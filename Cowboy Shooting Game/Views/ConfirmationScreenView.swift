//
//  ConfirmationScreenView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI
import SpriteKit

struct ConfirmationScreenView: View {
    @ObservedObject private var connection: GameConnectionManager
    @StateObject private var controller: ConfirmationController
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToGame = false

    init(connection: GameConnectionManager) {
        _connection = ObservedObject(wrappedValue: connection)
        _controller = StateObject(wrappedValue: ConfirmationController(connection: connection))
    }

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                ScreenTopBar(title: "GAME SET") {
                    connection.stopAll()
                    dismiss()
                }
                Spacer()
            }

            // Duelists panel
            HStack(spacing: 24) {
                nameBox(leftName)

                Text("vs")
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)

                nameBox(rightName)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primaryCSG)
                    .stroke(Color.ternaryCSG, lineWidth: 4)
            )
            .padding(.horizontal, 40)

            // Ready button, bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        controller.pressReady()
                    } label: {
                        Text(controller.localReady ? "Waiting…" : "Ready")
                    }
                    .buttonStyle(.cowboyCompact)
                    .disabled(controller.localReady)
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.activate() }
        .onChange(of: controller.bothReady) { _, ready in
            if ready { navigateToGame = true }
        }
        .onChange(of: connection.state) { _, newState in
            // Opponent left before the duel — fall back to the previous screen.
            if case .connected = newState {} else if !navigateToGame {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $navigateToGame) {
            GeometryReader { geometry in
                SpriteView(scene: createGameScene(size: geometry.size))
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Pieces

    private var opponentName: String {
        if case let .connected(peerName) = connection.state { return peerName }
        return "…"
    }

    /// Host is always shown on the left, challenger on the right.
    private var leftName: String { connection.isHost ? connection.myName : opponentName }
    private var rightName: String { connection.isHost ? opponentName : connection.myName }

    private func nameBox(_ name: String) -> some View {
        Text(name)
            .font(.headingCSG)
            .foregroundColor(Color.ternaryCSG)
            .lineLimit(1)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondaryCSG)
                    .stroke(Color.ternaryCSG, lineWidth: 3)
            )
    }

    private func createGameScene(size: CGSize) -> SKScene {
        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        scene.connection = connection
        return scene
    }
}

#Preview {
    ConfirmationScreenView(connection: GameConnectionManager())
}
