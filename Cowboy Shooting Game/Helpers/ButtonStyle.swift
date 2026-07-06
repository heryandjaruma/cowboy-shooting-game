//
//  ButtonStyle.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct CowboyButtonStyle: ButtonStyle {
    var stretches: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(Color.ternaryCSG)
            .padding(.horizontal, stretches ? 0 : 28)
            .frame(maxWidth: stretches ? .infinity : nil, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primaryCSG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ternaryCSG, lineWidth: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CowboyButtonStyle {
    static var cowboy: CowboyButtonStyle { CowboyButtonStyle(stretches: true) }

    static var cowboyCompact: CowboyButtonStyle { CowboyButtonStyle(stretches: false) }
}

/// ICON ONLY
struct CowboyIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Color.ternaryCSG)
            .frame(width: 44, height: 44)
            .background(
                Image(.buttonRound)
                    .resizable()
                    .scaledToFit()
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CowboyIconButtonStyle {
    static var cowboyIcon: CowboyIconButtonStyle { CowboyIconButtonStyle() }
}
 
struct ButtonPreview : View {
    var body : some View {
        Button{
            //empty
        }label: {
            Text("Hello")
                .font(.headingCSG)
        }
        .buttonStyle(.cowboy)
    }
}

#Preview {
    ButtonPreview()
}
