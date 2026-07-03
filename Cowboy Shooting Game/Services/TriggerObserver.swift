//
//  TriggerObserver.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//



import SwiftUI
 
/// Modifier ini yang bikin fungsi trigger bisa dipakai ulang di View manapun.
/// Dia TIDAK bikin TriggerController baru — dia cuma numpang ke `TriggerController.shared`
/// dan menitipkan closure aksi khusus untuk View yang memasangnya.
struct TriggerObserverModifier: ViewModifier {
 
    @ObservedObject private var controller = TriggerController.shared
    let action: (TriggerDirection) -> Void
    var showBuiltInIndicator: Bool = true
 
    func body(content: Content) -> some View {
        content
            .onAppear {
                controller.reactivate()
                controller.onTrigger = action
            }
            .onDisappear {
                // Bersihkan supaya View lain gak ketimpa aksi View ini
                if controller.onTrigger != nil {
                    controller.onTrigger = nil
                }
            }
            .overlay(alignment: .top) {
                if showBuiltInIndicator && controller.state.showIndicator {
                    TriggerIndicatorBadge(message: controller.state.statusMessage)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
    }
}
 
private struct TriggerIndicatorBadge: View {
    let message: String
 
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.and.mic")
                .foregroundColor(.white)
            Text(message)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}
 
extension View {
    /// Pasang di View manapun untuk mendengarkan tombol hardware sebagai trigger.
    ///
    ///     SomeView()
    ///         .onHardwareTrigger { direction in
    ///             switch direction {
    ///             case .up:   // aksi khusus untuk View ini
    ///             case .down: // aksi khusus untuk View ini
    ///             }
    ///         }
    func onHardwareTrigger(
        showIndicator: Bool = true,
        action: @escaping (TriggerDirection) -> Void
    ) -> some View {
        modifier(TriggerObserverModifier(action: action, showBuiltInIndicator: showIndicator))
    }
}
 
