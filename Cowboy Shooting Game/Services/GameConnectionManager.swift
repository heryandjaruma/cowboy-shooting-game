//
//  GameConnectionManager.swift
//  Cowboy Shooting Game
//
//  Peer-to-peer session management built directly on the Network framework +
//  Bonjour — no Multipeer Connectivity, no server.
//
//  Roles:
//    • Host  — advertises a Bonjour service via NWListener and waits for a joiner.
//    • Joiner — browses for hosts via NWBrowser and connects via NWConnection.
//
//  The game is a 1-on-1 duel, so exactly one peer connection is kept. Once the
//  host adopts a connection it stops advertising, and further inbound
//  connections are rejected. (Growing to N players would mean holding an array
//  of connections and broadcasting — deliberately not done here.)
//
//  Concurrency: this class is @MainActor (the target default) so its @Published
//  state drives SwiftUI safely. All Network objects run on a private background
//  queue; their callbacks hop back onto the main actor before touching state.
//

import Foundation
import Network
import Combine
import UIKit

@MainActor
final class GameConnectionManager: ObservableObject {

    /// Bonjour service type. Must match the `NSBonjourServices` entry in Info.plist.
    static let serviceType = "_cowboyduel._tcp"

    // MARK: Published state

    enum ConnectionState: Equatable {
        case idle
        case hosting
        case browsing
        case connecting
        case connected(peerName: String)
        case failed(reason: String)
    }

    /// A host discovered while browsing.
    struct DiscoveredPeer: Identifiable, Hashable, Sendable {
        let id: String          // Bonjour instance name — stable while advertised.
        let name: String
        let endpoint: NWEndpoint
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var discoveredPeers: [DiscoveredPeer] = []

    /// True on the device that is hosting — it also acts as the duel referee.
    @Published private(set) var isHost = false

    /// True once this device's monotonic clock is aligned with the host's, so
    /// scheduled times can be shared. Always true on the host (it *is* the reference).
    @Published private(set) var isClockSynced = false

    /// Handlers for received `.gameEvent`s, keyed by channel (the first payload byte).
    private var eventHandlers: [UInt8: (Data) -> Void] = [:]

    // Clock synchronization (NTP-style). `clockOffsetNanos` is (hostClock − localClock);
    // it's 0 on the host. Only the joiner estimates it.
    private var clockOffsetNanos: Int64 = 0
    private var bestRoundTripNanos: UInt64 = .max
    private var clockSyncSamplesRemaining = 0

    private enum ClockOp {
        static let ping: UInt8 = 0  // joiner → host: + t0
        static let pong: UInt8 = 1  // host → joiner: + t0 + t1 + t2
    }

    /// `UserDefaults` key under which the player's chosen display name is stored.
    /// Bound to the "Got a name?" prompt in `MainMenuView`.
    static let playerNameDefaultsKey = "playerName"

    /// `UserDefaults` key for the auto-assigned fallback alias — persisted once so
    /// it stays stable across reads and launches until the player picks a name.
    private static let autoNameDefaultsKey = "playerAutoName"

    /// Wild-West aliases handed out when the player hasn't chosen a name. Keeps
    /// duelists recognizable and avoids the generic "iPhone" device name that
    /// `UIDevice.current.name` returns since iOS 16 (a privacy change).
    private static let randomNames = [
        "Quick Draw", "Dead Eye", "El Bandito", "The Kid", "Doc Holla",
        "Six-Shooter", "Calamity", "Rustler", "Lone Ranger", "Buckshot",
        "Wild Bill", "Ghost Rider", "Ace", "Maverick", "Tumbleweed"
    ]

    /// Read-only view of the Wild-West aliases, for UIs that let the player cycle
    /// through suggestions (e.g. the name prompt's "Random" button).
    static var suggestedNames: [String] { randomNames }

