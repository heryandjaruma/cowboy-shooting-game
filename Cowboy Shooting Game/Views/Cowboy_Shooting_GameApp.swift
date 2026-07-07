//
//  Cowboy_Shooting_GameApp.swift
//  Cowboy Shooting Game
//
//  Created by Heryan Djaruma on 24/06/26.
//

import SwiftUI

@main
struct Cowboy_Shooting_GameApp: App {
    // Stuff from settings go here. Defaults is the hardcoded value
    @AppStorage(AppSettings.languageKey) private var languageCode = AppSettings.defaultLanguageCode
    @AppStorage(AppSettings.grayscaleKey) private var grayscaleEnabled = false

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environment(\.locale, Locale(identifier: languageCode))
                .grayscale(grayscaleEnabled ? 1.0 : 0.0)
        }
    }
}
