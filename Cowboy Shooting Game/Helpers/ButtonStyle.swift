//
//  ButtonStyle.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct CowboyButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(Color.ternaryCSG)
            .padding(.horizontal, compact ? 20 : 28)
            .padding(.vertical,10)
            .frame(height: 60)
            .background(
                Image(.button)
                    . resizable(capInsets: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1), resizingMode: .stretch)

            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CowboyButtonJoin: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(Color.ternaryCSG)
            .padding()
            // minHeight (not a fixed height) so a wrapped, multi-line label
            // grows the button instead of overflowing it.
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius:12)
                    .fill(Color.secondaryCSG)
                    .stroke(Color.ternaryCSG,lineWidth: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CowboyButtonStyle {
    static var cowboy: CowboyButtonStyle { CowboyButtonStyle(compact: false) }
    static var cowboyCompact: CowboyButtonStyle { CowboyButtonStyle(compact: true) }
    static var cowboyJoin: CowboyButtonJoin { CowboyButtonJoin() }
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
            Image(systemName: "gear")
        }
        .buttonStyle(.cowboyIcon)
    }
}

#Preview {
    ButtonPreview()
}