    /// Human-readable name advertised to / shown by the other device.
    ///
    /// Prefers the name the player typed; otherwise returns the stable
    /// auto-assigned alias. Read fresh each time so a name change takes effect on
    /// the next host/join.
    var myName: String {
        if let nameOverride { return nameOverride }
        let defaults = UserDefaults.standard
        if let chosen = defaults.string(forKey: Self.playerNameDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !chosen.isEmpty {
            return chosen
        }
        if let auto = defaults.string(forKey: Self.autoNameDefaultsKey), !auto.isEmpty {
            return auto
        }
        return Self.randomNames.first ?? "Stranger"
    }

    /// Explicit name injected at init (used by previews); overrides the stored name.
    private let nameOverride: String?

    // MARK: Private

    private let networkQueue = DispatchQueue(label: "ren.mark.cowboy-shooting-game.network")

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?

    /// Host only: fan-out of name/lives snapshots to watching devices.
    private var spectatorBroadcaster: SpectatorBroadcaster?

    init(myName: String? = nil) {
        self.nameOverride = myName
        if myName == nil { Self.ensureAutoName() }
        onEvent(channel: GameChannel.clock.rawValue) { [weak self] body in
            self?.handleClockEvent(body)
        }
    }

    /// Assign and persist a random alias once, so a player who never picks a name
    /// still gets a stable, recognizable identity instead of "iPhone".
    private static func ensureAutoName() {
        let defaults = UserDefaults.standard
        let existing = defaults.string(forKey: autoNameDefaultsKey) ?? ""
        if existing.isEmpty {
            defaults.set(randomNames.randomElement() ?? "Stranger", forKey: autoNameDefaultsKey)
        }
    }

    /// Convert an absolute host-clock timestamp into this device's own monotonic
    /// uptime clock, so both peers can act at the same real instant.
    func localUptime(forHostNanos hostNanos: UInt64) -> UInt64 {
        if isHost { return hostNanos }
        let local = Int64(bitPattern: hostNanos) - clockOffsetNanos
        return local < 0 ? 0 : UInt64(local)
    }

    // MARK: - Hosting

    /// Begin advertising this device as a host and wait for a joiner.
    func startHosting() {
        stopAll()
        isHost = true
        isClockSynced = true // the host clock is the reference.
        spectatorBroadcaster = SpectatorBroadcaster(hostName: myName)
        spectatorBroadcaster?.start()
        beginAdvertising()
    }

    /// After a challenger leaves, keep hosting and wait for the next one.
    /// (isHost / isClockSynced are already set from the original host session.)
    private func resumeHosting() {
        beginAdvertising()
    }

    /// (Re)start the Bonjour listener so a challenger can join.
    private func beginAdvertising() {
        listener?.cancel()
        listener = nil
        do {
            let listener = try NWListener(using: Self.makeParameters())
            listener.service = NWListener.Service(name: myName, type: Self.serviceType)

            listener.stateUpdateHandler = { newState in
                Task { @MainActor [weak self] in self?.handleListenerState(newState) }
            }
            listener.newConnectionHandler = { newConnection in
                Task { @MainActor [weak self] in self?.adoptIncoming(newConnection) }
            }

            self.listener = listener
            state = .hosting
            listener.start(queue: networkQueue)
        } catch {
            state = .failed(reason: "Couldn't start hosting: \(error.localizedDescription)")
        }
    }

    private func handleListenerState(_ newState: NWListener.State) {
        switch newState {
        case .failed(let error):
            state = .failed(reason: "Host failed: \(error.localizedDescription)")
            stopAll()
        case .cancelled:
            break
        default:
            break
        }
    }

    /// A joiner connected. Keep the first one; it's a duel.
    private func adoptIncoming(_ newConnection: NWConnection) {
        guard connection == nil else {
            newConnection.cancel() // Already dueling someone.
            return
        }
        // 1-on-1: stop advertising once we have a partner.
        listener?.cancel()
        listener = nil
        setupConnection(newConnection)
    }

    // MARK: - Browsing / Joining

    /// Begin searching for nearby hosts.
    func startBrowsing() {
        stopAll()
        isHost = false
        isClockSynced = false // the joiner must sync to the host first.
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil),
                                using: Self.makeParameters())

