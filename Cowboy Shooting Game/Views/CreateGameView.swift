//
//  CreateGameView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//


import SwiftUI

struct CreateGameView: View {
    @ObservedObject var connection: GameConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPulsing = false
    @State private var navigateToConfirmation = false
    @State private var returnToMenuOnDismiss = false

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
                ScreenTopBar(title: "CREATE GAME", trailingName: connection.myName) {
                    connection.stopAll() // leaving the room — tear down here, not on disappear.
                    dismiss()
                }

                Spacer()

                Image(.wifi)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)

                Spacer()

                Text("Game created, waiting for a player.")
                    .font(.headingCSG)
                    .foregroundStyle(.white)
                    .padding(.bottom, 30)
            }.padding(.top,20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { connection.startHosting() }
        .onChange(of: connection.state) { _, newState in
            // A challenger joined — both players meet on the confirmation screen.
            if case .connected = newState {
                navigateToConfirmation = true
            }
        }
        .fullScreenCover(isPresented: $navigateToConfirmation, onDismiss: {
            if returnToMenuOnDismiss {
                // Connection was lost mid-duel — unwind to the main menu.
                dismiss()
            } else if case .connected = connection.state {} else {
                // Back from the pre-duel screen without a match — host again.
                connection.startHosting()
            }
            // onAppear does NOT re-fire when a fullScreenCover dismisses, so the
            // music hand-back (game-over/gameplay → lobby) must happen here.
            MusicManager.shared.play(.lobby)
        }) {
            ConfirmationScreenView(connection: connection, onReturnToMenu: {
                returnToMenuOnDismiss = true
                navigateToConfirmation = false
            })
        }
    }
}

#Preview {
    CreateGameView(connection: GameConnectionManager())
}
