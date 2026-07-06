//
//  Typography.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 02/07/26.
//

import SwiftUI

// MARK: - FONT

extension Font {
    static var titleCSG: Font { .custom("WildWestPixel", size: 36)}
    static var headingCSG: Font { .custom("VCROSDMono", size: 24)}
    static var headingCSG2: Font { .custom("VCROSDMono", size: 18)}
}


// MARK: - COLORS
extension Color {
    static let primaryCSG = Color(red: 215/255, green: 175/255, blue: 109/255)
    static let secondaryCSG = Color(red: 234/255, green: 211/255, blue: 173/255)
    static let ternaryCSG = Color(red: 93/255, green: 50/255, blue: 43/255)
}

struct TitleView : View {
    var body: some View {
        ZStack {
            Text("COWBOY SHOOTERS\nBANG BANG")
                .font(.titleCSG)
                .foregroundStyle(Color(.black))
                .multilineTextAlignment(.center)
                .offset(x:3,y:3)
            Text("COWBOY SHOOTERS\nBANG BANG")
                .font(.titleCSG)
                .foregroundStyle(Color(.black))
                .multilineTextAlignment(.center)
                .offset(x:-3,y:-3)
            Text("COWBOY SHOOTERS\nBANG BANG")
                .font(.titleCSG)
                .foregroundStyle(Color(.black))
                .multilineTextAlignment(.center)
                .offset(x:-3,y:3)
            Text("COWBOY SHOOTERS\nBANG BANG")
                .font(.titleCSG)
                .foregroundStyle(Color(.black))
                .multilineTextAlignment(.center)
                .offset(x:3,y:-3)
        }.overlay(
            Text("COWBOY SHOOTERS\nBANG BANG")
            .font(.titleCSG)
            .foregroundStyle(Color(.white))
            .multilineTextAlignment(.center))
    }
}

struct TypographyPreview : View {
    var body: some View {
        Text("Hello, World!")
            .font(.titleCSG)
        Text("Hello, World!")
            .font(.headingCSG)
    }
}

#Preview {
    TitleView()
}
