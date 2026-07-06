//
//  ConfirmationController.swift
//  Cowboy Shooting Game
//
//  Pre-duel ready handshake: both players must press Ready on the
//  ConfirmationScreenView before either moves into the GameScene.
//
//  Rides the `GameChannel.match` channel with a single idempotent
//  "I am ready" message. If our first announcement raced ahead of the
//  peer registering its handler, we re-announce the moment we learn
//  they're ready — so both sides always converge.
//

import Foundation
import Combine

@MainActor
final class ConfirmationController: ObservableObject {

    @Published private(set) var localReady = false
    @Published private(set) var remoteReady = false
    /// True once both players pressed Ready — time to enter the arena.
    @Published private(set) var bothReady = false

    private let connection: GameConnectionManager

    private enum Opcode {
        static let ready: UInt8 = 0 // "I pressed Ready"
    }

    init(connection: GameConnectionManager) {
        self.connection = connection
    }

    /// Start listening for the peer's ready message. Call when the screen appears.
    func activate() {
        connection.onEvent(channel: GameChannel.match.rawValue) { [weak self] body in
            self?.handleIncoming(body)
        }
    }

    func pressReady() {
        guard !localReady else { return }
        localReady = true
        sendReady()
        checkBothReady()
    }

    private func handleIncoming(_ body: Data) {
        guard body.first == Opcode.ready else { return }
        let firstTime = !remoteReady
        remoteReady = true
        // Re-announce ours in case our earlier message was sent before the
        // peer's handler was registered. Only on the first sighting, so the
        // exchange always terminates.
        if firstTime && localReady {
            sendReady()
        }
        checkBothReady()
    }

    private func sendReady() {
        connection.sendEvent(channel: GameChannel.match.rawValue, body: Data([Opcode.ready]))
    }

    private func checkBothReady() {
        if localReady && remoteReady {
            bothReady = true
        }
    }
}
