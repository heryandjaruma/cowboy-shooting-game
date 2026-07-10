//
//  SplashScreenView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 10/07/26.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        Image(.splashScreen)
            .resizable()
            .ignoresSafeArea()
    }
}

#Preview {
    SplashScreenView()
}
