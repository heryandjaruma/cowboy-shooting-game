//
//  AudioManager.swift
//  Cowboy Shooting Game
//
//  Created by Heryan Djaruma on 08/07/26.
//

import AVFoundation
import Combine

enum MusicTrack: String {
    case lobby = "MusicLobby"
    case gameplay = "MusicGameplay"
    case gameOver = "MusicGameOver"

    // Compact wire ID used in the audio sync message (1 byte).
    var id: UInt8 {
        switch self {
        case .lobby:    return 0
        case .gameplay: return 1
        case .gameOver: return 2
        }
    }

    static func from(id: UInt8) -> MusicTrack? {
        switch id {
        case 0: return .lobby
        case 1: return .gameplay
        case 2: return .gameOver
        default: return nil
        }
    }
}

// Singleton
final class MusicManager: ObservableObject {
    static let shared = MusicManager()

    private var player: AVAudioPlayer?
    private var currentTrack: MusicTrack?

    @Published var isMuted: Bool = false

    // MARK: - Sync state

    private weak var connectionManager: GameConnectionManager?

    // Host-clock nanosecond timestamp recorded the moment the current track started.
    // The host broadcasts this; the joiner uses it to seek to the matching position.
    private var trackStartHostNanos: UInt64 = 0

    // Timer that fires every 2 s on the host side to push a heartbeat to the joiner.
    private var heartbeatTimer: Timer?

    // Audio sync message op-codes.
    private enum AudioOp {
        static let sync: UInt8 = 0   // music track + position
        static let voice: UInt8 = 1  // one-shot announcer line (spectator link only)
    }

    // One-shot announcer line relayed to spectators (e.g. ReadyForShowdownSFX).
    private var voicePlayer: AVAudioPlayer?

    // Drift smaller than this is inaudible; only correct if it exceeds this threshold.
    private static let driftThreshold: Double = 0.05  // seconds

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Public API

    /// Wire the music manager to the live peer connection.
    /// Call once — e.g. in MainMenuView.onAppear — so the manager can send and
    /// receive sync messages whenever a track plays.
    func attach(to gcm: GameConnectionManager) {
        connectionManager = gcm
        gcm.onEvent(channel: GameChannel.audio.rawValue) { [weak self] body in
            self?.handleAudioSync(body)
        }
    }

    /// Declare what should be playing on the current screen: starts `track`,
    /// or simply continues if it's already the current track.
    func play(_ track: MusicTrack, loop: Bool = true, crossfade: Bool = true) {
        guard currentTrack != track else { return }

        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a") else {
            print("Missing audio file: \(track.rawValue)")
            return
        }

