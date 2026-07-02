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
    /// Scaffolding: a running log of received game events. Replace with real game state.
    @Published private(set) var eventLog: [String] = []

    /// Human-readable name advertised to / shown by the other device.
    let myName: String

    // MARK: Private

    private let networkQueue = DispatchQueue(label: "ren.mark.cowboy-shooting-game.network")

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?

    init(myName: String? = nil) {
        // UIDevice.current is main-actor isolated; read it inside this @MainActor init.
        self.myName = myName ?? UIDevice.current.name
    }

    // MARK: - Hosting

    /// Begin advertising this device as a host and wait for a joiner.
    func startHosting() {
        stopAll()
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
        case .failed(let error):
            state = .failed(reason: "Connection failed: \(error.localizedDescription)")
            teardownConnection()
        case .cancelled:
            if case .connected = state { state = .idle }
        default:
            break
        }
    }

    // MARK: - Sending

    /// Discrete, must-arrive gameplay event (shot fired, hit, round start…).
    func sendEvent(_ payload: Data) { send(payload, as: .gameEvent) }

    /// High-frequency snapshot (position / aim). Latest-value-wins in spirit.
    func sendPlayerState(_ payload: Data) { send(payload, as: .playerState) }

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

                if let error {
                    self.state = .failed(reason: "Receive error: \(error.localizedDescription)")
                    self.teardownConnection()
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
        case .gameEvent:
            eventLog.append("event · \(data.count) bytes")
        case .playerState:
            // TODO: feed into the game loop.
            break
        case .invalid:
            break
        }
    }

    // MARK: - Teardown

    /// Drop the active peer connection but stay in the current mode.
    private func teardownConnection() {
        connection?.cancel()
        connection = nil
    }

    /// Tear everything down and return to idle.
    func stopAll() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discoveredPeers = []
        state = .idle
    }

    // MARK: - Parameters

    /// TCP + peer-to-peer (Wi-Fi/AWDL) with our custom framing on top.
    private static func makeParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2

        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true

        let framer = NWProtocolFramer.Options(definition: GameProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framer, at: 0)
        return parameters
    }
}
