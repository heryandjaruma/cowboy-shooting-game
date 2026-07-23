//
//  ReviewManager.swift
//  Cowboy Shooting Game
//
//  Decides *when* the native App Store review prompt should be offered. A
//  completed 1v1 match — win or lose — arms a pending request; the main menu
//  fulfils it the next time the player lands back at the root, which is a
//  natural pause rather than an interruption mid-duel.
//
//  Practice mode never runs a MatchController, so it can't arm a request: only
//  a real match against another player counts. StoreKit still applies its own
//  system frequency cap (~3 prompts per year) on top of this.
//

import Foundation

@MainActor
final class ReviewManager {
    static let shared = ReviewManager()
    private init() {}

    private var hasPendingRequest = false

    /// Arm a review request. Called when a real match concludes, for both the
    /// winner and the loser.
    func matchDidComplete() {
        hasPendingRequest = true
    }

    /// Consume a previously armed request, returning `true` at most once per
    /// completed match. The caller then presents the system review prompt.
    func consumePendingRequest() -> Bool {
        guard hasPendingRequest else { return false }
        hasPendingRequest = false
        return true
    }
}
