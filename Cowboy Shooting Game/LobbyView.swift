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
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Connected to \(peerName)")
                .font(.headline)

            // Scaffolding hook: prove the pipe works end-to-end.
            Button("Send test shot") {
                connection.sendEvent(Data("bang".utf8))
            }
            .buttonStyle(.bordered)

            if !connection.eventLog.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(connection.eventLog.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
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
