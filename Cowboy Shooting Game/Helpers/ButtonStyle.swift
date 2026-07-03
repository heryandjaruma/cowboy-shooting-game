//
//  ButtonStyle.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct CowboyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 0.42, green: 0.24, blue: 0.15))
            .frame(width: 220, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.82, green: 0.65, blue: 0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.42, green: 0.24, blue: 0.15), lineWidth: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CowboyButtonStyle {
    static var cowboy: CowboyButtonStyle { CowboyButtonStyle() }
}

/// ICON ONLY
struct CowboyIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Color(red: 0.42, green: 0.24, blue: 0.15))
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color(red: 0.82, green: 0.65, blue: 0.42))
            )
            .overlay(
                Circle()
                    .stroke(Color(red: 0.42, green: 0.24, blue: 0.15), lineWidth: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
 
extension ButtonStyle where Self == CowboyIconButtonStyle {
    static var cowboyIcon: CowboyIconButtonStyle { CowboyIconButtonStyle() }
}
 
