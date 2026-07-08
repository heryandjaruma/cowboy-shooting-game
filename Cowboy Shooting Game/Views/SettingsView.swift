//
//  SettingsView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

private struct SettingRow: View {
    let label: String
    let options: [String]
    @Binding var selection: Int
    private var value: String {
        options.indices.contains(selection) ? options[selection] : ""
    }
    
    private func cycle(by delta: Int){
        guard !options.isEmpty else { return }
        let count = options.count
        selection = ((selection + delta) % count + count) % count
    }
    
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
                Button{ cycle(by: -1) } label:{
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.cowboyIcon)
                .disabled(options.count < 2)

                Spacer()

                Text(value)
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)
                    .lineLimit(1)

                Spacer()

                Button{ cycle(by: 1) } label:{
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.cowboyIcon)
                .disabled(options.count < 2)
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

    // Helpers/AppSettings for these
    @AppStorage(AppSettings.languageKey) private var languageCode = AppSettings.defaultLanguageCode
    @AppStorage(AppSettings.grayscaleKey) private var grayscaleEnabled = true

    @AppStorage(AppSettings.masterVolumeKey)  private var masterVolume  = 1.0
    @AppStorage(AppSettings.sfxVolumeKey)     private var sfxVolume     = 1.0
    @AppStorage(AppSettings.gunshotVolumeKey) private var gunshotVolume = 1.0

    private let grayscaleOptions = ["OFF", "ON"]

    private var languageIndex: Binding<Int> {
        Binding(
            get: { AppSettings.languageCodes.firstIndex(of: languageCode) ?? 0 },
            set: { languageCode = AppSettings.languageCodes[$0] }
        )
    }

    private var grayscaleIndex: Binding<Int> {
        Binding(
            get: { grayscaleEnabled ? 1 : 0 },
            set: { grayscaleEnabled = ($0 == 1) }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)

            VStack(spacing: 0) {
                ScreenTopBar(title: "SETTINGS") {
                    dismiss()
                }
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 16) {
                        SettingRow(label: "Language", options: AppSettings.languageNames, selection: languageIndex)
                        SettingRow(label: "Grayscale Mode", options: grayscaleOptions, selection: grayscaleIndex)

                        SettingSliderRow(
                            label: "Trigger Level",
                            value: Binding(
                                get: { Double(triggerController.state.baselineTrigger) },
                                set: { triggerController.updateBaseline(Float($0)) }
                            ),
                            range: 0.05...0.95
                        )

                        SettingSliderRow(label: "Master Volume",  value: $masterVolume)
                        SettingSliderRow(label: "SFX Volume",     value: $sfxVolume)
                        SettingSliderRow(label: "Gunshot Volume", value: $gunshotVolume)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: masterVolume) { _, _ in
            MusicManager.shared.applyMasterVolume()
        }
    }
}

#Preview {
    SettingsView()
}
