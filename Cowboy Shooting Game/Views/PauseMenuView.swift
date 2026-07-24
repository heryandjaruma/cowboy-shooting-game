import SwiftUI

struct PauseMenuView: View {
    @ObservedObject var matchController: MatchController

    // Which overlay is open. Kept separate from `matchController.isPaused`
    // (that flag only tells the SpriteKit engine to freeze) so the surrender
    // prompt and the audio panel never appear at the same time.
    @State private var showSurrenderConfirm = false
    @State private var showSettings = false

    // Using the font name from your folder structure
    let customFont = "WildWestPixel"
    let darkBrown = Color(red: 0.3, green: 0.15, blue: 0.1)
    let tanBackground = Color(red: 0.9, green: 0.75, blue: 0.5)

    /// Once the duel is decided the SpriteKit scene owns the screen (victory /
    /// game over graphic + "tap to return"), so the in-game controls step aside.
    private var isMatchOver: Bool {
        if case .matchOver = matchController.matchPhase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // 1. The in-game controls (Bottom Left) — hidden once the match ends
            if !isMatchOver {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        circleButton(systemName: "flag.fill") {
                            openOverlay { showSurrenderConfirm = true }
                        }
                        circleButton(systemName: "speaker.wave.2.fill") {
                            openOverlay { showSettings = true }
                        }
                        Spacer()
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 30)
                }
            }

            // 2. The Surrender confirmation modal
            if showSurrenderConfirm && !isMatchOver {
                surrenderConfirmationOverlay
            }

            // 3. The audio settings modal
            if showSettings && !isMatchOver {
                settingsOverlay
            }
        }
        // Match ended while an overlay was open (e.g. the opponent surrendered):
        // drop the local overlay state so nothing lingers over the result screen.
        .onChange(of: isMatchOver) { _, over in
            if over {
                showSurrenderConfirm = false
                showSettings = false
            }
        }
    }

    // MARK: - Bottom-left buttons

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .padding(12)
                .frame(width: 50, height: 50)
                .foregroundColor(darkBrown)
                .background(tanBackground)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(darkBrown, lineWidth: 4)
                )
        }
    }

    /// Opens one overlay while freezing the SpriteKit engine.
    private func openOverlay(_ open: () -> Void) {
        withAnimation(.easeInOut(duration: 0.2)) {
            open()
            matchController.isPaused = true
        }
    }

    /// Closes any open overlay and resumes the SpriteKit engine.
    private func closeOverlays() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showSurrenderConfirm = false
            showSettings = false
            matchController.isPaused = false
        }
    }

    // MARK: - Overlays

    private var surrenderConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("Are you sure you want to surrender?")
                    .font(.custom(customFont, size: 24))
                    .foregroundColor(darkBrown)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                HStack(spacing: 30) {
                    // YES Button
                    Button(action: {
                        showSurrenderConfirm = false
                        matchController.surrenderMatch()
                    }) {
                        modalLabel("Yes")
                    }

                    // NO Button
                    Button(action: { closeOverlays() }) {
                        modalLabel("No")
                    }
                }
            }
            .padding(30)
            .background(Color(red: 0.95, green: 0.8, blue: 0.55)) // Lighter tan for the main box
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(darkBrown, lineWidth: 8)
            )
            .padding(.horizontal, 40)
        }
    }

    private func modalLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom(customFont, size: 22))
            .foregroundColor(darkBrown)
            .frame(width: 120, height: 44)
            .background(tanBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(darkBrown, lineWidth: 6)
            )
    }

    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("AUDIO")
                        .font(.headingCSG)
                        .foregroundColor(Color.ternaryCSG)
                    Spacer()
                    Button { closeOverlays() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.cowboyIcon)
                }

                ScrollView {
                    VolumeSettingsControls()
                        .padding(.vertical, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondaryCSG)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.ternaryCSG, lineWidth: 4)
                    )
            )
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
        }
    }
}