        browser.stateUpdateHandler = { newState in
            Task { @MainActor [weak self] in self?.handleBrowserState(newState) }
        }
        browser.browseResultsChangedHandler = { results, _ in
            // Build the Sendable peer list off the network queue, then hop.
            let peers: [DiscoveredPeer] = results.compactMap { result in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredPeer(id: name, name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Task { @MainActor [weak self] in self?.discoveredPeers = peers }
        }

        self.browser = browser
        state = .browsing
        browser.start(queue: networkQueue)
    }

    private func handleBrowserState(_ newState: NWBrowser.State) {
        if case .failed(let error) = newState {
            state = .failed(reason: "Browsing failed: \(error.localizedDescription)")
            stopAll()
        }
    }

    /// Connect to a discovered host.
    func join(_ peer: DiscoveredPeer) {
        browser?.cancel()
        browser = nil
        discoveredPeers = []

        let connection = NWConnection(to: peer.endpoint, using: Self.makeParameters())
        state = .connecting
        setupConnection(connection)
    }

    // MARK: - Shared connection setup

    private func setupConnection(_ connection: NWConnection) {
        self.connection = connection
        connection.stateUpdateHandler = { newState in
            Task { @MainActor [weak self] in self?.handleConnectionState(newState) }
        }
        connection.start(queue: networkQueue)
    }

    private func handleConnectionState(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            // Announce ourselves; the peer's name arrives via their handshake.
            state = .connected(peerName: "…")
            sendHandshake()
            receiveNextMessage()
            if !isHost { startClockSync() }
        case .failed, .cancelled:
            // A dropped connection (peer left, or a real failure) is handled the
            // same, graceful way — never surfaced as an error to the player.
            peerDidDisconnect()
        default:
            break
        }
    }

    // MARK: - Sending

    /// Register a handler for a game-event channel. Re-registering replaces it.
    func onEvent(channel: UInt8, _ handler: @escaping (Data) -> Void) {
        eventHandlers[channel] = handler
    }

    /// Send a channel-tagged gameplay event (must-arrive). The channel byte is
    /// prepended to `body`; the receiver's handler is given `body` without it.
    func sendEvent(channel: UInt8, body: Data = Data()) {
        var payload = Data([channel])
        payload.append(body)
        send(payload, as: .gameEvent)
    }

    /// High-frequency snapshot (position / aim). Latest-value-wins in spirit.
    func sendPlayerState(_ payload: Data) { send(payload, as: .playerState) }

    /// Host (referee) only: push the current lives tally to any spectators.
    /// A no-op on the joiner, where no broadcaster exists.
    func updateSpectatorLives(hostLives: Int, joinerLives: Int) {
        spectatorBroadcaster?.updateLives(hostLives: hostLives, joinerLives: joinerLives)
    }

    /// Host only: forward a channel-tagged event to spectators (audio sync, etc.).
    /// A no-op on the joiner, where no broadcaster exists.
    func relayToSpectators(channel: UInt8, body: Data) {
        spectatorBroadcaster?.relay(channel: channel, body: body)
    }

    private func sendHandshake() {
        send(Data(myName.utf8), as: .handshake)
    }

    private func send(_ payload: Data, as type: GameMessageType) {
        guard let connection else { return }
        let message = NWProtocolFramer.Message(gameMessageType: type)
        let context = NWConnection.ContentContext(identifier: "\(type)",
                                                  metadata: [message])
        connection.send(content: payload,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
            if let error {
                print("GameConnectionManager: send failed: \(error)")
            }
        })
    }

    // MARK: - Receiving

    private func receiveNextMessage() {
        connection?.receiveMessage { content, context, _, error in
            // Pull out Sendable values here (on the network queue) before hopping.
            let type = (context?.protocolMetadata(definition: GameProtocol.definition)
                        as? NWProtocolFramer.Message)?.gameMessageType ?? .invalid
            let data = content ?? Data()

            Task { @MainActor [weak self] in
                guard let self else { return }

                if type != .invalid {
                    self.handleReceived(type: type, data: data)
                }

                if error != nil {
                    // Peer closed the stream (e.g. they hit Cancel) — treat as a
                    // clean disconnect rather than an error.
                    self.peerDidDisconnect()
                    return
                }
                // Re-arm only after processing, which keeps messages strictly in order.
                self.receiveNextMessage()
            }
        }
    }

