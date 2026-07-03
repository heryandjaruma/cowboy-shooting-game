//
//  ScreenTopBar.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct ScreenTopBar: View {
    let title: String
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
