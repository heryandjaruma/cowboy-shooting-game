//
//  HelpView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 07/07/26.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    // The app overrides the language via `.environment(\.locale, …)`. `String(localized:)`
    // ignores that, so we read it here and resolve each step against it explicitly.
    @Environment(\.locale) private var locale
    private let steps: [LocalizedStringResource] = [
        "Press **“Create game”** to host a new game, or you can join a host's game with **“Join game”** and find any game you wish to join.",
        "Before pressing **“Ready,”** take a distance between you and the other player. While this is not required for gameplay, it is advised to **avoid physical** contact with the other player.",
        "After receiving the signal to fire, quickly **flick your phone upwards**. Raising your whole arm or flicking up your wrist work as long as the **top or bottom** side of your phone is pointing towards the opponent.",
        "Press either one of your **volume button** to fire. The fastest slinger wins.",
        "Each player has **3 lives**. The last one standing will take the match."
    ]

    private func highlighted(_ resource: LocalizedStringResource) -> AttributedString {
        // Resolve against the in-app locale, not the process default, so the tutorial
        // follows the language chosen in Settings like the rest of the UI.
        var resource = resource
        resource.locale = locale
        let raw = String(localized: resource)

        var attributed = (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
        attributed.font = Font.bodyCSG
        attributed.foregroundColor = Color.ternaryCSG.opacity(0.7)

        for run in attributed.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            attributed[run.range].font = Font.bodyCSG
            attributed[run.range].foregroundColor = Color.ternaryCSG.opacity(1.0)
        }
        return attributed
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

                                Text(highlighted(step))
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
