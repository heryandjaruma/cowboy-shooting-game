//
//  DrawPoseTestScene.swift
//  Cowboy Shooting Game
//
//  Single-device practice range for the Holster → Draw pose gate.
//
//  Runs the duel loop with no connection and no opponent: tap to start the
//  same 3-2-1 countdown (identical tick + randomized final hold), holster,
//  wait for FIRE, draw, and shoot with the volume trigger through the exact
//  pose gate the real duel uses. The "verdict" is your own draw time plus a
//  dry-fire count, and a live tilt readout helps tune the pose thresholds.
//
//  Reached from the 🎯 button on the main menu (DEBUG builds only). The
//  shooting/feedback code is deliberately copied from GameScene so this scene
//  needs nothing from the multiplayer stack.
//

import SwiftUI
import SpriteKit
import AVFoundation
import CoreHaptics
import CoreMotion
import Combine
import UIKit

class DrawPoseTestScene: SKScene {

    // MARK: - Properties

    var onExit: (() -> Void)?

    let drawPoseController = DrawPoseController()
    private let triggerController = TriggerController.shared

    private enum Phase: Equatable {
        case idle            // tap to start a draw
        case counting(Int)   // 3, 2, 1
        case fire            // window open — draw!
        case done            // shot landed; tap to go again
    }

    private var phase: Phase = .idle {
        didSet { handlePhaseChange(phase) }
    }

    /// Same rhythm as the real duel (see CountdownController).
    private let tickSeconds: Double = 1.3
    private let finalHoldRange: ClosedRange<Double> = 2...5

    private var countdownTask: Task<Void, Never>?
    private var windowOpenNanos: UInt64?
    private var lastReaction: Double?
    private var dryFireCount = 0
    private var cancellables = Set<AnyCancellable>()

    private var dimmingNode: SKSpriteNode!
    private var holsterHintLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var tiltReadoutLabel: SKLabelNode!
    private var exitLabel: SKLabelNode!
    private var countdownNode: SKSpriteNode!  // num3 / num2 / num1 images
    private var fireNode: SKSpriteNode!        // "fire" draw-prompt image
    private var bangNode: SKSpriteNode!        // shot-effect image

    private var hapticEngine: CHHapticEngine?
    private var audioPlayer: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    private var jammedPlayer: AVAudioPlayer?
    private var isFiringFlashlight = false

    /// Test-only tilt feed for the readout label, so the production
    /// DrawPoseController stays untouched.
    private let tiltMotion = CMMotionManager()

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        setupBackground()
        setupGun()
        setupDimmingLayer()
        setupCountdownLabel()
        setupSubtitleLabel()
        setupCountdownNode()
        setupFireNode()
        setupBangNode()
        setupHolsterHintLabel()
        setupTiltReadoutLabel()
        setupExitButton()

        prepareHaptics()
        setupAudioSession()

        observeDrawPose()

        drawPoseController.start()
        startTiltReadout()
        triggerController.reactivate()

        triggerController.onTrigger = { [weak self] _ in
            self?.attemptFire()
        }

