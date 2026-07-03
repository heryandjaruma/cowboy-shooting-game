//
//  CreateGameView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//


import SwiftUI

struct CreateGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPulsing = false

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
    }
}

#Preview {
    CreateGameView()
}
