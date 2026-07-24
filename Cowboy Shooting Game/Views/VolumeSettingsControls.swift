//
//  VolumeSettingsControls.swift
//  Cowboy Shooting Game
//
//  The audio sliders shared by the main-menu SettingsView and the in-duel
//  volume panel (PauseMenuView), so both stay identical. Owns the AppStorage
//  mix bindings, the Master/device-volume binding, and the hidden system-slider
//  lifecycle that Master needs.
//

import SwiftUI

private struct SettingSliderRow: View {
    let label: LocalizedStringKey
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

/// The Master / Music / SFX / Gunshot sliders as a self-contained block.
struct VolumeSettingsControls: View {
    @ObservedObject private var triggerController = TriggerController.shared

    @AppStorage(AppSettings.musicVolumeKey)   private var musicVolume   = 1.0
    @AppStorage(AppSettings.sfxVolumeKey)     private var sfxVolume     = 1.0
    @AppStorage(AppSettings.gunshotVolumeKey) private var gunshotVolume = 1.0

    var body: some View {
        VStack(spacing: 16) {
            SettingSliderRow(
                label: "Master",
                value: Binding(
                    get: { Double(triggerController.state.baselineTrigger) },
                    set: { triggerController.updateBaseline(Float($0)) }
                ),
                range: 0.05...0.95
            )

            SettingSliderRow(label: "Music",   value: $musicVolume)
            SettingSliderRow(label: "SFX",     value: $sfxVolume)
            SettingSliderRow(label: "Gunshot", value: $gunshotVolume)
        }
        .onChange(of: musicVolume) { _, _ in
            MusicManager.shared.applyMusicVolume()
        }
        // The Master slider sets the DEVICE volume, which needs the hidden
        // system slider — install it only while these controls are on screen.
        // Mid-duel this is a no-op: the trigger already owns the slider.
        .onAppear { triggerController.beginSystemVolumeControl() }
        .onDisappear { triggerController.endSystemVolumeControl() }
    }
}
