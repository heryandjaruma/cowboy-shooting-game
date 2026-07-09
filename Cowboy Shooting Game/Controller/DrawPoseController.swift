//
//  DrawPoseController.swift
//  Cowboy Shooting Game
//
//  Turns the phone into the pistol: hand at hip → signal → raise → fire.
//
//  During the countdown the player must hold the phone "holstered" — one end
//  of the long axis tipped toward the ground, like a pistol resting at the
//  hip. When the firing window opens they raise it level ("drawn") before the
//  volume trigger counts. A player who leaves the holster before the signal
//  has false-started and must re-holster before their shot registers.
//
//  Detection uses only the gravity vector from Core Motion, so it needs no
//  calibration and no permission prompt, and it works facing any direction.
//  The barrel is the device's long (Y) axis; gravity.y is ±1 with an end
//  pointing straight down and 0 when the phone is level, regardless of how
//  the grip is rolled. Both signs count as holstered so the mechanic is
//  handedness-agnostic in the landscape grip. The cones are deliberately
//  generous with a dead band between them — this is a feel mechanic, not a
//  precision aim check.
//
//  Everything is judged locally on each device, mirroring how reaction times
//  are measured: the network never sees poses, so no player gains a latency
//  edge and the host-referee protocol is unchanged.
//

import Foundation
import CoreMotion
import Combine

@MainActor
final class DrawPoseController: ObservableObject {

    enum Pose: Equatable {
        case holstered   // long axis tipped well below level — gun at the hip
        case drawn       // long axis roughly level — gun raised at the opponent
        case between     // mid-swing / anything else
    }

    @Published private(set) var pose: Pose = .between

    /// True once the player may shoot this round: holstered when the window
    /// opened, or re-holstered afterward following a false start.
    @Published private(set) var isArmed = false

    /// False when this device can't sense motion (e.g. the simulator); the
    /// gate then lets every shot through so the game stays playable.
    private(set) var isAvailable = false

    /// |gravity.y| at or above this is holstered: an end dipped ≥ ~44° below level.
    private let holsterThreshold = 0.7
    /// |gravity.y| at or below this is drawn: within ~35° of level. Kept
    /// generous so a casual raise counts even if the wrist tips a bit high or
    /// low. The gap up to `holsterThreshold` is a dead band so poses can't flicker.
    private let drawnThreshold = 0.57

    private var roundActive = false
    private let motionManager = CMMotionManager()

    // MARK: - Sensing

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }
        isAvailable = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravityY = motion?.gravity.y else { return }
            Task { @MainActor [weak self] in self?.classify(gravityY: gravityY) }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        roundActive = false
        isArmed = false
        pose = .between
    }

    // MARK: - Round lifecycle

    /// Call the instant the firing window opens. Being out of the holster at
    /// that moment is a false start: the player must re-holster to arm.
    func beginRound() {
        roundActive = true
        isArmed = !isAvailable || pose == .holstered
    }

    func endRound() {
        roundActive = false
        isArmed = false
    }

    /// Whether the trigger should fire right now: armed and holding the draw.
    var canFire: Bool {
        guard isAvailable else { return true }
        return isArmed && pose == .drawn
    }

    // MARK: - Pose classification

    private func classify(gravityY: Double) {
        let newPose: Pose
        if abs(gravityY) >= holsterThreshold {
            newPose = .holstered
        } else if abs(gravityY) <= drawnThreshold {
            newPose = .drawn
        } else {
            newPose = .between
        }
        if newPose != pose { pose = newPose }

        // A false-starter re-arms the moment they return to the holster.
        if roundActive, !isArmed, newPose == .holstered {
            isArmed = true
        }
    }
}
