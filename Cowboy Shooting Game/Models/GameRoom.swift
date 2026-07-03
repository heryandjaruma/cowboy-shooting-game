//
//  GameRoom.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation

struct GameRoom: Identifiable, Hashable {
    let id = UUID()
    let hostName: String

    var displayName: String {
        "\(hostName)'s Game"
    }
}
