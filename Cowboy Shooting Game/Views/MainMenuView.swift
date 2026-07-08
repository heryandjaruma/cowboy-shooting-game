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

    @AppStorage(GameConnectionManager.playerNameDefaultsKey) private var playerName = ""
    @State private var showNamePrompt = false
    @State private var nameDraft = ""
    @State private var showDrawPoseTest = false

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
                    TitleView()
                        .padding(.top, 20)

                    VStack(spacing: 9) {
                        ForEach(menuOptions) { option in
                            Button {
                                path.append(option.targetDestination)
                            } label: {
                                Text(option.targetDestination.title)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.6)
                                    .allowsTightening(true)
                                    .multilineTextAlignment(.center)
                                    .font(.headingCSG)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.6)
                                    .allowsTightening(true)
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(.cowboyCompact)
                        }

                        Button {
                            nameDraft = playerName
                            showNamePrompt = true
                        } label: {
                            Text("Got a name?")
                        }
                        .buttonStyle(.cowboyCompact)
                    }
                    .padding(.top, 20)
                }

                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 12) {
                            #if DEBUG
                            // Dev-only practice range for the draw pose gate.
                            Button {
                                showDrawPoseTest = true
                            } label: {
                                Text("🎯")
                            }
                            .buttonStyle(.cowboyIcon)
                            #endif

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
            .alert("Got a name?", isPresented: $showNamePrompt) {
                TextField("Enter your name", text: $nameDraft)
                Button("Save") {
                    playerName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("What does the town call you, Slinger?")
            }
            .fullScreenCover(isPresented: $showDrawPoseTest) {
                DrawPoseTestView()
            }
        }
        .onAppear {
            MusicManager.shared.attach(to: connection)
            MusicManager.shared.play(.lobby)
        }
    }
}

#Preview {
    MainMenuView()
}
