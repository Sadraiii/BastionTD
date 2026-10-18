import SpriteKit

extension SKSpriteNode {
    /// Puts the anchor on a pixel boundary so odd-sized sprites stay crisp.
    func usePixelAnchor(bottom: Bool = false) {
        guard let size = texture?.size(), size.width > 0, size.height > 0 else { return }
        anchorPoint = CGPoint(
            x: floor(size.width / 2) / size.width,
            y: bottom ? 0 : floor(size.height / 2) / size.height
        )
    }
}

/// A hero tower: stone base (with tier pips) plus a turret that turns toward its
/// target in 16 steps. Built in art-pixel units inside the scene's world node.
@MainActor
final class TowerNode: SKNode {
    let towerID: Int
    let kind: TowerKind
    private(set) var tiers: [Int]
    private let base: SKSpriteNode
    private let turret: SKSpriteNode
    private let badge = SKSpriteNode(texture: Art.powerReady)
    private var displayedAngle: CGFloat = .pi / 2
    private var targetAngle: CGFloat = .pi / 2
    private var state = VisualState.normal

    private enum VisualState { case normal, frenzied, disabled }

    init(towerID: Int, kind: TowerKind, tiers: [Int] = [0, 0]) {
        self.towerID = towerID
        self.kind = kind
        self.tiers = tiers
        base = SKSpriteNode(texture: Art.towerBase(kind, tiers: tiers))
        turret = SKSpriteNode(texture: Art.turret(kind, tiers: tiers))
        super.init()
        base.zPosition = 0
        turret.zPosition = 1
        badge.usePixelAnchor(bottom: true)
        badge.position = CGPoint(x: 0, y: 8)
        badge.zPosition = 3
        badge.isHidden = true
        badge.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1, duration: 0), .wait(forDuration: 0.3),
            .moveBy(x: 0, y: -1, duration: 0), .wait(forDuration: 0.3),
        ])))
        addChild(base)
        addChild(turret)
        addChild(badge)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var rotates: Bool { kind.rotates }

    func setTiers(_ tiers: [Int]) {
        self.tiers = tiers
        base.texture = Art.towerBase(kind, tiers: tiers)
        turret.texture = Art.turret(kind, tiers: tiers)
    }

    /// Tints the whole tower, used for the invalid-placement ghost.
    func tint(_ color: PixelColor?) {
        for sprite in [base, turret] {
            sprite.color = color?.uiColor ?? .white
            sprite.colorBlendFactor = color == nil ? 0 : 0.6
        }
    }

    func update(tower: Tower, aimAngle: CGFloat, dt: Double) {
        badge.isHidden = !tower.isPowerReady
        let newState: VisualState = tower.isDisabled ? .disabled : (tower.isFrenzied || tower.isRallied) ? .frenzied : .normal
        if newState != state {
            state = newState
            turret.removeAction(forKey: "state")
            switch newState {
            case .normal:
                tint(nil)
            case .disabled:
                tint(Pal.steel)
                turret.run(.repeatForever(.sequence([
                    .moveBy(x: 1, y: 0, duration: 0), .wait(forDuration: 0.06),
                    .moveBy(x: -1, y: 0, duration: 0), .wait(forDuration: 0.06),
                ])), withKey: "state")
            case .frenzied:
                turret.color = Pal.towerLight(kind).uiColor
                turret.run(.repeatForever(.sequence([
                    .run { [weak turret] in turret?.colorBlendFactor = 0.6 }, .wait(forDuration: 0.08),
                    .run { [weak turret] in turret?.colorBlendFactor = 0 }, .wait(forDuration: 0.08),
                ])), withKey: "state")
            }
        }
        guard !tower.isDisabled else { return }
        guard rotates else {
            // Spinning heroes (frost crystal, tesla coil, cyclone, clock) turn slowly.
            if kind == .cyclone || kind == .chrono { turret.zRotation -= CGFloat(dt) * (kind == .cyclone ? 3 : 0.6) }
            return
        }
        targetAngle = aimAngle
        var diff = targetAngle - displayedAngle
        diff = atan2(sin(diff), cos(diff))
        let maxStep = CGFloat(dt) * 10
        displayedAngle += max(-maxStep, min(maxStep, diff))
        let step = CGFloat.pi / 8
        let snapped = (displayedAngle / step).rounded() * step
        turret.zRotation = snapped - .pi / 2
        let kick: CGFloat = tower.recoil > 0.05 ? 1 : 0
        turret.position = CGPoint(x: (-cos(snapped) * kick).rounded(), y: (-sin(snapped) * kick).rounded())
    }

    /// World offset of the muzzle relative to the tower center.
    var muzzleOffset: CGPoint {
        let snapped = (displayedAngle / (.pi / 8)).rounded() * (.pi / 8)
        return CGPoint(x: (cos(snapped) * 8).rounded(), y: (sin(snapped) * 8).rounded())
    }

    /// Brief white blink when a non-rotating tower fires.
    func flash() {
        guard state == .normal else { return }
        turret.removeAction(forKey: "flash")
        turret.run(.sequence([
            .run { [weak turret] in turret?.color = .white; turret?.colorBlendFactor = 0.7 },
            .wait(forDuration: 0.08),
            .run { [weak turret] in turret?.colorBlendFactor = 0 },
        ]), withKey: "flash")
    }
}

