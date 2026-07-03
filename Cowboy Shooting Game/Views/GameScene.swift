import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    override func didMove(to view: SKView) {
        // Set the anchor point to the center of the screen
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupBackground()
        setupGun()
        setupPlayerUI()
        setupHealthUI()
    }
    
    // MARK: - Scene Setup Methods
    
    private func setupBackground() {
        let background = SKSpriteNode(imageNamed: "desert_bg")
        background.size = self.size // Stretch or scale to fit the screen
        background.zPosition = -10  // Ensure it stays behind everything else
        background.texture?.filteringMode = .nearest // Keep pixel art sharp
        
        addChild(background)
    }
    
    private func setupGun() {
        let gun = SKSpriteNode(imageNamed: "Peacemaker_gun")
        
        // Adjust this if the gun is still too big/small
        gun.setScale(0.5)
        
        // Positioned slightly below the absolute center
        gun.position = CGPoint(x: 0, y: -40)
        gun.zPosition = 1
        gun.texture?.filteringMode = .nearest
        
        addChild(gun)
    }
    
    private func setupPlayerUI() {
        // 1. The wooden panel background
        let panel = SKSpriteNode(imageNamed: "Button_long")
        
        // FIX: Scaled down from 2.0. Adjust this (e.g., 0.3, 0.6) until the panel looks right.
        panel.setScale(0.36)
        panel.texture?.filteringMode = .nearest
        
        // Position at the top left
        let xPos = -(self.size.width / 2) + (panel.size.width / 2) + 90
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 130
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        // 2. The Text Label
        let label = SKLabelNode(fontNamed: "YourCustomPixelFont-Regular")
        label.text = "Player 1 / Round 1"
        
        // FIX: Because the parent panel is scaled down to 0.5, the text will shrink too.
        // We boost the font size here to compensate.
        label.fontSize = 40
        label.fontColor = SKColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        
        panel.addChild(label)
        addChild(panel)
    }
    
    private func setupHealthUI() {
        // 1. The wooden panel background
        let panel = SKSpriteNode(imageNamed: "Button")
        
        // FIX: Scaled down to match the left panel
        panel.setScale(0.36)
        panel.texture?.filteringMode = .nearest
        
        // Position at the top right
        let xPos = (self.size.width / 2) - (panel.size.width / 2) - 90
        let yPos = (self.size.height / 2) - (panel.size.height / 2) - 130
        panel.position = CGPoint(x: xPos, y: yPos)
        panel.zPosition = 5
        
        // 2. The Hearts
        // We need to increase spacing because the parent scale shrinks the coordinate space
        let spacing: CGFloat = 180.0
        let startX = -(spacing)
        
        for i in 0..<3 {
            let heart = SKSpriteNode(imageNamed: "Life_full") // Adjusted to match your previous screenshot exactly
            heart.texture?.filteringMode = .nearest
            
            // FIX: Scale the hearts UP relative to the shrunken panel so they are visible
            heart.setScale(0.09)
            
            heart.position = CGPoint(x: startX + (CGFloat(i) * spacing), y: 0)
            heart.zPosition = 6
            
            panel.addChild(heart)
        }
        
        addChild(panel)
    }
}

