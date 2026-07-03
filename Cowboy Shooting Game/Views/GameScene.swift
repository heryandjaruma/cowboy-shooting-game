import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    // MARK: - Properties
    
    private var hearts: [SKSpriteNode] = []
    private var currentLives = 3
    
    private var dimmingNode: SKSpriteNode!
    private var countdownLabel: SKLabelNode!
    private var bangNode: SKSpriteNode!
    
    private var isSequenceRunning = false
    
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
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        let showFire = SKAction.run { self.countdownLabel.text = "FIRE" } // Based on your screenshot reference
        
        let fireAction = SKAction.run {
            self.countdownLabel.alpha = 0.0
            self.dimmingNode.alpha = 0.0
            self.bangNode.alpha = 1.0
            self.currentLives -= 1
            let targetHeart = self.hearts[self.currentLives]
            targetHeart.texture = SKTexture(imageNamed: "lost_life")
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
        
        gun.setScale(0.5)
        
        gun.position = CGPoint(x: 0, y: -40)
        gun.zPosition = 1
        gun.texture?.filteringMode = .nearest
        
        addChild(gun)
    }
    
    private func setupPlayerUI() {
        let panel = SKSpriteNode(imageNamed: "Button_long")
        
        panel.setScale(0.36)
        panel.texture?.filteringMode = .nearest
        
        let xPos = -(self.size.width / 2) + (panel.size.width / 2) + 90
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 130
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        let label = SKLabelNode(fontNamed: "YourCustomPixelFont-Regular")
        label.text = "Player 1 / Round 1"
        
        label.fontSize = 40
        label.fontColor = SKColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        
        panel.addChild(label)
        addChild(panel)
    }
    
    private func setupHealthUI() {
        let panel = SKSpriteNode(imageNamed: "Button")
        
        panel.setScale(0.36)
        panel.texture?.filteringMode = .nearest
        
        let xPos = (self.size.width / 2) - (panel.size.width / 2) - 90
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 130
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        let spacing: CGFloat = 180.0
        let startX = -(spacing)
        
        for i in 0..<3 {
            let heart = SKSpriteNode(imageNamed: "Life_full")
            heart.texture?.filteringMode = .nearest
            
            heart.setScale(0.09)
            
            heart.position = CGPoint(x: startX + (CGFloat(i) * spacing), y: 0)
            heart.zPosition = 6
            
            panel.addChild(heart)
            
            hearts.append(heart)
        }
        
        addChild(panel)
    }
    
    // MARK: - New Interaction Node Setups
    
    private func setupDimmingLayer() {
        dimmingNode = SKSpriteNode(color: .black, size: self.size)
        dimmingNode.alpha = 0.0
        dimmingNode.zPosition = 10
        addChild(dimmingNode)
    }
    
    private func setupCountdownLabel() {
        countdownLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold") // Default font for now
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
        
        bangNode.position = CGPoint(x: 0, y: -20)
        bangNode.zPosition = 12
        bangNode.alpha = 0.0
        
        addChild(bangNode)
    }
}
