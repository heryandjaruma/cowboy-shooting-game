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
}

struct GameCenterAuthView: UIViewControllerRepresentable {
    let viewController: UIViewController
    
    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context){}
}