/// An enemy sprite with walk animation, ground shadow, status tint and health bar.
@MainActor
final class EnemyNode: SKNode {
    let enemyID: Int
    let kind: EnemyKind
    private let frames: [SKTexture]
    private let body: SKSpriteNode
    private let shadow: SKSpriteNode
    private let healthBack: SKSpriteNode
    private let healthFill: SKSpriteNode
    private let shieldBubble: SKSpriteNode
    private let confusedMark = SKSpriteNode(texture: Art.text("?", color: Pal.pink))
    private let barWidth: CGFloat
    private var frameIndex = 0
    private var animationClock: Double

    init(enemyID: Int, kind: EnemyKind) {
        self.enemyID = enemyID
        self.kind = kind
        frames = Art.enemyFrames(kind)
        body = SKSpriteNode(texture: frames[0])
        body.usePixelAnchor(bottom: true)
        let spriteSize = frames[0].size()
        let shadowWidth = max(4, Int(spriteSize.width) - 3) & ~1
        shadow = SKSpriteNode(texture: Art.shadow(width: shadowWidth))
        shadow.usePixelAnchor()
        barWidth = max(8, min(16, (spriteSize.width - 3).rounded()))
        healthBack = SKSpriteNode(color: Pal.ink.uiColor, size: CGSize(width: barWidth + 2, height: 3))
        healthFill = SKSpriteNode(color: Pal.lime.uiColor, size: CGSize(width: barWidth, height: 1))
        animationClock = Double(enemyID % 7) * 0.13
        shieldBubble = SKSpriteNode(texture: Art.shieldBubble(width: Int(spriteSize.width)))
        super.init()

        let groundY: CGFloat = -3
        shadow.position = CGPoint(x: 0, y: groundY)
        shadow.zPosition = -1
        body.position = CGPoint(x: 0, y: kind.isFlying ? groundY + 6 : groundY - 1)
        healthBack.anchorPoint = CGPoint(x: 0, y: 0)
        healthBack.position = CGPoint(x: -(barWidth / 2).rounded() - 1, y: body.position.y + spriteSize.height + 1)
        healthBack.zPosition = 2
        healthFill.anchorPoint = CGPoint(x: 0, y: 0)
        healthFill.position = CGPoint(x: 1, y: 1)
        healthBack.addChild(healthFill)
        healthBack.isHidden = true
        shieldBubble.position = CGPoint(x: 0, y: body.position.y + (spriteSize.height / 2).rounded())
        shieldBubble.zPosition = 1
        shieldBubble.isHidden = true
        addChild(shadow)
        addChild(body)
        addChild(shieldBubble)
        addChild(healthBack)
        confusedMark.usePixelAnchor()
        confusedMark.position = CGPoint(x: 0, y: healthBack.position.y + 7)
        confusedMark.zPosition = 3
        confusedMark.isHidden = true
        addChild(confusedMark)
        if kind.isCamo {
            body.alpha = 0.5
            body.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 0.6, duration: 0.6),
            ])))
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(enemy: Enemy, layout: BoardLayout, dt: Double) {
        position = layout.snappedWorldPoint(enemy.position)

        let rate: Double = switch kind {
        case .runner, .shardling, .caveBat, .lavaBlob: 9
        case .wisp: 7
        case .titan, .brute: 3.5
        default: 5
        }
        if !enemy.isStunned && !enemy.isStone { animationClock += dt * rate }
        confusedMark.isHidden = !enemy.isConfused
        if kind.isCamo && enemy.revealed && body.hasActions() {
            body.removeAllActions()
            body.alpha = 1
        }
        let newFrame = Int(animationClock) % frames.count
        if newFrame != frameIndex {
            frameIndex = newFrame
            body.texture = frames[newFrame]
        }

        shieldBubble.isHidden = enemy.shield <= 0
        // Burrowed sandworms sink out of sight; cloaked allies of a Bog Witch fade.
        if kind == .sandworm {
            body.alpha = enemy.isStone ? 0.25 : 1
        } else if !kind.isCamo {
            body.alpha = enemy.isHidden ? 0.5 : 1
        }
        if enemy.hitFlash > 0 {
            body.color = .white
            body.colorBlendFactor = 0.85
        } else if enemy.isStone && kind != .sandworm {
            body.color = Pal.steel.uiColor
            body.colorBlendFactor = 0.9
        } else if enemy.isStunned {
            body.color = Pal.mist.uiColor
            body.colorBlendFactor = 0.7
        } else if enemy.isBurning && Int(animationClock * 4) % 2 == 0 {
            body.color = Pal.orange.uiColor
            body.colorBlendFactor = 0.55
        } else if enemy.isPoisoned {
            body.color = Pal.lime.uiColor
            body.colorBlendFactor = 0.45
        } else if enemy.isSlowed {
            body.color = Pal.cyan.uiColor
            body.colorBlendFactor = 0.5
        } else {
            body.colorBlendFactor = 0
        }

        let fraction = enemy.healthFraction
        healthBack.isHidden = fraction >= 0.999
        if !healthBack.isHidden {
            healthFill.size.width = max(1, (CGFloat(fraction) * barWidth).rounded())
            healthFill.color = fraction > 0.6 ? Pal.lime.uiColor : fraction > 0.3 ? Pal.amber.uiColor : Pal.red.uiColor
        }
    }
}

