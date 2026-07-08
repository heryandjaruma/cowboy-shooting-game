import SwiftUI
import SpriteKit
import GameplayKit
import AVFoundation
import CoreHaptics
import UIKit // Required for NSDataAsset
import Combine

class GameScene: SKScene {
    
    // MARK: - Properties
    
    var connection: GameConnectionManager?
    var onRequestReturnToMenu: (() -> Void)?
    var shotController: ShotController = ShotController()
    var countdownController: CountdownController = CountdownController()
    var matchController: MatchController = MatchController()
    var drawPoseController: DrawPoseController = DrawPoseController()
    
    private var hearts: [SKSpriteNode] = []
    
    private var dimmingNode: SKSpriteNode!
    private var holsterHintLabel: SKLabelNode!  // pose-gate coaching text
    private var countdownLabel: SKLabelNode!
    private var countdownNode: SKSpriteNode!  // num3 / num2 / num1 images
    private var fireNode: SKSpriteNode!        // "fire" draw-prompt image
    private var resultNode: SKSpriteNode!      // "win" / "lose" result image
    private var bangNode: SKSpriteNode!        // shot-effect image
    
    private var localSceneReady = false
    private var remoteSceneReady = false
    private var didAnnounceDuel = false
    
    private var cancellables = Set<AnyCancellable>()
    private let triggerController = TriggerController.shared //shot with Volume

    private enum SceneOp {
        static let ready: UInt8 = 0     // "I reached the GameScene"
        static let readyAck: UInt8 = 1  // "…and I heard that you did too"
    }
    
    // Hardware integration properties
    private var hapticEngine: CHHapticEngine?
    private var audioPlayer: AVAudioPlayer?
    private var isFiringFlashlight = false
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        if let connection {
            shotController.configure(connection: connection)
            countdownController.configure(connection: connection, shot: shotController)
            matchController.configure(connection: connection, countdown: countdownController, shot: shotController)
        }
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupBackground()
        setupGun()
        setupPlayerUI()
        setupHealthUI()
        setupDimmingLayer()
        setupCountdownLabel()
        setupCountdownNode()
        setupFireNode()
        setupResultNode()
        setupBangNode()
        setupHolsterHintLabel()

        prepareHaptics()
        setupAudioSession()

        observeControllers()
        setupNetworking()

        drawPoseController.start()
        triggerController.reactivate()

