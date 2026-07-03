//
//  TemporaryDestinationView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Text("Coming Soon")
                .font(.titleCSG)
        }
        .navigationTitle("Help")
    }
}

