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
                VStack(spacing: 12) {
                    ForEach(client.discoveredHosts) { host in
                        Button {
                            client.watch(host)
                        } label: {
                            Text(host.name)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.cowboyJoin)
                        .padding(2)
                    }
                }
                .padding(.vertical, 4)
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

    /// Host on the left, challenger on the right — names and hearts.
    private func duelBoard(_ snapshot: SpectatorSnapshot) -> some View {
        HStack(spacing: 24) {
            playerColumn(name: snapshot.hostName, lives: snapshot.hostLives)
            Text("VS")
                .font(.headingCSG)
                .foregroundStyle(.white)
            playerColumn(name: snapshot.joinerName.isEmpty ? "Waiting…" : snapshot.joinerName,
                         lives: snapshot.joinerLives)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primaryCSG)
                .stroke(Color.ternaryCSG, lineWidth: 4)
        )
        .padding(.horizontal, 16)
    }

    private func playerColumn(name: String, lives: Int) -> some View {
        VStack(spacing: 12) {
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

/// Full-screen round-result overlay: dimmed backdrop, the winner's shot stamps
/// the Bang artwork onto the loser's name, then the lost heart flips over.
/// Self-contained — reads nothing from the live board underneath.
private struct RoundBangOverlay: View {
    let result: RoundResult
    let onFinished: () -> Void

    @State private var bangVisible = false
    @State private var heartLost = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            HStack(spacing: 48) {
                column(name: result.hostName, isLoser: result.loserIsHost)
                column(name: result.joinerName, isLoser: !result.loserIsHost)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { bangVisible = true }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeOut(duration: 0.3)) { heartLost = true }
            try? await Task.sleep(for: .seconds(1.4))
            onFinished()
        }
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
                            .offset(x: 30, y: -24)
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
