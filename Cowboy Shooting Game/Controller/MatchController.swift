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
        case matchOver(won: Bool)
    }
    
    @Published private(set) var myLives = 3
    @Published private(set) var opponentLives = 3
    @Published private(set) var matchPhase: MatchPhase = .playing
    
    private weak var connection: GameConnectionManager?
    private weak var countdown: CountdownController?
    private var cancellables = Set<AnyCancellable>()
    
    // for host to track both lives
    private var hostLives = 3
    private var joinerLives = 3
    
    private enum Opcode {
        static let matchOver: UInt8 = 0         // host send to joiner: 1 byte joinerWon (0/1)
        static let continueRound: UInt8 = 1     // host send to joiner: 1 byte hostLives, 1 byte joinerLives
    }
    
    func configure(connection: GameConnectionManager, countdown: CountdownController, shot: ShotController) {
        self.connection = connection
        self.countdown = countdown
        
        connection.onEvent(channel: GameChannel.life.rawValue) { [weak self] body in
            self?.handleIncoming(body)
        }
        
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
        
        if hostLives == 0 || joinerLives == 0 {
            let joinerWon = hostLives == 0
            connection.sendEvent(channel: GameChannel.life.rawValue,
                                 body: Data([Opcode.matchOver, joinerWon ? 1 : 0]))
            scheduleFinish { self.matchPhase = .matchOver(won: !joinerWon) }
        } else {
            connection.sendEvent(channel: GameChannel.life.rawValue,
                                 body: Data([Opcode.continueRound, UInt8(hostLives), UInt8(joinerLives)]))
            scheduleNextRound()
        }
        
    }
    
    private func handleIncoming(_ body: Data) {
        guard let opcode = body.first else { return }
        switch opcode {
        case Opcode.matchOver:
            guard body.count > 1 else { return }
            let joinerWon = body[1] == 1
            scheduleFinish {
                self.matchPhase = .matchOver(won: joinerWon)
            }
        case Opcode.continueRound:
            guard body.count > 2 else { return }
            // Joiner's own perspective: host is "opponent", joiner is "self"
            opponentLives = Int(body[1])    // host's lives
            myLives = Int(body[2])          // joiner's own lives
            scheduleNextRound()
        default:
            break
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: apply)
    }
}
