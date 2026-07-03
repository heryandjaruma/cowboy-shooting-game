//
//  SettingsView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//


import SwiftUI

struct SettingsView: View {
    @ObservedObject private var triggerController = TriggerController.shared

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Use Slider to change the Volumi")
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Game Volume:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(triggerController.state.baselineTrigger * 100))%")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)

                        Slider(
                            value: Binding(
                                get: { triggerController.state.baselineTrigger },
                                set: { triggerController.updateBaseline($0) }
                            ),
                            in: 0.05...0.95
                        )

                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
