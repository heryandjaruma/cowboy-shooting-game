//
//  SpectateView.swift
//  Cowboy Shooting Game
//
//  Spectator mode (POC): pick a nearby duel to watch, then see both players'
//  names and remaining lives update live. The host is the source of truth —
//  this screen only renders the snapshots it receives.
//

import SwiftUI

struct SpectateView: View {
    @StateObject private var client = SpectatorClient()
    @Environment(\.dismiss) private var dismiss

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
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { client.startBrowsing() }
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
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < lives ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(minWidth: 120)
    }
}

#Preview {
    SpectateView()
}
