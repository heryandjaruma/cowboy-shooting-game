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
    @State private var showConnectionLostAlert = false

    /// Unwinds past the create/join screen back to the main menu (set by the
    /// presenting view). Used when the connection drops mid-duel.
    private let onReturnToMenu: () -> Void

    /// Keeps a single GameScene alive across body re-evaluations. Building the
    /// scene inline in the cover would silently restart the duel every time a
    /// published value (e.g. connection.state) changes mid-match.
    private final class SceneHolder {
        var scene: GameScene?
    }
    @State private var sceneHolder = SceneHolder()

    init(connection: GameConnectionManager, onReturnToMenu: @escaping () -> Void = {}) {
        _connection = ObservedObject(wrappedValue: connection)
        _controller = StateObject(wrappedValue: ConfirmationController(connection: connection))
        self.onReturnToMenu = onReturnToMenu
    }
    
    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)

            VStack {
                ScreenTopBar(title: "GAME SET") {
                    connection.stopAll()
                    dismiss()
                }
                Spacer()
            }.padding(.top, 20)
            
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
            .onAppear {
                MusicManager.shared.stop(fade: true)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.activate() }
        .onChange(of: controller.bothReady) { _, ready in
            if ready { navigateToGame = true }
        }
        .onChange(of: connection.state) { _, newState in
            if case .connected = newState { return }
            if navigateToGame {
                // Mid-duel drop: tell the player, then send them to the main menu.
                // If the match already ended (the opponent tapping "return to menu"
                // also closes the connection), the result screen is the exit instead.
                guard !showConnectionLostAlert else { return }
                if case .matchOver = sceneHolder.scene?.matchController.matchPhase { return }
                connection.stopAll() // a disconnected host would otherwise re-advertise mid-game
                showConnectionLostAlert = true
            } else {
                // Opponent left before the duel — fall back to the previous screen.
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $navigateToGame, onDismiss: { sceneHolder.scene = nil }) {
            GeometryReader { geometry in
                SpriteView(scene: gameScene(size: geometry.size)) // start a SpriteKit view
                    .ignoresSafeArea()
                    .onAppear {
                        MusicManager.shared.play(.gameplay)
                    }
            }
            .alert("Connection Lost", isPresented: $showConnectionLostAlert) {
                Button("Back to Menu") {
                    navigateToGame = false
                    onReturnToMenu()
                }
            } message: {
                Text("The connection to your opponent was lost.")
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
    
    // init a game scene (once per match — see SceneHolder)
    private func gameScene(size: CGSize) -> SKScene {
        if let scene = sceneHolder.scene { return scene }
        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        scene.connection = connection
        scene.onRequestReturnToMenu = { [weak connection] in
            connection?.stopAll()
            dismiss()
        }
        sceneHolder.scene = scene
        return scene
    }
}

#Preview {
    ConfirmationScreenView(connection: GameConnectionManager())
}
