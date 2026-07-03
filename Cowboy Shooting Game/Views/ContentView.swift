//
//  ContentView.swift
//  Cowboy Shooting Game
//
//  Created by Heryan Djaruma on 24/06/26.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    
    var gameScene: SKScene {
        let scene = GameScene(size: CGSize(width: 1920, height: 1080))
        
        scene.scaleMode = .aspectFill
        
        return scene
    }
    
    var body: some View {
        SpriteView(scene: gameScene)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
