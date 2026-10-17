import SpriteKit

/// Short-lived pixel effects. All positions are world art-pixel coordinates.
extension GameScene {
    /// Busy waves can spawn many effects; past this count cosmetic ones are skipped.
    private var effectBudgetExceeded: Bool { effectLayer.children.count > 140 }

    func playFrames(_ frames: [SKTexture], at point: CGPoint, timePerFrame: TimeInterval, z: CGFloat = 0) {
        guard let first = frames.first, !effectBudgetExceeded else { return }
        let sprite = SKSpriteNode(texture: first)
        sprite.usePixelAnchor()
        sprite.position = point
        sprite.zPosition = z
        effectLayer.addChild(sprite)
        sprite.run(.sequence([.animate(with: frames, timePerFrame: timePerFrame), .removeFromParent()]))
    }

    /// A pixel-font popup that steps upward and blinks out.
    func floatText(_ text: String, color: PixelColor, at point: CGPoint) {
        guard labelLayer.children.count < 40 else { return }
        let sprite = SKSpriteNode(texture: Art.text(text, color: color))
        sprite.usePixelAnchor()
        sprite.position = point
        labelLayer.addChild(sprite)
        let step = SKAction.sequence([.moveBy(x: 0, y: 2, duration: 0), .wait(forDuration: 0.09)])
        sprite.run(.sequence([
            .repeat(step, count: 5),
            .wait(forDuration: 0.25),
            .hide(), .wait(forDuration: 0.06), .unhide(), .wait(forDuration: 0.06),
            .removeFromParent(),
        ]))
    }

    /// Square pixel debris.
    func sparks(at point: CGPoint, color: PixelColor, count: Int) {
        guard !effectBudgetExceeded else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.pixel
        emitter.particleBirthRate = 4000
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 45
        emitter.particleSpeedRange = 30
        emitter.yAcceleration = -90
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 1
        emitter.particleColor = color.uiColor
        emitter.particleColorBlendFactor = 1
        emitter.position = point
        emitter.targetNode = effectLayer
        effectLayer.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }

    /// Shows a one-off texture (lightning) with a quick retro flicker.
    func flicker(_ texture: SKTexture, origin: CGPoint) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.position = origin
        effectLayer.addChild(sprite)
        sprite.run(.sequence([
            .wait(forDuration: 0.05), .hide(), .wait(forDuration: 0.03), .unhide(),
            .wait(forDuration: 0.06), .removeFromParent(),
        ]))
    }

    /// Falling snow over a power field (Blizzard) for its duration.
    func blizzard(at point: CGPoint, radius: CGFloat, duration: Double) {
        playFrames(Art.ringFrames(radius: Int(radius), color: Pal.cyan, accent: Pal.white), at: point, timePerFrame: 0.06, z: -2)
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.pixel
        emitter.particleBirthRate = radius * 1.6
        emitter.particleLifetime = 0.9
        emitter.particlePositionRange = CGVector(dx: radius * 1.6, dy: radius * 1.6)
        emitter.emissionAngle = -.pi / 2 - 0.3
        emitter.particleSpeed = 22
        emitter.particleSpeedRange = 10
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -0.8
        emitter.particleScale = 1
        emitter.particleScaleRange = 1
        emitter.particleColor = Pal.white.uiColor
        emitter.particleColorBlendFactor = 1
        emitter.position = point
        emitter.targetNode = effectLayer
        effectLayer.addChild(emitter)
        emitter.run(.sequence([
            .wait(forDuration: duration),
            .run { [weak emitter] in emitter?.particleBirthRate = 0 },
            .wait(forDuration: 1),
            .removeFromParent(),
        ]))
    }

    /// Jolts the battlefield by whole art pixels.
    func shake(intensity: CGFloat) {
        guard let layout, world.action(forKey: "shake") == nil else { return }
        let origin = layout.origin
        let px = layout.pixelSize * intensity
        let offsets = [CGPoint(x: px, y: 0), CGPoint(x: -px, y: px), CGPoint(x: 0, y: -px), .zero]
        let moves = offsets.map { SKAction.sequence([.move(to: origin + $0, duration: 0), .wait(forDuration: 0.035)]) }
        world.run(.sequence(moves + [.move(to: origin, duration: 0)]), withKey: "shake")
    }
}
