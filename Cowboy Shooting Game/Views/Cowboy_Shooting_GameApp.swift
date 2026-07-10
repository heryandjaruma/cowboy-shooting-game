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
    @AppStorage(AppSettings.languageKey) private var languageCode = AppSettings.defaultLanguageCode
    @AppStorage(AppSettings.grayscaleKey) private var grayscaleEnabled = false
    @AppStorage(AppSettings.onboardingCompleteKey) private var onboardingComplete = false

    @StateObject private var gameCenterManager = GameCenterManager.shared

    // Splash screen state — resets every app launch since it's not persisted
    @State private var showSplash = true

    init() {
        GameCenterManager.shared.authenticatePlayer()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Show splash for a fixed duration, then fade it out
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
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

