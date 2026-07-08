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
}

// Singleton
final class MusicManager: ObservableObject {
    static let shared = MusicManager()
    
    private var player: AVAudioPlayer?
    private var currentTrack: MusicTrack?
    
    @Published var isMuted: Bool = false
    
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
    
    func play(_ track: MusicTrack, loop: Bool = true, crossfade: Bool = true) {
        guard currentTrack != track else { return }
        
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a") else {
            print("Missing audio file: \(track.rawValue)")
            return
        }
        
        if crossfade, let oldPlayer = player {
            fadeOut(oldPlayer) { [weak self] in
                self?.startNewPlayer(url: url, track: track, loop: loop)
            }
        } else {
            player?.stop()
            self.player = nil
            self.currentTrack = nil
            startNewPlayer(url: url, track: track, loop: loop)
        }
    }
    
    func stop(fade: Bool = true) {
        guard let player else { return }
        
        if fade {
            fadeOut(player) { [weak self] in
                self?.player = nil
                self?.currentTrack = nil
            }
        } else {
            player.stop()
            self.player = nil
            self.currentTrack = nil
        }
    }
    
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
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    private func fadeIn(_ player: AVAudioPlayer, duration: TimeInterval = 0.8) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = Float(currentStep) / Float(steps)
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
