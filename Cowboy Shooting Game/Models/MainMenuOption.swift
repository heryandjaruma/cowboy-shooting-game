//
//  MainMenuOption.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 02/07/26.
//
 
import Foundation
 
struct MenuOption: Identifiable {
    let id = UUID()
    let targetDestination: MenuDestination
}
 
enum MenuDestination: Hashable {
    case createGame
    case joinGame
    case spectateGame
    case settingsGame
    case helpGame
    case creditsGame

    var title: LocalizedStringResource {
        switch self {
        case .createGame: "Create Game"
        case .joinGame: "Join Game"
        case .spectateGame: "Spectate"
        case .settingsGame: "Settings"
        case .helpGame: "Help"
        case .creditsGame: "Credits"
        }
    }
}
 
