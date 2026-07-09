//
//  CountdownController.swift
//  Cowboy Shooting Game
//
//  Drives the pre-duel flow: both players press Ready, then a 3-2-1 countdown
//  runs and the firing window opens.
//
//  Flow:
//    • Each player taps Ready → sees "Step right up." while waiting.
//    • The HOST arbitrates: once both are ready it picks one shared, randomized
//      hold for the final "1" (2–5s, so the draw can't be timed) and tells the
//      joiner to begin. Both devices then run an identical countdown locally.
//    • At the end each device opens its own firing window and hands the moment to
//      ShotController, which judges the draw by locally-measured reaction time.
//
//  The two countdowns start a network hop apart (the joiner begins when it
//  receives the "begin" message), but that's fine: each player reacts to their
//  own screen and is judged on their own reaction interval.
//

import Foundation
import Combine

@MainActor
final class CountdownController: ObservableObject {
    
    enum Phase: Equatable {
        case notReady        // connected; waiting for this player to tap Ready
        case waiting         // this player is ready ("Step right up.")
        case counting(Int)   // 3, 2
        case fire            // firing window open — draw!
    }
    
    @Published private(set) var phase: Phase = .notReady
    
    /// How long "3" and "2" are each shown — a touch longer than a real second.
    private let tickSeconds: Double = 1.3
    /// The suspenseful hold on "1" is randomized within this range (seconds).
    private let finalHoldRange: ClosedRange<Double> = 2...5
    /// Lead time before "3" appears, to let `begin` reach the joiner first.
    private let leadSeconds: Double = 0.5
    
    private weak var connection: GameConnectionManager?
    private weak var shot: ShotController?
    
    private var localReady = false
    private var remoteReady = false
    private var countdownTask: Task<Void, Never>?
    
    /// One-byte opcodes carried inside a `GameChannel.match` payload.
    private enum Opcode {
        static let ready: UInt8 = 0   // "I'm ready"
        static let begin: UInt8 = 1   // host → joiner, followed by Double(finalHold)
        static let reset: UInt8 = 2   // "back to the lobby for a rematch"
    }
    
    // MARK: - Wiring
    
    func configure(connection: GameConnectionManager, shot: ShotController) {
        self.connection = connection
        self.shot = shot
        connection.onEvent(channel: GameChannel.match.rawValue) { [weak self] body in
            self?.handleIncoming(body)
        }
    }
    
    // MARK: - Ready
    
    func pressReady() {
        guard phase == .notReady, let connection else { return }
        localReady = true
        phase = .waiting
        connection.sendEvent(channel: GameChannel.match.rawValue, body: Data([Opcode.ready]))
        startIfBothReady()
    }
    
    /// Host-only: when both players are ready, pick the shared schedule and kick off.
    ///
    /// The window-open time is expressed as an absolute host-clock timestamp, so
    /// both devices open their windows at the *same real instant* (the joiner
    /// converts it with the synced clock offset). That's what makes the draw fair.
    private func startIfBothReady() {
        guard let connection, connection.isHost, localReady, remoteReady else { return }
        let hold = Double.random(in: finalHoldRange)
        let openHostNanos = DispatchTime.now().uptimeNanoseconds
        + nanos(leadSeconds + 2 * tickSeconds + hold)
        
        var body = Data([Opcode.begin])
        body += BinaryCoding.encode(openHostNanos)
        body += BinaryCoding.encode(hold)
        connection.sendEvent(channel: GameChannel.match.rawValue, body: body)
        
        scheduleCountdown(openHostNanos: openHostNanos, finalHold: hold)
    }
    
    // MARK: - Rematch
    
    func reset() {
        connection?.sendEvent(channel: GameChannel.match.rawValue, body: Data([Opcode.reset]))
        performReset()
    }
    
    /// Local-only reset for automatic round transitions. Crucially does NOT clear
    /// remoteReady: the peer may have tapped-to-continue and sent its `ready` before
    /// this device reset, and that signal must survive or the both-ready gate deadlocks
    /// (peer counts down, this device stuck on "waiting").
    func resetForNextRound() {
        performReset(clearRemoteReady: false)
    }
    
    private func performReset(clearRemoteReady: Bool = true) {
        countdownTask?.cancel()
        countdownTask = nil
        localReady = false
        if clearRemoteReady { remoteReady = false }
        phase = .notReady
        shot?.reset()
    }
    
    // MARK: - Incoming
    
    private func handleIncoming(_ body: Data) {
        guard let opcode = body.first else { return }
        switch opcode {
        case Opcode.ready:
            remoteReady = true
            startIfBothReady()
        case Opcode.begin:
            let rest = Data(body.dropFirst())
            guard let openHostNanos = BinaryCoding.decodeU64(rest),
                  let hold = BinaryCoding.decode(Data(rest.dropFirst(8))) else { return }
            scheduleCountdown(openHostNanos: openHostNanos, finalHold: hold)
        case Opcode.reset:
            performReset()
        default:
            break
        }
    }
    
    // MARK: - Countdown
    
    /// Run the 3-2-1-fire schedule against the shared clock. Every step is pinned
    /// to an absolute local time derived from the host-clock window-open instant,
    /// so both devices tick and open the window together.
    private func scheduleCountdown(openHostNanos: UInt64, finalHold: Double) {
        guard let connection else { return }
        // This round's ready pair is consumed. Clearing here (not at reset time)
        // is what prevents a stale remoteReady from a finished round auto-starting
        // the next one while the peer is still on "tap to continue".
        localReady = false
        remoteReady = false
        let open = connection.localUptime(forHostNanos: openHostNanos)
        let show1 = open &- nanos(finalHold)
        let show2 = show1 &- nanos(tickSeconds)
        let show3 = show2 &- nanos(tickSeconds)
        
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sleep(until: show3); self.phase = .counting(3)
                try await self.sleep(until: show2); self.phase = .counting(2)
                try await self.sleep(until: show1); self.phase = .counting(1)
                try await self.sleep(until: open)
                self.openWindow(atLocalNanos: open)
            } catch {
                // Cancelled by reset/disconnect — leave the phase as-is.
            }
        }
    }
    
    /// Suspend until this device's monotonic clock reaches `targetNanos`.
    private func sleep(until targetNanos: UInt64) async throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard targetNanos > now else { return } // already due
        try await Task.sleep(for: .nanoseconds(Int64(targetNanos - now)))
    }
    
    private func openWindow(atLocalNanos openNanos: UInt64) {
        phase = .fire
        // Measure reaction from the exact synced instant, not "now", so both
        // devices share the same zero point.
        shot?.startRound(windowOpenNanos: openNanos)
    }
    
    private func nanos(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}
