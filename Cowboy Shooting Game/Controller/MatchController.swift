//
//  MatchController.swift
//  Cowboy Shooting Game
//
//  Created by Heryan Djaruma on 07/07/26.
//

import Foundation
import Combine
import Dispatch

@MainActor
final class MatchController: ObservableObject {
    enum MatchPhase: Equatable {
        case playing
        case roundOver(ShotController.Outcome)
        case awaitingContinue // waiting for tap to continue
        case matchOver(won: Bool)
    }
    
    private let resultLingerSeconds: Double = 1.6   // let win/lose land and the ~1.5s Bullseye/Outdrawn call finish before the prompt
    
    @Published private(set) var myLives = 3
    @Published private(set) var opponentLives = 3
    @Published private(set) var matchPhase: MatchPhase = .playing
    @Published var isPaused = false // Tracks if the pause menu is open
    
    private weak var connection: GameConnectionManager?
    private weak var countdown: CountdownController?
    private var cancellables = Set<AnyCancellable>()
    
    // for host to track both lives
    private var hostLives = 3
    private var joinerLives = 3
    
    private enum Opcode {
            static let matchOver: UInt8 = 0         // host send to joiner: 1 byte joinerWon (0/1), 1 byte hostLives, 1 byte joinerLives
            static let continueRound: UInt8 = 1     // host send to joiner: 1 byte hostLives, 1 byte joinerLives
            static let peerSurrendered: UInt8 = 2   // <-- ADD THIS: Peer tells the other peer they gave up
        }
    
    func configure(connection: GameConnectionManager, countdown: CountdownController, shot: ShotController) {
        self.connection = connection
        self.countdown = countdown
        
        connection.onEvent(channel: GameChannel.life.rawValue) { [weak self] body in
            self?.handleIncoming(body)
        }

        // Fresh match (or rematch) — let spectators see the full 3-3 tally.
        connection.updateSpectatorLives(hostLives: hostLives, joinerLives: joinerLives)
        
        shot.$outcome
            .compactMap { $0 }
            .sink { [weak self] outcome in self?.handleOutcome(outcome) }
            .store(in: &cancellables)
    }
    
    private func handleOutcome(_ outcome: ShotController.Outcome) {
        guard let connection else { return }
        matchPhase = .roundOver(outcome)
        
        guard connection.isHost else { return }
        
        if outcome == .loser {
            hostLives = max(0, hostLives - 1)
        }
        else {
            joinerLives = max(0, joinerLives - 1)
        }
        myLives = hostLives
        opponentLives = joinerLives
        connection.updateSpectatorLives(hostLives: hostLives, joinerLives: joinerLives)

        if hostLives == 0 || joinerLives == 0 {
            let joinerWon = hostLives == 0
            connection.sendEvent(channel: GameChannel.life.rawValue,
                                 body: Data([Opcode.matchOver, joinerWon ? 1 : 0,
                                             UInt8(hostLives), UInt8(joinerLives)]))
            scheduleFinish { self.finishMatch(won: !joinerWon) }
        } else {
            connection.sendEvent(channel: GameChannel.life.rawValue,
                                 body: Data([Opcode.continueRound, UInt8(hostLives), UInt8(joinerLives)]))
//            scheduleNextRound()
            scheduleContinuePrompt()
        }
        
    }
    
    private func handleIncoming(_ body: Data) {
            guard let opcode = body.first else { return }
            switch opcode {
        case Opcode.matchOver:
            guard body.count > 3 else { return }
            let joinerWon = body[1] == 1
            // Final lives ride along so the joiner's hearts and end-of-match
            // summary reflect the fatal round, not the previous one.
            opponentLives = Int(body[2])    // host's lives
            myLives = Int(body[3])          // joiner's own lives
            scheduleFinish {
                self.finishMatch(won: joinerWon)
            }
        case Opcode.continueRound:
            guard body.count > 2 else { return }
            // Joiner's own perspective: host is "opponent", joiner is "self"
            opponentLives = Int(body[1])    // host's lives
            myLives = Int(body[2])          // joiner's own lives
//            scheduleNextRound()
            scheduleContinuePrompt() // wait for continue tap
                
            case Opcode.peerSurrendered: // <-- ADD THIS ENTIRE CASE
                        // The opponent surrendered, so we instantly win
                        opponentLives = 0
                        if connection?.isHost == true {
                            joinerLives = 0
                        } else {
                            hostLives = 0
                        }
                        
                        isPaused = false
                        finishMatch(won: true)
                            countdown?.resetForNextRound()
                        
                    default:
                        break
                    }
                }
    
    func continueToNextRound() {
        guard matchPhase == .awaitingContinue else { return }
        matchPhase = .playing
        countdown?.resetForNextRound()   // clears outcome, re-arms shooter, phase → .notReady
        // GameScene presses ready once its "Ready for showdown" call finishes,
        // so the announcer always precedes the countdown; it starts once BOTH tap.
    }
    
    // schedule a tap to continue
    private func scheduleContinuePrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + resultLingerSeconds) { [weak self] in
            guard let self, case .roundOver = self.matchPhase else { return }
            self.matchPhase = .awaitingContinue
        }
    }
    
    private func scheduleNextRound() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self ] in
            self?.matchPhase = .playing
            self?.countdown?.resetForNextRound()
            self?.countdown?.pressReady()
        }
    }
    
    private func scheduleFinish(_ apply: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .seconds(2))
            apply()
        }
    }

    /// Pass wins here
    private func finishMatch(won: Bool) {
        matchPhase = .matchOver(won: won)
        if won {
            GameCenterManager.shared.reportWin()
        }
        // A real duel just ended (win or lose) — arm the review prompt so the
        // main menu can offer it once the player returns to the lobby.
        ReviewManager.shared.matchDidComplete()
    }
    
    /// Forces a loss for the local player, notifies the network peer, and ends the match.
    func surrenderMatch() {
            guard let connection else { return }
            
            // 1. Tell the opponent we gave up
            connection.sendEvent(channel: GameChannel.life.rawValue,
                                 body: Data([Opcode.peerSurrendered]))
            
            // 2. Zero out our own lives locally
            if connection.isHost {
                hostLives = 0
            } else {
                joinerLives = 0
            }
            myLives = 0
            
            // 3. Close the menu, trigger a loss, and THEN kill the timer
            isPaused = false
            finishMatch(won: false)         // <--- MOVED UP
            countdown?.resetForNextRound()  // <--- MOVED DOWN
        }
}
