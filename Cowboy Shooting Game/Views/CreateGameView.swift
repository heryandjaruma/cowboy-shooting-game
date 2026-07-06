//
//  CreateGameView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//


import SwiftUI
import SpriteKit

struct CreateGameView: View {
    @ObservedObject var connection: GameConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPulsing = false
    @State private var navigateToGame = false

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                ScreenTopBar(title: "Create Game") {
                    dismiss()
                }

                Spacer()

                Image(systemName: "wifi")
                    .font(.system(size: 170, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("Room created, waiting for a challenger")
                    .font(.headingCSG2)
                    .foregroundStyle(.white)
                    .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { connection.startHosting() }
        .onDisappear { connection.stopAll() }
        .onChange(of: connection.state) { _, newState in
                    // A challenger joined — move the host into the game too.
                    if case .connected = newState {
                        navigateToGame = true
                    }
                }
                .fullScreenCover(isPresented: $navigateToGame) {
                    GeometryReader { geometry in
                        SpriteView(scene: createGameScene(size: geometry.size))
                            .ignoresSafeArea()
                    }
                }
    }
    
    private func createGameScene(size: CGSize) -> SKScene {
            let scene = GameScene(size: size)
            scene.scaleMode = .resizeFill
            return scene
        }
}

#Preview {
    CreateGameView(connection: GameConnectionManager())
}