        triggerController.onTrigger = { [weak self] _ in
            self?.attemptFire()
        }
    }
    
    // MARK: - Unregister the Control when leaving scene
    override func willMove(from view: SKView) {
        super.willMove(from: view)

        triggerController.onTrigger = nil
        drawPoseController.stop()
    }
    
    // MARK: - Controller Observation
    // GameKit cannot directly use the @Publishable,
    // so instead it needs to subscribe to the changes.
    private func observeControllers() {
        countdownController.$phase
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)
        
        shotController.$didFire
            .sink { [weak self] didFire in
                guard didFire else { return }
                self?.bang()
            }
            .store(in: &cancellables)
        
        shotController.$outcome
            .sink { [weak self] outcome in
                guard let outcome else { return }
                self?.handleOutcome(outcome)
            }
            .store(in: &cancellables)
        
        matchController.$myLives
            .sink{ [weak self] lives in self?.updateHearts(lives)}
            .store(in: &cancellables)
        
        matchController.$matchPhase // observe phase for awaiting tap
            .sink { [weak self] phase in
                switch phase {
                case .matchOver(let won): self?.showMatchOver(won: won)
                case .awaitingContinue:   self?.showContinuePrompt()
                default: break
                }
            }
            .store(in: &cancellables)

        // Pose gate. @Published emits on willSet, so hop through the main queue
        // once to read the controller's fully-updated state in the handler.
        drawPoseController.$pose
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshHolsterHint(phase: self.countdownController.phase)
            }
            .store(in: &cancellables)

        drawPoseController.$isArmed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshHolsterHint(phase: self.countdownController.phase)
            }
            .store(in: &cancellables)
    }
    
    private func handlePhaseChange(_ phase: CountdownController.Phase) {
        switch phase {
        case .notReady, .waiting:
            drawPoseController.endRound()
        case .counting:
            break
        case .fire:
            // Judged at the exact window-open instant: out of the holster now
            // is a false start and the player must re-holster to arm.
            drawPoseController.beginRound()
            playDrawSignalHaptic() // felt even with the phone held at the hip
        }
        refreshHolsterHint(phase: phase)

        switch phase {
        case .notReady:
            dimmingNode.run(SKAction.fadeAlpha(to: 0.7, duration: 0.2))
            countdownLabel.removeAllActions()
            countdownLabel.position = CGPoint(x: 0, y: 0) // rese position after moved by tap to continue
            countdownLabel.text = "Preparing the battle ground..."
            countdownLabel.fontSize = 30
            countdownLabel.fontColor = .white
            countdownLabel.setScale(1.0)
            countdownLabel.alpha = 1.0
            countdownNode.removeAllActions(); countdownNode.alpha = 0.0
            fireNode.removeAllActions();     fireNode.alpha = 0.0
            resultNode.removeAllActions();   resultNode.alpha = 0.0
            
        case .waiting:
            dimmingNode.run(SKAction.fadeAlpha(to: 0.7, duration: 0.2))
            countdownLabel.removeAllActions()
            countdownLabel.text = "May the Fastest Hand Win..."
            countdownLabel.fontSize = 40
            countdownLabel.fontColor = .white
            countdownLabel.setScale(1.0)
            countdownLabel.alpha = 1.0
            countdownNode.removeAllActions(); countdownNode.alpha = 0.0
            fireNode.removeAllActions();     fireNode.alpha = 0.0
            resultNode.removeAllActions();   resultNode.alpha = 0.0
            
        case .counting(let n):
            dimmingNode.alpha = 0.7
            fireNode.removeAllActions();   fireNode.alpha = 0.0
            resultNode.removeAllActions(); resultNode.alpha = 0.0
            
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
            playCountdownTickHaptic()

        case .fire:
            // Lift the dimming overlay and hide number nodes
            countdownLabel.removeAllActions(); countdownLabel.run(SKAction.fadeOut(withDuration: 0.15))
            countdownNode.removeAllActions();  countdownNode.run(SKAction.fadeOut(withDuration: 0.15))
            resultNode.removeAllActions();     resultNode.alpha = 0.0
            dimmingNode.run(SKAction.fadeOut(withDuration: 0.25))
            // Show fire image with a looping pulse
            fireNode.removeAllActions()
            fireNode.setScale(0.2)
            fireNode.alpha = 1.0
            let grow = SKAction.scale(to: 1.05, duration: 0.18)
            let pulse = SKAction.sequence([
                SKAction.scale(to: 0.42, duration: 0.35),
                SKAction.scale(to: 0.69, duration: 0.35)
            ])
            fireNode.run(SKAction.sequence([grow, SKAction.repeatForever(pulse)]))
        }
    }
    
    private func handleOutcome(_ outcome: ShotController.Outcome) {
        // Stop any in-progress animations
        hideHolsterHint()
        fireNode.removeAllActions();   fireNode.run(SKAction.fadeOut(withDuration: 0.15))
        countdownNode.removeAllActions(); countdownNode.alpha = 0.0
        countdownLabel.removeAllActions(); countdownLabel.alpha = 0.0
        dimmingNode.run(SKAction.fadeAlpha(to: 0.7, duration: 0.3))
        resultNode.removeAllActions()
        
        let resultTex = SKTexture(imageNamed: outcome == .winner ? "win" : "lose")
        resultTex.filteringMode = .nearest
        
        let targetHeight: CGFloat = 260
        let aspect = resultTex.size().width / resultTex.size().height
        resultNode.texture = resultTex
        resultNode.size = CGSize(width: targetHeight * aspect, height: targetHeight)
        
        resultNode.setScale(0.2)
        resultNode.alpha = 1.0
        resultNode.run(SKAction.sequence([
            SKAction.scale(to: 0.69, duration: 0.15),
            SKAction.scale(to: 0.42, duration: 0.10)
        ]))
        
        if outcome == .loser {
            playGetHitHaptic()
        }
    }
    
    private func updateHearts(_ lives: Int) {
        for (i, heart) in hearts.enumerated() {
            heart.texture = SKTexture(imageNamed: i < lives ? "Life_full" : "lost_life")
        }
    }
    
    private func showMatchOver(won: Bool) {
        resultNode.removeAllActions()
        let tex = SKTexture(imageNamed: won ? "victory" : "game_over")
        tex.filteringMode = .nearest
        
        let targetHeight: CGFloat = 400
        let aspect = tex.size().width / tex.size().height
        resultNode.texture = tex
        resultNode.size = CGSize(width: targetHeight * aspect, height: targetHeight)
        
        resultNode.setScale(0.2)
        resultNode.alpha = 1.0
        resultNode.run(SKAction.sequence([
            SKAction.scale(to: 0.69, duration: 0.15),
            SKAction.scale(to: 0.42, duration: 0.10)
        ]))
        
        showReturnToMenuPrompt()
    }
    
    private func showContinuePrompt() {
        countdownLabel.removeAllActions()
        countdownLabel.text = "Tap to continue"
        countdownLabel.fontSize = 44
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: 0, y: -100)
        countdownLabel.setScale(1.0)
        countdownLabel.alpha = 1.0
        countdownLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))
    }
    
    private func showReturnToMenuPrompt() {
        countdownLabel.removeAllActions()
        countdownLabel.position = CGPoint(x: 0, y: -280)   // below the result image
        countdownLabel.text = "Tap to return to menu"
        countdownLabel.fontSize = 36
        countdownLabel.fontColor = .white
        countdownLabel.setScale(1.0)
        countdownLabel.alpha = 1.0
        countdownLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))
    }
    
    
    // MARK: - Networking (scene-ready handshake)
    
    private func setupNetworking() {
        guard let connection else {
            print("⚠️ GameScene has no connection — running solo.")
            return
        }
        
        // Register before announcing so we can't miss the peer's reply.
        connection.onEvent(channel: GameChannel.scene.rawValue) { [weak self] body in
            self?.handleSceneEvent(body)
        }
        
        localSceneReady = true
        connection.sendEvent(channel: GameChannel.scene.rawValue, body: Data([SceneOp.ready]))
        announceIfBothReady()
    }
    
    private func handleSceneEvent(_ body: Data) {
        guard let op = body.first, let connection else { return }
        switch op {
        case SceneOp.ready:
            remoteSceneReady = true
            // Reply so the peer learns we're here even if our first "ready" landed
            // before it had registered its handler.
            connection.sendEvent(channel: GameChannel.scene.rawValue, body: Data([SceneOp.readyAck]))
            announceIfBothReady()
        case SceneOp.readyAck:
            remoteSceneReady = true
            announceIfBothReady()
        default:
            break
        }
    }
    
    private func announceIfBothReady() {
        guard !didAnnounceDuel, localSceneReady, remoteSceneReady,
              let connection else { return }
        didAnnounceDuel = true
        
        let role = connection.isHost ? "HOST" : "PEER"
        let opponent: String
        if case let .connected(peerName) = connection.state {
            opponent = peerName
        } else {
            opponent = "opponent"
        }
        print("[\(role)] \(connection.myName) and \(opponent) both reached the scene.")
        
        // Entering the game scene implies readiness — kick off the countdown.
        countdownController.pressReady()
    }
    
    // MARK: - Touch Handling
        
    private func handleTapForUIProgression() {
        if case .matchOver = matchController.matchPhase {
            onRequestReturnToMenu?()
            return
        }
        if matchController.matchPhase == .awaitingContinue {
            matchController.continueToNextRound()
            return
        }
        // Intentionally no fire-handling here.
        // Taps during the live duel window are ignored — only the volume trigger can fire.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTapForUIProgression()
    }
    
    // MARK: - Shooting (volume trigger only)

    private func attemptFire() {
        guard case .fire = countdownController.phase,
              !shotController.didFire,
              shotController.outcome == nil else {
            return
        }
        // Pose gate: the shot only counts from a raised gun after a clean
        // (or corrected) holster start — see DrawPoseController.
        guard drawPoseController.canFire else {
            dryFire()
            return
        }
        shotController.fire()
    }

    /// Trigger pulled while not in a valid draw pose — the hammer just clicks.
    private func dryFire() {
        playDryFireHaptic()
        // Nudge the FIRE prompt sideways so the blocked shot is visible too.
        let shake = SKAction.sequence([
            .moveBy(x: 12, y: 0, duration: 0.04),
            .moveBy(x: -24, y: 0, duration: 0.06),
            .moveBy(x: 12, y: 0, duration: 0.04),
            .move(to: CGPoint(x: 0, y: 0), duration: 0.02)
        ])
        fireNode.run(shake, withKey: "dryFireShake")
    }
    
    // MARK: - Scene Setup Methods
    
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
    
    private func setupPlayerUI() {
        let panel = SKSpriteNode(imageNamed: "Button_long")
        
        panel.setScale(0.15)
        panel.texture?.filteringMode = .nearest
        
        let xPos = -(self.size.width / 2) + (panel.size.width / 2) + 60
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 30
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        let label = SKLabelNode(fontNamed: "YourCustomPixelFont-Regular")
        label.text = "Player 1 / Round 1"
        
        label.fontSize = 80
        label.fontColor = SKColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        
        panel.addChild(label)
        addChild(panel)
    }
    
    private func setupHealthUI() {
        let panel = SKSpriteNode(imageNamed: "Button")
        
        panel.setScale(0.15)
        panel.texture?.filteringMode = .nearest
        
        let xPos = (self.size.width / 2) - (panel.size.width / 2) - 60
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 30
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        let spacing: CGFloat = 160.0
        let startX = -(spacing)
        
        for i in 0..<3 {
            let heart = SKSpriteNode(imageNamed: "Life_full")
            heart.texture?.filteringMode = .nearest
            
            heart.setScale(0.08)
            
            heart.position = CGPoint(x: startX + (CGFloat(i) * spacing), y: 0)
            heart.zPosition = 6
            
            panel.addChild(heart)
            
            hearts.append(heart)
        }
        
        addChild(panel)
    }
    
    private func setupDimmingLayer() {
        dimmingNode = SKSpriteNode(color: .black, size: self.size)
        dimmingNode.alpha = 0.7
        dimmingNode.zPosition = 10
        addChild(dimmingNode)
    }
    
    private func setupCountdownLabel() {
        countdownLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        countdownLabel.fontSize = 140
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.text = "Waiting..."
        countdownLabel.alpha = 1.0
        countdownLabel.zPosition = 11
        addChild(countdownLabel)
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
    
    private func setupResultNode() {
        resultNode = SKSpriteNode()
        resultNode.position = CGPoint(x: 0, y: 0)
        resultNode.zPosition = 13
        resultNode.alpha = 0.0
        addChild(resultNode)
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

    // MARK: - Holster hint (pose-gate coaching)

    /// Bottom-of-screen coaching: holster guidance while the countdown runs,
    /// a false-start warning during the firing window, nothing once the round
    /// is decided or when this device can't sense motion.
    private func refreshHolsterHint(phase: CountdownController.Phase) {
        guard drawPoseController.isAvailable,
              shotController.outcome == nil, !shotController.didFire,
              matchController.matchPhase == .playing else {
            hideHolsterHint()
            return
        }
        switch phase {
        case .notReady:
            hideHolsterHint()
        case .waiting, .counting:
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
        }
    }

    private func showHolsterHint(_ text: String, color: SKColor, pulse: Bool) {
        // Pose updates stream in continuously; don't restart the animation
        // unless the message actually changed.
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
    
    // MARK: - Hardware Integration (Audio, Flashlight, Haptics)
    
    private func bang() {
        playGunshotAudio()
        playGunshotHaptic()
        fireMuzzleFlash()
        // Stop the fire draw-prompt
        fireNode.removeAllActions()
        fireNode.run(SKAction.fadeOut(withDuration: 0.1))
        // Burst the bang shot-effect node
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
    
    private func playGunshotAudio() {
        guard let soundAsset = NSDataAsset(name: "rayne-mixedgun") else {
            print("Could not find the audio asset in the catalog.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: soundAsset.data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
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
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play gunshot haptic: \(error.localizedDescription)")
        }
    }
    
    /// Sharp little click for a trigger pull outside a valid draw pose.
    private func playDryFireHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)

        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play dry fire haptic: \(error.localizedDescription)")
        }
    }

    /// Buzz when the firing window opens, so the signal is felt even while the
    /// phone is holstered at the hip rather than being watched.
    private func playDrawSignalHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)

        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play draw signal haptic: \(error.localizedDescription)")
        }
    }

    /// Short firm tick on each countdown number (3, 2, 1).
    private func playCountdownTickHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)

        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play countdown tick haptic: \(error.localizedDescription)")
        }
    }

    private func playGetHitHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
        
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 0.4)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play get hit haptic: \(error.localizedDescription)")
        }
    }
}

