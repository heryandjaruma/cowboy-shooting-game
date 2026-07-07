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

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                ScreenTopBar(title: "Create Game", trailingName: connection.myName) {
                    connection.stopAll() // leaving the room — tear down here, not on disappear.
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
        .onChange(of: connection.state) { _, newState in
            // A challenger joined — both players meet on the confirmation screen.
            if case .connected = newState {
                navigateToConfirmation = true
            }
        }
        .fullScreenCover(isPresented: $navigateToConfirmation, onDismiss: {
            // Back from the pre-duel screen without a match — host again.
            if case .connected = connection.state {} else {
                connection.startHosting()
            }
        }) {
            ConfirmationScreenView(connection: connection)
        }
    }
}

#Preview {
    CreateGameView(connection: GameConnectionManager())
}