        // Claim the track immediately, so a play() landing during a fading
        // stop()/crossfade isn't swallowed by the stale currentTrack.
        currentTrack = track
        if crossfade, let oldPlayer = player {
            player = nil
            fadeOut(oldPlayer) { [weak self] in
                guard let self, self.currentTrack == track else { return }
                self.startNewPlayer(url: url, track: track, loop: loop)
            }
        } else {
            player?.stop()
            player = nil
            startNewPlayer(url: url, track: track, loop: loop)
        }
    }

    func stop(fade: Bool = true) {
        stopHeartbeat()
        guard let player else { return }
        // Clear immediately so a play() during the fade isn't ignored.
        self.player = nil
        currentTrack = nil

        if fade {
            fadeOut(player) {}
        } else {
            player.stop()
        }
    }

    // MARK: - Private playback

    private func startNewPlayer(url: URL, track: MusicTrack, loop: Bool) {
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = loop ? -1 : 0
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()
            self.player = newPlayer
            self.currentTrack = track
            fadeIn(newPlayer)

            // Host: stamp the start time and begin broadcasting it so the joiner
            // can lock onto the same playback position.
            guard let gcm = connectionManager, gcm.isHost else { return }
            let now = DispatchTime.now().uptimeNanoseconds
            trackStartHostNanos = now
            broadcastSync(track: track, hostStartNanos: now)
            startHeartbeat()
        } catch {
            print("Playback error: \(error)")
        }
    }

    // MARK: - Host: broadcast sync

    private func broadcastSync(track: MusicTrack, hostStartNanos: UInt64) {
        guard let gcm = connectionManager else { return }
        // Payload: [op:UInt8][trackId:UInt8][hostStartNanos:UInt64 LE = 8 bytes]
        var body = Data([AudioOp.sync, track.id])
        body += BinaryCoding.encode(hostStartNanos)
        gcm.sendEvent(channel: GameChannel.audio.rawValue, body: body)

        // Spectators get elapsed-in-track instead of a host timestamp — their
        // link has no clock sync, and one-way LAN latency is well below the
        // drift threshold; the heartbeat keeps correcting them anyway.
        // Lobby music stays local: spectators hear only the duel's audio.
        guard track != .lobby else { return }
        let elapsed = DispatchTime.now().uptimeNanoseconds - hostStartNanos
        var relayBody = Data([AudioOp.sync, track.id])
        relayBody += BinaryCoding.encode(elapsed)
        gcm.relayToSpectators(channel: GameChannel.audio.rawValue, body: relayBody)
    }

    /// Host: relay a one-shot announcer line (e.g. "Ready for showdown") to
    /// spectators so they hear the round beats too. A no-op on the joiner.
    func relayVoiceLineToSpectators(_ resource: String) {
        var body = Data([AudioOp.voice])
        body.append(Data(resource.utf8))
        connectionManager?.relayToSpectators(channel: GameChannel.audio.rawValue, body: body)
    }

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let track = self.currentTrack,
                      let gcm = self.connectionManager,
                      gcm.isHost else { return }
                self.broadcastSync(track: track, hostStartNanos: self.trackStartHostNanos)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - Joiner: receive sync

    /// Decode an incoming audio sync message and align local playback to the host's
    /// current position. Both phones end up at the same timestamp in the track,
    /// effectively syncing to the most advanced playback position (the host's).
    private func handleAudioSync(_ body: Data) {
        guard let gcm = connectionManager, !gcm.isHost else { return }
        // body: [op:UInt8][trackId:UInt8][hostStartNanos:UInt64 = 8 bytes] = 10 bytes
        guard body.count >= 10,
              body[0] == AudioOp.sync,
              let track = MusicTrack.from(id: body[1]),
              let hostStartNanos = BinaryCoding.decodeU64(Data(body.dropFirst(2))) else { return }

        // Convert the host's start timestamp to the local clock, then compute how
        // far into the track the host is right now. Both phones derive the same
        // elapsed value, so they play the same audio frame at the same real instant.
        let localStartNanos = gcm.localUptime(forHostNanos: hostStartNanos)
        let nowNanos = DispatchTime.now().uptimeNanoseconds
        let expectedPosition = nowNanos >= localStartNanos
            ? Double(nowNanos - localStartNanos) / 1_000_000_000
            : 0.0

        syncPlayback(track: track, expectedPosition: expectedPosition)
    }

    // MARK: - Spectator: receive relayed audio

    /// Apply an audio event relayed over the spectator link: either a music
    /// sync (track + elapsed seconds) or a one-shot announcer line.
    func handleSpectatorAudio(_ body: Data) {
        switch body.first {
        case AudioOp.sync:
            // body: [op][trackId][elapsedNanos:UInt64 = 8 bytes] = 10 bytes
            guard body.count >= 10,
                  let track = MusicTrack.from(id: body[1]),
                  let elapsedNanos = BinaryCoding.decodeU64(Data(body.dropFirst(2))) else { return }
            syncPlayback(track: track, expectedPosition: Double(elapsedNanos) / 1_000_000_000)
        case AudioOp.voice:
            playVoiceLine(named: String(decoding: body.dropFirst(), as: UTF8.self))
        default:
            break
        }
    }

    private func playVoiceLine(named resource: String) {
        let url = Bundle.main.url(forResource: resource, withExtension: "mp3")
            ?? Bundle.main.url(forResource: resource, withExtension: "m4a")
        guard let url else {
            print("Missing voice line: \(resource)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = AppSettings.sfxVolume
            player.prepareToPlay()
            player.play()
            voicePlayer = player
        } catch {
            print("Failed to play voice line \(resource): \(error)")
        }
    }

    /// Start `track` at `expectedPosition`, or drift-correct if it's already
    /// the current track. Shared by the joiner and spectator sync paths.
    private func syncPlayback(track: MusicTrack, expectedPosition: Double) {
        if currentTrack == track, let player {
            // Same track already playing — drift correction only (no fade, inaudible seek).
            let drift = expectedPosition - player.currentTime
            if abs(drift) > Self.driftThreshold {
                player.currentTime = expectedPosition
            }
        } else {
            // Different (or no) track — start it and seek directly to the synced position.
            guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a") else {
                return
            }
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.numberOfLoops = -1
                newPlayer.prepareToPlay()
                newPlayer.currentTime = expectedPosition
                newPlayer.volume = 0
                player?.stop()
                newPlayer.play()
                player = newPlayer
                currentTrack = track
                fadeIn(newPlayer)
            } catch {
                print("Audio sync playback error: \(error)")
            }
        }
    }

    // MARK: - Fade helpers

    /// Update the currently-playing track's volume to the stored music volume.
    /// Call from SettingsView.onChange so changes take effect immediately.
    func applyMusicVolume() {
        player?.volume = AppSettings.musicVolume
    }

    private func fadeIn(_ player: AVAudioPlayer, duration: TimeInterval = 0.8) {
        let target = AppSettings.musicVolume
        let steps = 20
        let stepDuration = duration / Double(steps)
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = target * Float(currentStep) / Float(steps)
            if currentStep >= steps { timer.invalidate() }
        }
    }

    private func fadeOut(_ player: AVAudioPlayer, duration: TimeInterval = 0.5, completion: @escaping () -> Void) {
        let steps = 15
        let stepDuration = duration / Double(steps)
        var currentStep = 0
        let startVolume = player.volume
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = startVolume * (1 - Float(currentStep) / Float(steps))
            if currentStep >= steps {
                timer.invalidate()
                player.stop()
                completion()
            }
        }
    }
}
