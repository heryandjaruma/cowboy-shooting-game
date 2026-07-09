//
//  MainMenuView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 02/07/26.
//

import SwiftUI
import Lottie

struct MainMenuView: View {
    @State private var connection = GameConnectionManager()
    @State private var path = NavigationPath()

    @State private var showNamePrompt = false
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
                
                LottieView(animation:.named("tumbleweed"))
                    .looping()
                    .animationSpeed(0.7)
                    .resizable()
                    .frame(width: 300,height: 300)
                    .offset(y:170)
                           
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
                                showNamePrompt = true
                            } label: {
                                Image(systemName: "person.fill")
                            }
                            .buttonStyle(.cowboyIcon)

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
            .fullScreenCover(isPresented: $showDrawPoseTest) {
                DrawPoseTestView()
            }
        }
        .overlay {
            if showNamePrompt {
                NamePromptView(
                    onConfirm: { showNamePrompt = false },
                    onCancel: { showNamePrompt = false }
                )
            }
        }
        .onAppear {
            MusicManager.shared.attach(to: connection)
            MusicManager.shared.play(.lobby)
        }
    }
}

struct NamePromptView: View {
    @AppStorage(GameConnectionManager.playerNameDefaultsKey) private var playerName = ""
    @State private var nameDraft = ""
    @State private var randomIndex = 0

    let onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Dimmed backdrop; tapping outside the card cancels when allowed.
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onCancel?() }

            VStack(spacing: 20) {
                Text("What's your name, Slinger?")
                    .font(.headingCSG)
                    .foregroundColor(Color.ternaryCSG)
                    .multilineTextAlignment(.center)

                TextField(text: $nameDraft){
                    Text("You can change it again later")
                        .foregroundStyle(Color.ternaryCSG.opacity(0.5))
                }
                    .font(.bodyCSG)
                    .foregroundColor(Color.ternaryCSG)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(confirmName)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 540)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.secondaryCSG)
                            .stroke(Color.ternaryCSG, lineWidth: 3)
                    )

                HStack (spacing: 20) {
                    Button(action: cycleRandomName) {
                        Text("Random")
                    }
                    .buttonStyle(.cowboyCompact)
                    Spacer()
                    Button(action: confirmName) {
                        Text("OK")
                        .frame(minWidth: 44)
                    }
                    .buttonStyle(.cowboyCompact)
                }
                .frame(maxWidth: 450)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primaryCSG)
                    .stroke(Color.ternaryCSG, lineWidth: 4)
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            // Seed the field with the current name so an existing name shows for editing.
            nameDraft = playerName
            randomIndex = Int.random(in: 0..<max(GameConnectionManager.suggestedNames.count, 1))
        }
    }

    /// Shows the next suggested alias in the field without committing it — the name
    /// is only assigned when the player taps OK.
    private func cycleRandomName() {
        let names = GameConnectionManager.suggestedNames
        guard !names.isEmpty else { return }
        nameDraft = names[randomIndex % names.count]
        randomIndex += 1
    }

    /// Commits the typed name, or falls back to a random alias when left blank.
    private func confirmName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        playerName = trimmed.isEmpty
            ? (GameConnectionManager.suggestedNames.randomElement() ?? "Stranger")
            : trimmed
        onConfirm()
    }
}

#Preview {
    MainMenuView()
}