#if DEBUG // used as helper for preview
extension GameScene {
    func previewApply(phase: CountdownController.Phase) {
        handlePhaseChange(phase)
    }
    func previewApply(outcome: ShotController.Outcome) {
        handleOutcome(outcome)
    }
    func previewApply(livesRemaining: Int) {
        updateHearts(livesRemaining)
    }
}
#endif

#if DEBUG // preview with helper for didMove
private struct GameScenePreviewHarness: View {
    let configure: (GameScene) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let scene: GameScene = {
                let s = GameScene(size: geo.size)
                s.scaleMode = .resizeFill
                return s
            }()
            
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        configure(scene)
                    }
                }
        }
    }
}
#endif

#Preview("Waiting") {
    GameScenePreviewHarness { $0.previewApply(phase: .waiting) }
}

#Preview("Counting - 3") {
    GameScenePreviewHarness { $0.previewApply(phase: .counting(3)) }
}

#Preview("Counting - 2") {
    GameScenePreviewHarness { $0.previewApply(phase: .counting(2)) }
}

#Preview("Counting - 1") {
    GameScenePreviewHarness { $0.previewApply(phase: .counting(1)) }
}

#Preview("Fire") {
    GameScenePreviewHarness { $0.previewApply(phase: .fire) }
}

#Preview("Win") {
    GameScenePreviewHarness { scene in
        scene.previewApply(phase: .fire)
        scene.previewApply(outcome: .winner)
    }
}

#Preview("Lose") {
    GameScenePreviewHarness { scene in
        scene.previewApply(phase: .fire)
        scene.previewApply(outcome: .loser)
    }
}

#Preview("2 Lives Left") {
    GameScenePreviewHarness { $0.previewApply(livesRemaining: 2) }
}

#Preview("Game Over (0 Lives)") {
    GameScenePreviewHarness { $0.previewApply(livesRemaining: 0) }
}
