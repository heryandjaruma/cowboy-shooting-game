//
//  LobbyView.swift
//  Cowboy Shooting Game
//
//  Entry screen: pick a role (host or join), then pair with a nearby device.
//  Drives a GameConnectionManager and reflects its state.
//

import SwiftUI
import Network

struct LobbyView: View {
    @StateObject private var connection = GameConnectionManager()
    @StateObject private var shot = ShotController()
    @StateObject private var countdown = CountdownController()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header

                switch connection.state {
                case .idle:
                    roleButtons
                case .hosting:
                    statusCard("Waiting for a challenger…", systemImage: "dot.radiowaves.left.and.right")
                    cancelButton
                case .browsing:
                    browsingList
                    cancelButton
                case .connecting:
                    statusCard("Connecting…", systemImage: "hourglass")
                    cancelButton
                case .connected(let peerName):
                    connectedCard(peerName: peerName)
                    cancelButton
                case .failed(let reason):
                    statusCard(reason, systemImage: "exclamationmark.triangle")
                    Button("Back") { connection.stopAll() }
                        .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Cowboy Duel")
        }
        .task {
            shot.configure(connection: connection)
            countdown.configure(connection: connection, shot: shot)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("You are **\(connection.myName)**")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 32)
    }

    private var roleButtons: some View {
        VStack(spacing: 16) {
            Button {
                connection.startHosting()
            } label: {
                Label("Host a Duel", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                connection.startBrowsing()
            } label: {
                Label("Join a Duel", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }

    private var browsingList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                Text("Searching for hosts…")
                    .foregroundStyle(.secondary)
            }

            if connection.discoveredPeers.isEmpty {
                Text("No hosts found yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(connection.discoveredPeers) { peer in
                    Button {
                        connection.join(peer)
                    } label: {
                        HStack {
                            Image(systemName: "person.wave.2")
                            Text(peer.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func connectedCard(peerName: String) -> some View {
        VStack(spacing: 20) {
            Text("Facing \(peerName)")
                .font(.headline)

            if let outcome = shot.outcome {
                resultView(outcome)
            } else {
                switch countdown.phase {
                case .notReady:
                    if connection.isClockSynced {
                        Button { countdown.pressReady() } label: {
                            Label("Ready", systemImage: "hand.raised.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Getting in position…")
                                .foregroundStyle(.secondary)
                        }
                    }

                case .waiting:
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Step right up.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                case .counting(let n):
                    Text("\(n)")
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                        .id(n)

                case .fire:
                    fireView
                }
            }
        }
        .controlSize(.large)
        .animation(.snappy, value: countdown.phase)
        .animation(.snappy, value: shot.outcome)
    }

    private var fireView: some View {
        Group {
            if shot.didFire {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for the verdict…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button { shot.fire() } label: {
                    Label("DRAW!", systemImage: "scope")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private func resultView(_ outcome: ShotController.Outcome) -> some View {
        VStack(spacing: 12) {
            Text(outcome == .winner ? "🏆 Winner!" : "💀 Loser")
                .font(.largeTitle.bold())
                .foregroundStyle(outcome == .winner ? .green : .red)
            Button("Play again") { countdown.reset() }
                .buttonStyle(.bordered)
        }
    }

    private func statusCard(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button(role: .cancel) {
            connection.stopAll()
        } label: {
            Text("Cancel")
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    LobbyView()
}
