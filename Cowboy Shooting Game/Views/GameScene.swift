import SpriteKit
import GameplayKit
import AVFoundation
import CoreHaptics
import UIKit // Required for NSDataAsset

class GameScene: SKScene {
    
    // MARK: - Properties
    
    private var hearts: [SKSpriteNode] = []
    private var currentLives = 3
    
    private var dimmingNode: SKSpriteNode!
    private var countdownLabel: SKLabelNode!
    private var bangNode: SKSpriteNode!
    
    private var isSequenceRunning = false

    var connection: GameConnectionManager?
    private var localSceneReady = false
    private var remoteSceneReady = false
    private var didAnnounceDuel = false

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
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupBackground()
        setupGun()
        setupPlayerUI()
        setupHealthUI()
        setupDimmingLayer()
        setupCountdownLabel()
        setupBangNode()
        
        // Boot up hardware features
        prepareHaptics()
        setupAudioSession()

        // Carrying connection here
        setupNetworking()
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
        print("[\(role)] \(connection.myName) joined \(opponent) joined.")
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1. Trigger the immediate shoot effects on screen touch
        playGunshotAudio()
        playGunshotHaptic()
        fireMuzzleFlash()
        
        // 2. Trigger the sequence (only if it isn't already running and player has lives)
        guard !isSequenceRunning, currentLives > 0 else { return }
        triggerFireSequence()
    }
    
    // MARK: - Interaction Sequence
    
    private func triggerFireSequence() {
        isSequenceRunning = true
        
        let dimIn = SKAction.fadeAlpha(to: 0.7, duration: 0.2)
        dimmingNode.run(dimIn)
        
        let waitOneSec = SKAction.wait(forDuration: 1.0)
        
        let show3 = SKAction.run { self.countdownLabel.text = "3"; self.countdownLabel.alpha = 1.0 }
        let show2 = SKAction.run { self.countdownLabel.text = "2" }
        let show1 = SKAction.run { self.countdownLabel.text = "1" }
        let showFire = SKAction.run { self.countdownLabel.text = "FIRE" }
        
        let fireAction = SKAction.run {
            self.countdownLabel.alpha = 0.0
            self.dimmingNode.alpha = 0.0
            self.bangNode.alpha = 1.0
            
            self.currentLives -= 1
            let targetHeart = self.hearts[self.currentLives]
            targetHeart.texture = SKTexture(imageNamed: "lost_life")
            
            // Trigger the "Get Hit" haptic when the life is lost
            self.playGetHitHaptic()
        }
        
        let hideBang = SKAction.run {
            self.bangNode.alpha = 0.0
            self.isSequenceRunning = false
        }
        
        let sequence = SKAction.sequence([
            show3, waitOneSec,
            show2, waitOneSec,
            show1, waitOneSec,
            showFire, waitOneSec,
            fireAction,
            SKAction.wait(forDuration: 0.5),
            hideBang
        ])
        
        run(sequence)
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
        dimmingNode.alpha = 0.0
        dimmingNode.zPosition = 10
        addChild(dimmingNode)
    }
    
    private func setupCountdownLabel() {
        countdownLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        countdownLabel.fontSize = 140
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.alpha = 0.0
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
    
    // MARK: - Hardware Integration (Audio, Flashlight, Haptics)
    
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
