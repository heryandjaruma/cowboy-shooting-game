//
//  SettingsView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

private struct SettingRow: View {
    let label: String
    let value: String
    var onDecrease: () -> Void = {}
    var onIncrease: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.headingCSG)
                .foregroundColor(Color.ternaryCSG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primaryCSG)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.ternaryCSG, lineWidth: 3)
                        )
                )

            HStack {
                Button(action: onDecrease) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.cowboyIcon)

                Spacer()

                Text(value)
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)

                Spacer()

                Button(action: onIncrease) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.cowboyIcon)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondaryCSG)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.ternaryCSG, lineWidth: 3)
                    )
            )
        }
    }
}

private struct SettingSliderRow: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range)
                .tint(Color.ternaryCSG)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryCSG)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.ternaryCSG, lineWidth: 3)
                )
        )
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var triggerController = TriggerController.shared

    var body: some View {
        ZStack(alignment: .top) {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)

            VStack(spacing: 20) {
                ScreenTopBar(title: "SETTINGS") {
                    dismiss()
                }

                VStack(spacing: 16) {
                    SettingRow(label: "Language", value: "English")
                    SettingRow(label: "Grayscale Mode", value: "OFF")

                    SettingSliderRow(
                        label: "Gunshot Noise",
                        value: Binding(
                            get: { Double(triggerController.state.baselineTrigger) },
                            set: { triggerController.updateBaseline(Float($0)) }
                        ),
                        range: 0.05...0.95
                    )
                }
                .padding(.horizontal, 16)

                Spacer()
            }.padding(.top,20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
}