        handlePhaseChange(.idle)
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)

        triggerController.onTrigger = nil
        triggerController.disable()
        countdownTask?.cancel()
        drawPoseController.stop()
        tiltMotion.stopDeviceMotionUpdates()
    }

    // MARK: - Pose observation (same pattern as GameScene)

    private func observeDrawPose() {
        // @Published emits on willSet, so hop through the main queue once to
        // read the controller's fully-updated state in the handler.
        drawPoseController.$pose
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshHolsterHint() }
            .store(in: &cancellables)

        drawPoseController.$isArmed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshHolsterHint() }
            .store(in: &cancellables)
    }

    // MARK: - Round flow (solo stand-in for CountdownController)

    private func startRound() {
        countdownTask?.cancel()
        windowOpenNanos = nil
        lastReaction = nil
        dryFireCount = 0
        drawPoseController.endRound()

        countdownTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.phase = .counting(3)
                try await Task.sleep(for: .seconds(self.tickSeconds))
                self.phase = .counting(2)
                try await Task.sleep(for: .seconds(self.tickSeconds))
                self.phase = .counting(1)
                try await Task.sleep(for: .seconds(Double.random(in: self.finalHoldRange)))
                self.windowOpenNanos = DispatchTime.now().uptimeNanoseconds
                self.phase = .fire
            } catch {
                // Cancelled by restart/exit — leave the phase as-is.
            }
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if nodes(at: touch.location(in: self)).contains(where: { $0.name == "exitButton" }) {
            onExit?()
            return
        }
        switch phase {
        case .idle, .done:
            startRound()
        case .counting, .fire:
            break // fire only via the volume trigger, like the real duel
        }
    }

    // MARK: - Shooting (volume trigger through the same pose gate)

    private func attemptFire() {
        guard case .fire = phase, let open = windowOpenNanos else { return }
        guard drawPoseController.canFire else {
            dryFire()
            return
        }
        lastReaction = Double(DispatchTime.now().uptimeNanoseconds &- open) / 1_000_000_000
        bang()
        phase = .done
    }

    /// Trigger pulled while not in a valid draw pose — the hammer just clicks.
    private func dryFire() {
        dryFireCount += 1
        playGunJammedAudio()
        playDryFireHaptic()
        let shake = SKAction.sequence([
            .moveBy(x: 12, y: 0, duration: 0.04),
            .moveBy(x: -24, y: 0, duration: 0.06),
            .moveBy(x: 12, y: 0, duration: 0.04),
            .move(to: CGPoint(x: 0, y: 0), duration: 0.02)
        ])
        fireNode.run(shake, withKey: "dryFireShake")
    }

    // MARK: - Phase visuals

    private func handlePhaseChange(_ phase: Phase) {
        switch phase {
        case .idle:
            drawPoseController.endRound()
            dimmingNode.run(SKAction.fadeAlpha(to: 0.7, duration: 0.2))
            countdownLabel.removeAllActions()
            countdownLabel.text = "TAP TO TEST YOUR DRAW"
            countdownLabel.fontSize = 44
            countdownLabel.fontColor = .white
            countdownLabel.alpha = 1.0
            subtitleLabel.text = "Holster, wait for the signal, raise, volume-fire"
            subtitleLabel.alpha = 1.0
            countdownNode.removeAllActions(); countdownNode.alpha = 0.0
            fireNode.removeAllActions();     fireNode.alpha = 0.0

        case .counting(let n):
            dimmingNode.alpha = 0.7
            fireNode.removeAllActions(); fireNode.alpha = 0.0
            subtitleLabel.alpha = 0.0
            countdownLabel.removeAllActions(); countdownLabel.alpha = 0.0

            let numTex = SKTexture(imageNamed: "num\(n)")
            numTex.filteringMode = .nearest
            countdownNode.texture = numTex

            let targetHeight: CGFloat = 220
            let aspect = numTex.size().width / numTex.size().height
            countdownNode.size = CGSize(width: targetHeight * aspect, height: targetHeight)

            countdownNode.removeAllActions()
            countdownNode.setScale(0.2)
            countdownNode.alpha = 1.0
            countdownNode.run(SKAction.sequence([
                SKAction.scale(to: 0.69, duration: 0.12),
                SKAction.scale(to: 0.42, duration: 0.08)
            ]))
            playCountdownTickAudio()
            playCountdownTickHaptic()

        case .fire:
            // Judged at the exact window-open instant, same rule as the duel.
            drawPoseController.beginRound()
            playDrawSignalHaptic()

            countdownLabel.removeAllActions(); countdownLabel.run(SKAction.fadeOut(withDuration: 0.15))
            countdownNode.removeAllActions();  countdownNode.run(SKAction.fadeOut(withDuration: 0.15))
            dimmingNode.run(SKAction.fadeOut(withDuration: 0.25))
            fireNode.removeAllActions()
            fireNode.setScale(0.2)
            fireNode.alpha = 1.0
            let grow = SKAction.scale(to: 1.05, duration: 0.18)
            let pulse = SKAction.sequence([
                SKAction.scale(to: 0.42, duration: 0.35),
                SKAction.scale(to: 0.69, duration: 0.35)
            ])
            fireNode.run(SKAction.sequence([grow, SKAction.repeatForever(pulse)]))

        case .done:
            drawPoseController.endRound()
            dimmingNode.run(SKAction.fadeAlpha(to: 0.7, duration: 0.3))
            countdownNode.removeAllActions(); countdownNode.alpha = 0.0
            fireNode.removeAllActions(); fireNode.run(SKAction.fadeOut(withDuration: 0.15))

            countdownLabel.removeAllActions()
            countdownLabel.text = String(format: "DRAW TIME  %.3f s", lastReaction ?? 0)
            countdownLabel.fontSize = 52
            countdownLabel.fontColor = .white
            countdownLabel.alpha = 1.0

            subtitleLabel.text = dryFireCount == 0
                ? "Clean draw — tap to go again"
                : "\(dryFireCount) dry fire\(dryFireCount == 1 ? "" : "s") — tap to go again"
            subtitleLabel.alpha = 1.0
            subtitleLabel.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.6),
                .fadeAlpha(to: 1.0, duration: 0.6)
            ])))
        }
        refreshHolsterHint()
    }

    // MARK: - Holster hint (pose-gate coaching, mirrors GameScene)

    private func refreshHolsterHint() {
        guard drawPoseController.isAvailable else {
            hideHolsterHint()
            return
        }
        switch phase {
        case .idle, .counting:
            if drawPoseController.pose == .holstered {
                showHolsterHint("HOLSTERED... STEADY",
                                color: SKColor(red: 0.45, green: 0.85, blue: 0.45, alpha: 1.0),
                                pulse: false)
            } else {
                showHolsterHint("HOLSTER! TIP YOUR GUN DOWN",
                                color: .orange, pulse: true)
            }
        case .fire:
            if drawPoseController.isArmed {
                hideHolsterHint()
            } else {
                showHolsterHint("TOO SOON! RE-HOLSTER!",
                                color: .red, pulse: true)
            }
        case .done:
            hideHolsterHint()
        }
    }

    private func showHolsterHint(_ text: String, color: SKColor, pulse: Bool) {
        guard holsterHintLabel.text != text || holsterHintLabel.alpha == 0 else { return }
        holsterHintLabel.removeAllActions()
        holsterHintLabel.text = text
        holsterHintLabel.fontColor = color
        holsterHintLabel.alpha = 1.0
        if pulse {
            holsterHintLabel.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.45),
                .fadeAlpha(to: 1.0, duration: 0.45)
            ])))
        }
    }

    private func hideHolsterHint() {
        holsterHintLabel.removeAllActions()
        holsterHintLabel.alpha = 0.0
    }

    // MARK: - Tilt readout (test-only diagnostics)

    private func startTiltReadout() {
        guard drawPoseController.isAvailable, tiltMotion.isDeviceMotionAvailable else {
            tiltReadoutLabel.text = "no motion on this device — pose gate open"
            return
        }
        tiltMotion.deviceMotionUpdateInterval = 0.1
        tiltMotion.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravityY = motion?.gravity.y else { return }
            Task { @MainActor [weak self] in self?.updateTiltReadout(gravityY: gravityY) }
        }
    }

    private func updateTiltReadout(gravityY: Double) {
        let tilt = asin(min(1.0, abs(gravityY))) * 180 / .pi
        let pose: String
        switch drawPoseController.pose {
        case .holstered: pose = "HOLSTERED"
        case .drawn:     pose = "DRAWN"
        case .between:   pose = "BETWEEN"
        }
        let armed = drawPoseController.isArmed ? " · armed" : ""
        tiltReadoutLabel.text = String(format: "tilt %.0f° · %@%@", tilt, pose, armed)
    }

    // MARK: - Scene Setup (copied from GameScene where shared)

    private func setupBackground() {
        let background = SKSpriteNode(imageNamed: "desert_bg")
        background.size = self.size
        background.zPosition = -10
        background.texture?.filteringMode = .nearest
        addChild(background)
    }

    private func setupGun() {
        let gun = SKSpriteNode(imageNamed: "Peacemaker_gun")
        gun.setScale(0.25)
        gun.position = CGPoint(x: 0, y: -40)
        gun.zPosition = 1
        gun.texture?.filteringMode = .nearest
        addChild(gun)
    }

    private func setupDimmingLayer() {
        dimmingNode = SKSpriteNode(color: .black, size: self.size)
        dimmingNode.alpha = 0.7
        dimmingNode.zPosition = 10
        addChild(dimmingNode)
    }

    private func setupCountdownLabel() {
        countdownLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        countdownLabel.fontSize = 44
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.alpha = 0.0
        countdownLabel.zPosition = 11
        addChild(countdownLabel)
    }

    private func setupSubtitleLabel() {
        subtitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        subtitleLabel.fontSize = 22
        subtitleLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: 0, y: -60)
        subtitleLabel.alpha = 0.0
        subtitleLabel.zPosition = 11
        addChild(subtitleLabel)
    }

    private func setupCountdownNode() {
        countdownNode = SKSpriteNode()
        countdownNode.position = CGPoint(x: 0, y: 0)
        countdownNode.zPosition = 11
        countdownNode.alpha = 0.0
        addChild(countdownNode)
    }

    private func setupFireNode() {
        fireNode = SKSpriteNode(imageNamed: "fire")
        fireNode.texture?.filteringMode = .nearest
        fireNode.position = CGPoint(x: 0, y: 0)
        fireNode.zPosition = 11
        fireNode.alpha = 0.0
        addChild(fireNode)
    }

    private func setupBangNode() {
        bangNode = SKSpriteNode(imageNamed: "Bang")
        bangNode.texture?.filteringMode = .nearest
        bangNode.setScale(0.2)
        bangNode.position = CGPoint(x: 0, y: -20)
        bangNode.zPosition = 12
        bangNode.alpha = 0.0
        addChild(bangNode)
    }

    private func setupHolsterHintLabel() {
        holsterHintLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        holsterHintLabel.fontSize = 26
        holsterHintLabel.verticalAlignmentMode = .center
        holsterHintLabel.horizontalAlignmentMode = .center
        holsterHintLabel.position = CGPoint(x: 0, y: -self.size.height / 2 + 60)
        holsterHintLabel.zPosition = 11
        holsterHintLabel.alpha = 0.0
        addChild(holsterHintLabel)
    }

    private func setupTiltReadoutLabel() {
        tiltReadoutLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        tiltReadoutLabel.fontSize = 15
        tiltReadoutLabel.fontColor = SKColor(white: 0.85, alpha: 0.9)
        tiltReadoutLabel.verticalAlignmentMode = .bottom
        tiltReadoutLabel.horizontalAlignmentMode = .left
        tiltReadoutLabel.position = CGPoint(x: -self.size.width / 2 + 16, y: -self.size.height / 2 + 14)
        tiltReadoutLabel.zPosition = 15
        addChild(tiltReadoutLabel)
    }

    private func setupExitButton() {
        // Oversized invisible hit area behind the label for an easy tap target.
        let hitArea = SKSpriteNode(color: .clear, size: CGSize(width: 140, height: 70))
        hitArea.name = "exitButton"
        hitArea.position = CGPoint(x: -self.size.width / 2 + 80, y: self.size.height / 2 - 40)
        hitArea.zPosition = 20
        addChild(hitArea)

        exitLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        exitLabel.name = "exitButton"
        exitLabel.text = "< EXIT"
        exitLabel.fontSize = 24
        exitLabel.fontColor = .white
        exitLabel.verticalAlignmentMode = .center
        exitLabel.horizontalAlignmentMode = .center
        exitLabel.position = hitArea.position
        exitLabel.zPosition = 21
        addChild(exitLabel)
    }

    // MARK: - Hardware feedback (copied from GameScene)

    private func bang() {
        playGunshotAudio()
        playGunshotHaptic()
        fireMuzzleFlash()
        fireNode.removeAllActions()
        fireNode.run(SKAction.fadeOut(withDuration: 0.1))
        bangNode.removeAllActions()
        bangNode.alpha = 1.0
        bangNode.run(SKAction.sequence([
            SKAction.scale(to: 0.35, duration: 0.08),
            SKAction.wait(forDuration: 0.3),
            SKAction.group([
                SKAction.scale(to: 0.2, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25)
            ])
        ]))
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error.localizedDescription)")
        }
    }

    private func fireMuzzleFlash() {
        isFiringFlashlight = true
        Task {
            setTorch(on: true)
            try? await Task.sleep(nanoseconds: 50_000_000)
            setTorch(on: false)
            await MainActor.run { self.isFiringFlashlight = false }
        }
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                }
            } else {
                if device.isTorchActive || device.torchMode != .off {
                    device.torchMode = .off
                }
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }

    private var masterVolume: Float {
        Float(UserDefaults.standard.object(forKey: AppSettings.masterVolumeKey) as? Double ?? 1.0)
    }
    private var sfxVolume: Float {
        Float(UserDefaults.standard.object(forKey: AppSettings.sfxVolumeKey) as? Double ?? 1.0)
    }

    private func playGunshotAudio() {
        guard let soundAsset = NSDataAsset(name: "rayne-mixedgun") else {
            print("Could not find the audio asset in the catalog.")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(data: soundAsset.data)
            audioPlayer?.volume = masterVolume * Float(UserDefaults.standard.object(forKey: AppSettings.gunshotVolumeKey) as? Double ?? 1.0)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }

    private func playCountdownTickAudio() {
        guard let url = Bundle.main.url(forResource: "CountdownTick", withExtension: "m4a") else { return }
        do {
            tickPlayer = try AVAudioPlayer(contentsOf: url)
            tickPlayer?.volume = masterVolume * sfxVolume
            tickPlayer?.prepareToPlay()
            tickPlayer?.play()
        } catch {
            print("Failed to play countdown tick: \(error.localizedDescription)")
        }
    }

    private func playGunJammedAudio() {
        guard let url = Bundle.main.url(forResource: "GunJammed", withExtension: "m4a") else { return }
        do {
            jammedPlayer = try AVAudioPlayer(contentsOf: url)
            jammedPlayer?.volume = masterVolume * sfxVolume
            jammedPlayer?.prepareToPlay()
            jammedPlayer?.play()
        } catch {
            print("Failed to play gun jammed: \(error.localizedDescription)")
        }
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }

    private func playGunshotHaptic() {
        playTransientHaptic(intensity: 1.0, sharpness: 1.0)
    }

    /// Short firm tick on each countdown number (3, 2, 1).
    private func playCountdownTickHaptic() {
        playTransientHaptic(intensity: 0.7, sharpness: 0.6)
    }

    /// Sharp little click for a trigger pull outside a valid draw pose.
    private func playDryFireHaptic() {
        playTransientHaptic(intensity: 0.5, sharpness: 0.9)
    }

    /// Buzz when the firing window opens, so the signal is felt even while the
    /// phone is holstered at the hip rather than being watched.
    private func playDrawSignalHaptic() {
        playTransientHaptic(intensity: 1.0, sharpness: 0.4)
    }

    private func playTransientHaptic(intensity: Float, sharpness: Float) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftUI wrapper

/// Full-screen host for the practice range, presented from the main menu.
struct DrawPoseTestView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: makeScene(size: geometry.size))
                .ignoresSafeArea()
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = DrawPoseTestScene(size: size)
        scene.scaleMode = .resizeFill
        scene.onExit = { dismiss() }
        return scene
    }
}

#Preview {
    DrawPoseTestView()
}
