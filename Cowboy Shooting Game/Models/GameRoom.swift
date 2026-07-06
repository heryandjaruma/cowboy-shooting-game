//
//  GameRoom.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation
import Network

struct GameRoom: Identifiable, Hashable {
    let id: String
    let hostName: String
    let endpoint: NWEndpoint // Changed from UID cause we use NWEndpoint

    var displayName: String {
        "\(hostName)'s Game"
    }
}
