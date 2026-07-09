//
//  AppSettings.swift
//  Cowboy Shooting Game
//
//  Shared keys and option lists for user-adjustable app settings, so the app
//  root (Cowboy_Shooting_GameApp) and SettingsView stay in sync.
//

import Foundation

enum AppSettings {
    static let languageKey = "appLanguage"
    static let grayscaleKey = "grayscaleEnabled"
    /// Flag for onboarding
    static let onboardingCompleteKey = "onboardingComplete"
    static let languages: [(name: String, code: String)] = [
        ("English", "en"),
        ("Indonesia", "id")
    ]

    static var languageNames: [String] { languages.map(\.name) }
    static var languageCodes: [String] { languages.map(\.code) }
    static var defaultLanguageCode: String { languageCodes.first ?? "en" }
}
