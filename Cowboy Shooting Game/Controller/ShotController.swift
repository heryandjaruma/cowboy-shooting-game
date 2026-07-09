//
//  ShotController.swift
//  Cowboy Shooting Game
//
//  Resolves a quick-draw by REACTION TIME.
//
//  CountdownController opens the firing window on each device (see startRound).
//  From that instant each player's reaction is measured locally — tapTime minus
//  windowOpenTime — using a monotonic clock. Because each reaction is measured
//  entirely on-device against that device's own window-open moment, the two
//  numbers are directly comparable and completely latency-independent: the
//  network never touches the measurement, so neither side gets a timing edge.
//
//  The host is the referee: it holds both reaction times (its own + the one the
//  joiner reports) and declares the smaller the winner, then tells the joiner.
//

import Foundation
import Combine

@MainActor
final class ShotController: ObservableObject {

    enum Outcome: Equatable {
        case winner
        case loser
    }

    /// The result of the current round, or nil while it's still undecided.
    @Published private(set) var outcome: Outcome?
    /// True once this device has drawn but is still waiting on the verdict.
    @Published private(set) var didFire = false

    private weak var connection: GameConnectionManager?

    /// Monotonic timestamp (uptime nanoseconds) when the firing window opened.
    private var windowOpenNanos: UInt64?
    private var myReaction: Double?      // seconds
    private var remoteReaction: Double?  // seconds
    private var resolved = false

    /// One-byte opcodes carried inside a `GameChannel.shot` payload.
    private enum Opcode {
        static let draw: UInt8 = 0        // joiner → host, followed by Double(reaction)
        static let resultWin: UInt8 = 1   // host → joiner: "you won"
        static let resultLose: UInt8 = 2  // host → joiner: "you lost"
    }
    
    // add timeout for draw
    private var drawTimeoutTask: Task<Void, Never>?
    private let drawGrace: Double = 1.0

    // MARK: - Wiring

    func configure(connection: GameConnectionManager) {
        self.connection = connection
        connection.onEvent(channel: GameChannel.shot.rawValue) { [weak self] body in
            self?.handleIncoming(body)
        }
    }

    /// Called by CountdownController the instant the firing window opens.
    func startRound(windowOpenNanos nanos: UInt64) {
        drawTimeoutTask?.cancel(); drawTimeoutTask = nil
        windowOpenNanos = nanos
        myReaction = nil
        remoteReaction = nil
        resolved = false
        outcome = nil
        didFire = false
    }

    // MARK: - Local input

    /// The local player pressed DRAW.
    func fire() {
        guard let open = windowOpenNanos, !didFire, outcome == nil, let connection else { return }
        let reaction = Double(DispatchTime.now().uptimeNanoseconds &- open) / 1_000_000_000
        didFire = true

        if connection.isHost {
            myReaction = reaction
            armDrawTimeout()
            resolveIfPossible()
        } else {
            connection.sendEvent(channel: GameChannel.shot.rawValue,
                                 body: Data([Opcode.draw]) + BinaryCoding.encode(reaction))
        }
    }

    func reset() {
        drawTimeoutTask?.cancel(); drawTimeoutTask = nil
        windowOpenNanos = nil
        myReaction = nil
        remoteReaction = nil
        resolved = false
        outcome = nil
        didFire = false
    }

    // MARK: - Incoming

    private func handleIncoming(_ body: Data) {
        guard let opcode = body.first, let connection else { return }
        switch opcode {
        case Opcode.draw where connection.isHost:
            remoteReaction = BinaryCoding.decode(Data(body.dropFirst()))
            armDrawTimeout() // the joiner drew first — the host now gets drawGrace to answer
            resolveIfPossible()
        case Opcode.resultWin where !connection.isHost:
            settle(.winner)
        case Opcode.resultLose where !connection.isHost:
            settle(.loser)
        default:
            break
        }
    }

    // MARK: - Referee (host only)
    
    /// Called when the host first learns of a reaction. Gives the slower hand
    /// `drawGrace` seconds; if it never draws, the one who did draw wins.
    private func armDrawTimeout() {
        guard let connection, connection.isHost, drawTimeoutTask == nil, !resolved else { return }
        drawTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.drawGrace ?? 1.0))
            guard let self, !Task.isCancelled else { return }
            self.resolveByTimeout()
        }
    }

    /// Once the host knows both reaction times, the smaller one wins.
    private func resolveIfPossible() {
        guard let connection, connection.isHost, !resolved,
              let mine = myReaction, let theirs = remoteReaction else { return }
        finish(hostWins: mine <= theirs)
    }
    
    private func resolveByTimeout() {
        guard let connection, connection.isHost, !resolved else { return }
        switch (myReaction, remoteReaction) {
        case (.some(let mine), .some(let theirs)): finish(hostWins: mine <= theirs)
        case (.some, .none):                        finish(hostWins: true)   // only host drew
        case (.none, .some):                        finish(hostWins: false)  // only peer drew
        case (.none, .none):                        break                    // nobody drew
        }
    }
    
    private func finish(hostWins: Bool) {
        guard let connection, connection.isHost, !resolved else { return }
        resolved = true
        drawTimeoutTask?.cancel(); drawTimeoutTask = nil
        if hostWins {
            connection.sendEvent(channel: GameChannel.shot.rawValue, body: Data([Opcode.resultLose]))
            settle(.winner)
        } else {
            connection.sendEvent(channel: GameChannel.shot.rawValue, body: Data([Opcode.resultWin]))
            settle(.loser)
        }
    }

    // MARK: - Resolution

    private func settle(_ outcome: Outcome) {
        resolved = true
        self.outcome = outcome
    }
}
