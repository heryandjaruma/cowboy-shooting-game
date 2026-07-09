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

    // App-mix volume controls — stored in UserDefaults, default 1.0 (full).
    // These shape the app's OWN mix only. The "Master" level is the device
    // volume, owned by TriggerController; iOS already scales all app audio by
    // it, so it must never be multiplied into these.
    static let musicVolumeKey   = "musicVolume"
    static let sfxVolumeKey     = "sfxVolume"
    static let gunshotVolumeKey = "gunshotVolume"

    /// Single source of truth for reading the mix volumes (0–1).
    static var musicVolume: Float { storedVolume(musicVolumeKey) }
    static var sfxVolume: Float { storedVolume(sfxVolumeKey) }
    static var gunshotVolume: Float { storedVolume(gunshotVolumeKey) }

    private static func storedVolume(_ key: String) -> Float {
        Float(UserDefaults.standard.object(forKey: key) as? Double ?? 1.0)
    }
}
