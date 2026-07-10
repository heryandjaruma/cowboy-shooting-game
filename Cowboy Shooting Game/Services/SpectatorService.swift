//
//  SpectatorService.swift
//  Cowboy Shooting Game
//
//  Spectator mode (POC). The host stays the source of truth: alongside the
//  duel it advertises a second Bonjour service that any number of spectators
//  can connect to, and pushes one-way snapshots — player names + lives — over
//  the same GameProtocol framing whenever the referee's tally changes.
//  Spectators never send anything back.
//

import Foundation
import Network
import Combine

/// What a spectator sees. Wire format of the `.spectate` event body (after the
/// channel byte): [hostLives][joinerLives][hostNameLength][hostName utf8][joinerName utf8]
struct SpectatorSnapshot: Equatable, Sendable {
    var hostName: String
    var joinerName: String   // empty until a challenger has joined
    var hostLives: Int
    var joinerLives: Int

    init(hostName: String, joinerName: String = "", hostLives: Int = 3, joinerLives: Int = 3) {
        self.hostName = hostName
        self.joinerName = joinerName
        self.hostLives = hostLives
        self.joinerLives = joinerLives
    }

    func encoded() -> Data {
        let hostBytes = Data(hostName.utf8).prefix(255)
        var data = Data([UInt8(clamping: hostLives),
                         UInt8(clamping: joinerLives),
                         UInt8(hostBytes.count)])
        data.append(hostBytes)
        data.append(Data(joinerName.utf8))
        return data
    }

    init?(decoding data: Data) {
        let bytes = Data(data) // copy so indices start at 0
        guard bytes.count >= 3 else { return nil }
        let nameLength = Int(bytes[2])
        guard bytes.count >= 3 + nameLength else { return nil }
        hostLives = Int(bytes[0])
        joinerLives = Int(bytes[1])
        hostName = String(decoding: bytes[3..<(3 + nameLength)], as: UTF8.self)
        joinerName = String(decoding: bytes[(3 + nameLength)...], as: UTF8.self)
    }
}

// MARK: - Host side

/// Accepts spectator connections while hosting and pushes the current snapshot
/// to all of them. Owned by `GameConnectionManager`; lives only on the host.
@MainActor
final class SpectatorBroadcaster {

    /// Bonjour service type for the spectator feed. Must match the
    /// `NSBonjourServices` entry in Info.plist.
    static let serviceType = "_cowboyduel-spec._tcp"

    private let queue = DispatchQueue(label: "ren.mark.cowboy-shooting-game.spectator")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var snapshot: SpectatorSnapshot

    init(hostName: String) {
        snapshot = SpectatorSnapshot(hostName: hostName)
    }

    func start() {
        listener?.cancel()
        do {
            let listener = try NWListener(using: GameConnectionManager.makeParameters())
            listener.service = NWListener.Service(name: snapshot.hostName, type: Self.serviceType)
            listener.newConnectionHandler = { newConnection in
                Task { @MainActor [weak self] in self?.adopt(newConnection) }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            // Spectating is a bonus feature — never let it break hosting.
            print("SpectatorBroadcaster: couldn't start: \(error)")
        }
    }

    private func adopt(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { newState in
            Task { @MainActor [weak self] in
                switch newState {
                case .ready:
                    self?.send(to: connection) // catch the newcomer up immediately
                case .failed, .cancelled:
                    self?.connections.removeAll { $0 === connection }
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    /// The duel's joiner identified itself — spectators learn the name.
    func setJoinerName(_ name: String) {
        snapshot.joinerName = name
        broadcast()
    }

    /// The referee's tally changed — push it to everyone watching.
    func updateLives(hostLives: Int, joinerLives: Int) {
        snapshot.hostLives = hostLives
        snapshot.joinerLives = joinerLives
        broadcast()
    }

    /// The challenger left; the host is waiting for a new one.
    func reset() {
        snapshot.joinerName = ""
        snapshot.hostLives = 3
        snapshot.joinerLives = 3
        broadcast()
    }

    private func broadcast() {
        for connection in connections { send(to: connection) }
    }

    private func send(to connection: NWConnection) {
        var payload = Data([GameChannel.spectate.rawValue])
        payload.append(snapshot.encoded())
        let message = NWProtocolFramer.Message(gameMessageType: .gameEvent)
        let context = NWConnection.ContentContext(identifier: "spectate", metadata: [message])
        connection.send(content: payload,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
            if let error {
                print("SpectatorBroadcaster: send failed: \(error)")
            }
        })
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections = []
    }
}

// MARK: - Spectator side

/// Finds nearby hosts' spectator feeds, connects to one, and republishes its
/// snapshots for SwiftUI. Receive-only.
@MainActor
final class SpectatorClient: ObservableObject {

    struct DiscoveredHost: Identifiable, Hashable, Sendable {
        let id: String   // Bonjour instance name — the host's player name.
        let name: String
        let endpoint: NWEndpoint
    }

    @Published private(set) var discoveredHosts: [DiscoveredHost] = []
    @Published private(set) var snapshot: SpectatorSnapshot?
    @Published private(set) var isConnected = false

    private let queue = DispatchQueue(label: "ren.mark.cowboy-shooting-game.spectator-client")
    private var browser: NWBrowser?
    private var connection: NWConnection?

    func startBrowsing() {
        stop()
        let browser = NWBrowser(for: .bonjour(type: SpectatorBroadcaster.serviceType, domain: nil),
                                using: GameConnectionManager.makeParameters())
        browser.browseResultsChangedHandler = { results, _ in
            let hosts: [DiscoveredHost] = results.compactMap { result in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredHost(id: name, name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Task { @MainActor [weak self] in self?.discoveredHosts = hosts }
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    /// Connect to a host's spectator feed and start receiving snapshots.
    func watch(_ host: DiscoveredHost) {
        browser?.cancel()
        browser = nil
        discoveredHosts = []

        let connection = NWConnection(to: host.endpoint, using: GameConnectionManager.makeParameters())
        self.connection = connection
        connection.stateUpdateHandler = { newState in
            Task { @MainActor [weak self] in
                switch newState {
                case .ready:
                    self?.isConnected = true
                    self?.receiveNextMessage()
                case .failed, .cancelled:
                    self?.hostDidDisconnect()
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func receiveNextMessage() {
        connection?.receiveMessage { content, context, _, error in
            // Pull out Sendable values here (on the network queue) before hopping.
            let type = (context?.protocolMetadata(definition: GameProtocol.definition)
                        as? NWProtocolFramer.Message)?.gameMessageType ?? .invalid
            let data = content ?? Data()

            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == .gameEvent, data.first == GameChannel.spectate.rawValue,
                   let snapshot = SpectatorSnapshot(decoding: Data(data.dropFirst())) {
                    self.snapshot = snapshot
                }
                if error != nil {
                    self.hostDidDisconnect()
                    return
                }
                self.receiveNextMessage()
            }
        }
    }

    /// The host went away (duel ended, or they left) — go back to browsing.
    private func hostDidDisconnect() {
        guard connection != nil else { return } // already torn down locally
        startBrowsing() // its stop() clears the dead connection
    }

    func stop() {
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        discoveredHosts = []
        snapshot = nil
        isConnected = false
    }
}
