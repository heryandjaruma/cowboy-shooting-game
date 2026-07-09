//
//  OnboardingView.swift
//  Cowboy Shooting Game

import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void

    private enum Phase {
        case name
        case welcome
    }

    @State private var phase: Phase = .name

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            switch phase {
            case .name:
                // No cancel button following sketch
                NamePromptView(onConfirm: { phase = .welcome })
            case .welcome:
                WelcomeCard(onOK: onFinished)
            }
        }
    }
}

private struct WelcomeCard: View {
    let onOK: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Welcome to the duel. Shoot fast and stay alive to win. Lose 3 lives? Game over.")
                    .font(.bodyCSG)
                    .foregroundColor(Color.ternaryCSG)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOK) {
                    Text("OK")
                        .frame(minWidth: 44)
                }
                .buttonStyle(.cowboyCompact)
            }
            .padding(24)
            .frame(maxWidth: 540)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primaryCSG)
                    .stroke(Color.ternaryCSG, lineWidth: 4)
            )
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
