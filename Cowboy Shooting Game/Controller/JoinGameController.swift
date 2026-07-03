//
//  JoinGameController.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation
import Combine

final class JoinGameController: ObservableObject {
    @Published private(set) var rooms: [GameRoom] = []

    init() {
        loadDummyRooms()
    }

    func loadDummyRooms() {
        rooms = [
            GameRoom(hostName: "Rayne"),
            GameRoom(hostName: "Max"),
            GameRoom(hostName: "Ryan"),
            GameRoom(hostName: "Ian"),
            GameRoom(hostName: "Nisa"),
            GameRoom(hostName: "Test"),
            GameRoom(hostName: "Test"),
            GameRoom(hostName: "Test"),
            GameRoom(hostName: "Test"),
            GameRoom(hostName: "Test"),
            GameRoom(hostName: "Test")
        ]
    }

    func join(room: GameRoom) {
        // TODO: networking
    }
}
