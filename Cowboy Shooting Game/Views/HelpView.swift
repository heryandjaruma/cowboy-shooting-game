//
//  HelpView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 07/07/26.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [String] = [
        "Press “Create game” to host a new game, or you can join a host's game with “Join game” and find any game you wish to join.",
        "Before pressing “Ready,” take a distance between you and the other player as you both face opposite each other.",
        "After receiving the signal to fire, quickly turn your body facing the other player and press the volume button to shoot. The round ends and both players proceed to the next round until game ends.",
        "One game consists of 3-5 rounds. The winner of the game is the player whose lives are still intact."
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)
            VStack {
                ScreenTopBar(title: "Tutorial") {
                    dismiss()
                }

                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.bodyCSG)
                                    .foregroundColor(Color.ternaryCSG)

                                Text(step)
                                    .font(.bodyCSG)
                                    .foregroundColor(Color.ternaryCSG)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primaryCSG)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.ternaryCSG, lineWidth: 4)
                            )
                    )
                }
                .padding(.top,20)
                .padding(.horizontal, 16)

                Spacer()
            }.padding(.top,20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    HelpView()
}