/// Bolt, missile or mortar shell in flight. Shells rise above their ground shadow.
@MainActor
final class ProjectileNode: SKNode {
    private let core: SKSpriteNode
    private let shadow: SKSpriteNode?

    private let kind: Projectile.Kind

    init(kind: Projectile.Kind) {
        self.kind = kind
        core = SKSpriteNode(texture: kind == .missile ? Art.missile : Art.shell)
        core.usePixelAnchor()
        shadow = kind == .shell ? SKSpriteNode(texture: Art.shadow(width: 6)) : nil
        super.init()
        if let shadow {
            shadow.zPosition = -1
            addChild(shadow)
        }
        addChild(core)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(projectile: Projectile, layout: BoardLayout) {
        if kind == .bolt && core.texture !== Art.bolt(for: projectile.towerKind) {
            core.texture = Art.bolt(for: projectile.towerKind)
            core.size = core.texture?.size() ?? core.size
            core.usePixelAnchor()
        }
        position = layout.snappedWorldPoint(projectile.position)
        core.position.y = (CGFloat(projectile.height) * 16).rounded()
        if kind == .bolt && projectile.towerKind == .aegis {
            core.zRotation += 0.5
        } else if kind == .missile {
            let step = CGFloat.pi / 4
            core.zRotation = ((layout.worldAngle(of: projectile.heading) - .pi / 2) / step).rounded() * step
        }
    }
}
