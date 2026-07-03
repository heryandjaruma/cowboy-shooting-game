import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupBackground()
        setupGun()
        setupPlayerUI()
        setupHealthUI()
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
            let heart = SKSpriteNode(imageNamed: "Life_full") // Adjusted to match your previous screenshot exactly
            heart.texture?.filteringMode = .nearest
            
            heart.setScale(0.09)
            
            heart.position = CGPoint(x: startX + (CGFloat(i) * spacing), y: 0)
            heart.zPosition = 6
            
            panel.addChild(heart)
        }
        
        addChild(panel)
    }
}

