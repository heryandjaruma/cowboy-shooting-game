//
//  JoinGameController.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation
import Combine

@MainActor
final class JoinGameController: ObservableObject {
    @Published private(set) var rooms: [GameRoom] = []

    private let connection: GameConnectionManager
    private var cancellable: AnyCancellable?

    init(connection: GameConnectionManager) {
        self.connection = connection
    }

    func start() {
        connection.startBrowsing()
        cancellable = connection.$discoveredPeers.sink { [weak self] peers in
            Task { @MainActor in
                self?.rooms = peers.map {
                    GameRoom(id: $0.id, hostName: $0.name, endpoint: $0.endpoint)
                }
            }
        }
    }

    func join(room: GameRoom) {
        connection.join(.init(id: room.id, name: room.hostName, endpoint: room.endpoint))
    }

    func stop() {
        cancellable = nil
        connection.stopAll()
    }
}
