//
//  SFXManager.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 24/07/26.
//

import AVFoundation

final class SFXManager {
    static let shared = SFXManager()

    enum Sound: String {
        case buttonTap = "ClickSound"
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        preload(.buttonTap)
    }

    private func preload(_ sound: Sound) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else { return }
        players[sound] = try? AVAudioPlayer(contentsOf: url)
        players[sound]?.prepareToPlay()
    }

    func play(_ sound: Sound) {
        players[sound]?.currentTime = 0
        players[sound]?.play()
    }
}
