//
//  MainMenuView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 02/07/26.
//

import SwiftUI

struct MainMenuView: View {
    @State private var connection = GameConnectionManager()
    @State private var path = NavigationPath()

    private let menuOptions: [MenuOption] = [
        MenuOption(targetDestination: .createGame),
        MenuOption(targetDestination: .joinGame)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Image(.backgroundMainScreen)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("COWBOY\nSHOOTERS")
                        .font(.titleCSG)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        ForEach(menuOptions) { option in
                            Button {
                                path.append(option.targetDestination)
                            } label: {
                                Text(option.targetDestination.title)
                            }
                            .buttonStyle(.cowboyCompact)
                        }
                    }
                    .padding(.top, 20)
                }

                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                path.append(MenuDestination.helpGame)
                            } label: {
                                Text("?")
                            }
                            .buttonStyle(.cowboyIcon)

                            Button {
                                path.append(MenuDestination.settingsGame)
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .buttonStyle(.cowboyIcon)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }.padding(.top, 20)
            }
            .navigationDestination(for: MenuDestination.self) { destination in
                switch destination {
                case .createGame:
                    CreateGameView(connection: connection)
                case .joinGame:
                    JoinGameView(connection: connection)
                case .helpGame:
                    HelpView()
                case .settingsGame:
                    SettingsView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        // Trigger button di-aktifkan sekali di root, tetap hidup selama app jalan
        .onHardwareTrigger { direction in
            switch direction {
            case .up:
                // TODO: aksi trigger up (misal: shoot)
                break
            case .down:
                // TODO: aksi trigger down
                break
            }
        }
    }
}

#Preview {
    MainMenuView()
}
