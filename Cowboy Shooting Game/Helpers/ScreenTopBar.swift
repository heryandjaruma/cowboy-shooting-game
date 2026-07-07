//
//  ScreenTopBar.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct ScreenTopBar: View {
    let title: LocalizedStringKey
    /// Optional player name shown on the right — helps others spot the right
    /// lobby / opponent even when using a defaulted alias.
    var trailingName: String? = nil
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Text("<")
            }
            .buttonStyle(.cowboyIcon)

            Text(title)
                .font(.headingCSG)
                .foregroundColor(Color.ternaryCSG)
                .padding()
                .background (
                    RoundedRectangle(cornerRadius:14)
                        .stroke(Color.ternaryCSG, lineWidth: 4)
                        .fill(Color.primaryCSG))
            Spacer()

            if let trailingName, !trailingName.isEmpty {
                Text(trailingName)
                    .font(.headingCSG2)
                    .foregroundColor(Color.ternaryCSG)
                    .lineLimit(1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.ternaryCSG, lineWidth: 4)
                            .fill(Color.secondaryCSG))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

#Preview {
    ZStack {
        Color.brown.ignoresSafeArea()
        ScreenTopBar(title: "Join Game") {}
    }
}
