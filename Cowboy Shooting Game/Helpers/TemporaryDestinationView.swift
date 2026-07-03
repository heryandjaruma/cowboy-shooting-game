//
//  TemporaryDestinationView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

struct CreateGameView: View {
    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Text("Create Game")
                .font(.titleCSG)
        }
        .navigationTitle("Create Game")
    }
}

struct JoinGameView: View {
    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Text("Join Game")
                .font(.titleCSG)
        }
        .navigationTitle("Join Game")
    }
}

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

