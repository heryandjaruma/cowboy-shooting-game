//
//  Cowboy_Shooting_GameApp.swift
//  Cowboy Shooting Game
//
//  Created by Heryan Djaruma on 24/06/26.
//

import SwiftUI
import GameKit
import Combine

@main
struct Cowboy_Shooting_GameApp: App {
    // Stuff from settings go here. Defaults is the hardcoded value
    @AppStorage(AppSettings.languageKey) private var languageCode = AppSettings.defaultLanguageCode
    @AppStorage(AppSettings.grayscaleKey) private var grayscaleEnabled = false
    @AppStorage(AppSettings.onboardingCompleteKey) private var onboardingComplete = false
    
    // GameKit stuff
    @StateObject private var gameCenterManager = GameCenterManager.shared

    // Ensures authentication happens every boot-upa
    init() {
        GameCenterManager.shared.authenticatePlayer()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    MainMenuView()
                } else {
                    OnboardingView(onFinished: { onboardingComplete = true })
                }
            }
            .environmentObject(gameCenterManager)
            .environment(\.locale, Locale(identifier: languageCode))
            .grayscale(grayscaleEnabled ? 1.0 : 0.0)
            .sheet(isPresented: $gameCenterManager.showAuthViewController) {
                if let viewController = gameCenterManager.authViewController {
                    GameCenterAuthView(viewController: viewController)
                }
            }
        }
    }
}


final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var showAuthViewController = false
    var authViewController: UIViewController?

    /// Matches `vendorIdentifier` in GameCenterResources.gamekit — the leaderboard's ID.
    static let leaderboardID = "LocalWinCounts"
    /// Persistent cumulative win tally, so wins survive relaunches and are never lost
    /// while the player is signed out (they get backfilled on the next submit).
    private static let winCountKey = "gameCenterWinCount"

    private init() {}

    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let viewController = viewController {
                    self?.authViewController = viewController
                    self?.showAuthViewController = true
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.showAuthViewController = false
                    // Push any wins earned while signed out up to the leaderboard.
                    self?.submitWinCount()
                } else {
                    self?.isAuthenticated = false
                    self?.showAuthViewController = false
                    if let error = error {
                        print("Game Center Auth Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Records a duel win: bumps the persistent local tally, then submits the new
    /// total. The leaderboard is best-score, so the cumulative count is the score.
    func reportWin() {
        let newTotal = UserDefaults.standard.integer(forKey: Self.winCountKey) + 1
        UserDefaults.standard.set(newTotal, forKey: Self.winCountKey)
        submitWinCount()
    }

    /// Submits the current local win total to Game Center. Safe to call anytime —
    /// no-ops until the player is authenticated.
    func submitWinCount() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let total = UserDefaults.standard.integer(forKey: Self.winCountKey)
        GKLeaderboard.submitScore(total, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { error in
            if let error {
                print("Game Center leaderboard submit error: \(error.localizedDescription)")
            }
        }
    }
}

struct GameCenterAuthView: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context){}
}

