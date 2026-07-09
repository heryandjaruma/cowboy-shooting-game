//
//  CreateGameView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//


import SwiftUI
import Lottie

struct CreateGameView: View {
    @ObservedObject var connection: GameConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPulsing = false
    @State private var navigateToConfirmation = false
    @State private var playbackMode : LottiePlaybackMode = .paused

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
                
                LottieView(animation: .named("connectionWifi"))
                    .playing()
                    .looping()
                    .animationSpeed(0.20)
                    .resizable()
                    .frame(width: 200, height: 200)
                
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
