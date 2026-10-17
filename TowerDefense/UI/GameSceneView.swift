import SpriteKit
import SwiftUI

/// Hosts the battlefield SKView. The scene is owned by the session, so it survives
/// SwiftUI re-layouts such as rotating the device.
struct GameSceneView: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = Pal.ink.uiColor
        view.presentScene(scene)

        let pinch = UIPinchGestureRecognizer(target: scene, action: #selector(GameScene.handlePinch))
        let pan = UIPanGestureRecognizer(target: scene, action: #selector(GameScene.handlePan))
        pan.minimumNumberOfTouches = 2
        let reset = UITapGestureRecognizer(target: scene, action: #selector(GameScene.resetZoom))
        reset.numberOfTouchesRequired = 2
        for gesture in [pinch, pan, reset] as [UIGestureRecognizer] {
            gesture.delegate = scene
            view.addGestureRecognizer(gesture)
        }
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
    }
}