    private func handleReceived(type: GameMessageType, data: Data) {
        switch type {
        case .handshake:
            let name = String(decoding: data, as: UTF8.self)
            state = .connected(peerName: name.isEmpty ? "Opponent" : name)
            spectatorBroadcaster?.setJoinerName(name.isEmpty ? "Opponent" : name)
        case .gameEvent:
            guard let channel = data.first else { break }
            eventHandlers[channel]?(Data(data.dropFirst()))
        case .playerState:
            // TODO: feed into the game loop.
            break
        case .invalid:
            break
        }
    }

    // MARK: - Clock synchronization

    /// Joiner: probe the host a handful of times and keep the offset from the
    /// round-trip with the least delay (the least-jittered, most accurate sample).
    private func startClockSync() {
        guard !isHost else { return }
        bestRoundTripNanos = .max
        clockSyncSamplesRemaining = 5
        sendPing()
    }

    private func sendPing() {
        let t0 = DispatchTime.now().uptimeNanoseconds
        sendEvent(channel: GameChannel.clock.rawValue,
                  body: Data([ClockOp.ping]) + BinaryCoding.encode(t0))
    }

    private func handleClockEvent(_ body: Data) {
        guard let op = body.first else { return }
        let rest = Data(body.dropFirst())

        switch op {
        case ClockOp.ping: // host side: timestamp receipt and reply
            let t1 = DispatchTime.now().uptimeNanoseconds
            guard let t0 = BinaryCoding.decodeU64(rest) else { return }
            let t2 = DispatchTime.now().uptimeNanoseconds
            var payload = Data([ClockOp.pong])
            payload += BinaryCoding.encode(t0)
            payload += BinaryCoding.encode(t1)
            payload += BinaryCoding.encode(t2)
            sendEvent(channel: GameChannel.clock.rawValue, body: payload)

        case ClockOp.pong: // joiner side: compute offset & round-trip delay
            let t3 = DispatchTime.now().uptimeNanoseconds
            guard rest.count >= 24,
                  let t0 = BinaryCoding.decodeU64(rest),
                  let t1 = BinaryCoding.decodeU64(Data(rest.dropFirst(8))),
                  let t2 = BinaryCoding.decodeU64(Data(rest.dropFirst(16))) else { return }

            let roundTrip = (Int64(bitPattern: t3) - Int64(bitPattern: t0))
                          - (Int64(bitPattern: t2) - Int64(bitPattern: t1))
            let offset = ((Int64(bitPattern: t1) - Int64(bitPattern: t0))
                        + (Int64(bitPattern: t2) - Int64(bitPattern: t3))) / 2

            if UInt64(max(roundTrip, 0)) < bestRoundTripNanos {
                bestRoundTripNanos = UInt64(max(roundTrip, 0))
                clockOffsetNanos = offset
            }
            isClockSynced = true

            clockSyncSamplesRemaining -= 1
            if clockSyncSamplesRemaining > 0 { sendPing() }

        default:
            break
        }
    }

    // MARK: - Teardown

    /// The peer connection dropped (they left, or it failed). Clean up and, if we
    /// were hosting, go back to waiting for a new challenger; a joiner returns to
    /// the lobby. A no-op if we already tore the connection down ourselves (Cancel).
    private func peerDidDisconnect() {
        guard connection != nil else { return }
        connection?.cancel()
        connection = nil

        if isHost {
            spectatorBroadcaster?.reset() // spectators see a fresh 3-3 lobby again.
            resumeHosting() // stay in the room, wait for another challenger.
        } else {
            state = .idle   // the host left — back to the lobby.
        }
    }

    /// Tear everything down and return to the lobby (the local Cancel button).
    func stopAll() {
        connection?.cancel()
        connection = nil
        spectatorBroadcaster?.stop()
        spectatorBroadcaster = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discoveredPeers = []
        isHost = false
        isClockSynced = false
        state = .idle
    }

    // MARK: - Parameters

    /// TCP + peer-to-peer (Wi-Fi/AWDL) with our custom framing on top.
    /// Also used by the spectator link (SpectatorService) so both speak GameProtocol.
    static func makeParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        tcp.noDelay = true // disable Nagle: send our tiny timing messages immediately.

        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true

        let framer = NWProtocolFramer.Options(definition: GameProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framer, at: 0)
        return parameters
    }
}
