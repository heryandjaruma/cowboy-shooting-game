//
//  SpectateView.swift
//  Cowboy Shooting Game
//
//  Spectator mode (POC): pick a nearby duel to watch, then see both players'
//  names and remaining lives update live. The host is the source of truth —
//  this screen only renders the snapshots it receives. When a life is lost, a
//  self-contained overlay above a dimmed screen stamps the Bang artwork on the
//  loser's name and animates the heart deduction.
//

import SwiftUI

/// One round's outcome, derived by diffing two consecutive snapshots.
private struct RoundResult: Equatable {
    let id = UUID()
    let hostName: String
    let joinerName: String
    let loserIsHost: Bool
    let loserLivesAfter: Int
}

struct SpectateView: View {
    @StateObject private var client = SpectatorClient()
    @Environment(\.dismiss) private var dismiss
    @State private var roundResult: RoundResult?

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)

            VStack(spacing: 20) {
                ScreenTopBar(title: "SPECTATE") {
                    client.stop()
                    MusicManager.shared.play(.lobby)
                    dismiss()
                }

                Spacer()

                if let snapshot = client.snapshot {
                    duelBoard(snapshot)
                } else if client.isConnected {
                    Text("Waiting for the duel…")
                        .font(.headingCSG)
                        .foregroundStyle(.white)
                } else {
                    hostList
                }

                Spacer()
            }
            .padding(.top, 20)

            if let roundResult {
                RoundBangOverlay(result: roundResult) {
                    withAnimation(.easeOut(duration: 0.4)) { self.roundResult = nil }
                }
                .id(roundResult.id) // a fresh result restarts the whole sequence
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            client.startBrowsing()
            MusicManager.shared.stop(fade: true) // the duel's audio takes over here
        }
        .onChange(of: client.snapshot) { old, new in
            // A drop in either player's lives means the other one landed a hit.
            guard let old, let new,
                  old.hostName == new.hostName, old.joinerName == new.joinerName else { return }
            let result: RoundResult?
            if new.hostLives < old.hostLives {
                result = RoundResult(hostName: new.hostName, joinerName: new.joinerName,
                                     loserIsHost: true, loserLivesAfter: new.hostLives)
            } else if new.joinerLives < old.joinerLives {
                result = RoundResult(hostName: new.hostName, joinerName: new.joinerName,
                                     loserIsHost: false, loserLivesAfter: new.joinerLives)
            } else {
                result = nil
            }
            if let result {
                withAnimation(.easeIn(duration: 0.25)) { roundResult = result }
            }
        }
    }

    /// The lobby list — same shape as Join Game, but read-only feeds.
    private var hostList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duels Nearby")
                .font(.headingCSG)
                .foregroundColor(Color.ternaryCSG)

            if client.discoveredHosts.isEmpty {
                Text("Looking for a duel to watch…")
                    .font(.bodyCSG)
                    .foregroundColor(Color.ternaryCSG.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Scrolls once the list outgrows the box instead of pushing it
                // off screen; long host names wrap rather than truncate.
                CowboyScrollView {
                    VStack(spacing: 12) {
                        ForEach(client.discoveredHosts) { host in
                            Button {
                                client.watch(host)
                            } label: {
                                Text(host.name)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .buttonStyle(.cowboyJoin)
                            .padding(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryCSG)
                .stroke(Color.ternaryCSG, lineWidth: 4)
        )
        .padding(.horizontal, 16)
    }

    /// Host on the left, challenger on the right — names and hearts. Once a
    /// player hits 0 lives the duel is decided, so each side gets its verdict
    /// artwork; a rematch or new challenger re-broadcasts 3-3 and clears it.
    private func duelBoard(_ snapshot: SpectatorSnapshot) -> some View {
        let matchOver = snapshot.hostLives == 0 || snapshot.joinerLives == 0
        return HStack(spacing: 24) {
            playerColumn(name: snapshot.hostName, lives: snapshot.hostLives,
                         won: matchOver ? snapshot.hostLives > 0 : nil)
            Text("VS")
                .font(.headingCSG)
                .foregroundStyle(.white)
            playerColumn(name: snapshot.joinerName.isEmpty ? "Waiting…" : snapshot.joinerName,
                         lives: snapshot.joinerLives,
                         won: matchOver ? snapshot.joinerLives > 0 : nil)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryCSG)
                .stroke(Color.ternaryCSG, lineWidth: 4)
        )
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: snapshot)
    }

    /// `won` is nil while the duel is still running.
    private func playerColumn(name: String, lives: Int, won: Bool?) -> some View {
        VStack(spacing: 12) {
            if let won {
                Image(won ? "victory" : "game_over")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 44)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(name)
                .font(.headingCSG)
                .foregroundColor(Color.ternaryCSG)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            heartsRow(lives: lives)
        }
        .frame(minWidth: 120)
    }
}

/// The in-game heart artwork, one row of three.
private func heartsRow(lives: Int, size: CGFloat = 34) -> some View {
    HStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { index in
            Image(index < lives ? "Life_full" : "lost_life")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

/// Full-screen round-result overlay: dimmed backdrop, the winner's revolver
/// swings up, levels at the loser, and fires — the Bang artwork stamps onto
/// the loser's name and the lost heart flips over. Self-contained — reads
/// nothing from the live board underneath.
private struct RoundBangOverlay: View {
    let result: RoundResult
    let onFinished: () -> Void

    @State private var gunLeveled = false
    @State private var bangVisible = false
    @State private var heartLost = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            HStack(spacing: 32) {
                column(name: result.hostName, isLoser: result.loserIsHost)
                gun
                column(name: result.joinerName, isLoser: !result.loserIsHost)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.3))
            // Swing the revolver down from the draw until it levels at the loser…
            withAnimation(.easeOut(duration: 0.4)) { gunLeveled = true }
            try? await Task.sleep(for: .seconds(0.55))
            // …fire: Bang stamps the loser's name, the gun kicks with recoil.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { bangVisible = true }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeOut(duration: 0.3)) { heartLost = true }
            // Hold the end result so people can take it in.
            try? await Task.sleep(for: .seconds(1.8))
            onFinished()
        }
    }

    /// The winner's revolver, aimed across at the loser. The asset points left,
    /// so mirror it when the loser sits on the right. Rotation is applied
    /// before the mirror, which flips the swing and recoil along with it.
    private var gun: some View {
        Image("Peacemaker_gun")
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 130)
            .rotationEffect(.degrees(gunRotation))
            .scaleEffect(x: result.loserIsHost ? 1 : -1, y: 1)
    }

    /// Muzzle up at the draw (+55°), level to aim (0°), kick up on the shot.
    private var gunRotation: Double {
        if bangVisible { return 18 }
        return gunLeveled ? 0 : 55
    }

    private func column(name: String, isLoser: Bool) -> some View {
        VStack(spacing: 16) {
            nameBox(name)
                // The winner's box kicks up as their shot lands.
                .scaleEffect(bangVisible && !isLoser ? 1.08 : 1.0)
                .overlay {
                    if isLoser && bangVisible {
                        Image("Bang")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 150)
                            .rotationEffect(.degrees(-12))
                            // Toward the gun in the middle, whichever side that is.
                            .offset(x: result.loserIsHost ? 30 : -30, y: -24)
                            .transition(.scale(scale: 3).combined(with: .opacity))
                    }
                }

            if isLoser {
                loserHearts
            }
        }
    }

    /// The loser's hearts: the doomed one swells while the Bang lands, then
    /// flips to the lost-life artwork.
    private var loserHearts: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let isFull = heartLost ? index < result.loserLivesAfter
                                       : index < result.loserLivesAfter + 1
                Image(isFull ? "Life_full" : "lost_life")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .scaleEffect(index == result.loserLivesAfter && bangVisible && !heartLost
                                 ? 1.35 : 1.0)
            }
        }
    }

    private func nameBox(_ name: String) -> some View {
        Text(name)
            .font(.headingCSG)
            .foregroundColor(Color.ternaryCSG)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondaryCSG)
                    .stroke(Color.ternaryCSG, lineWidth: 3)
            )
    }
}

#Preview {
    SpectateView()
}
