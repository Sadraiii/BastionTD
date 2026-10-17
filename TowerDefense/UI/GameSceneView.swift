import SpriteKit
import SwiftUI

/// Hosts the battlefield SKView. The scene is owned by the session, so it survives
/// SwiftUI re-layouts such as rotating the device.
struct GameSceneView: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = 60
        view.backgroundColor = Pal.ink.uiColor
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
    }
}
