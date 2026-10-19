import SpriteKit

/// Renders the engine's state as pixel art and turns touches into session commands.
///
/// The scene owns no game rules: each frame it asks the session to advance the
/// simulation, mirrors towers, enemies and projectiles into sprite nodes, and plays
/// effects for the events the engine reported.
@MainActor
final class GameScene: SKScene {
    weak var session: GameSession?
    let map: MapDefinition
    let paths: [PathGeometry]

    private(set) var layout: BoardLayout?

    /// Everything on the battlefield, measured in art pixels.
    let world = SKNode()
    let effectLayer = SKNode()
    let labelLayer = SKNode()
    private let boardSprite: SKSpriteNode
    private let decorLayer = SKNode()
    private let highlightLayer = SKNode()
    private let flowLayer = SKNode()
    private let towerLayer = SKNode()
    private let groundLayer = SKNode()
    private let airLayer = SKNode()
    private let projectileLayer = SKNode()
    private let rangeNode = SKSpriteNode()
    /// The Rook's row and column, shown instead of a range ring.
    private let lineNodes = [SKSpriteNode(color: .white, size: .zero), SKSpriteNode(color: .white, size: .zero)]
    private let selectionNode = SKSpriteNode(texture: Art.bracket)
    /// One crystal on a pedestal per route end, in `map.coreCells` order.
    private var coreCrystals: [SKSpriteNode] = []
    private var corePedestals: [SKSpriteNode] = []
    /// One portal per route start.
    private var portals: [(sprite: SKSpriteNode, path: PathGeometry)] = []
    private let leverNode = SKSpriteNode(texture: Art.lever(up: true))
    private let gateNode = SKSpriteNode(texture: Art.gate(shut: false))

    private var towerNodes: [Int: TowerNode] = [:]
    private var enemyNodes: [Int: EnemyNode] = [:]
    private var projectileNodes: [Int: ProjectileNode] = [:]
    private var highlightNodes: [GridPoint: SKSpriteNode] = [:]
    private var obstacleNodes: [GridPoint: SKSpriteNode] = [:]
    /// One hole per caved-in tile, in `engine.pits` order.
    private var pitNodes: [SKSpriteNode] = []
    /// Flow markers for each route.
    private var chevrons: [[SKSpriteNode]] = []
    private var ghost: TowerNode?
    private var commanderNode: SKNode?
    private let commanderBody = SKSpriteNode()
    private let commanderBadge = SKSpriteNode()
    private let commanderRing = SKSpriteNode()
    private let commanderGlow = SKSpriteNode(texture: Art.shadow(width: 18))
    private var commanderLevel = 0
    private var commanderRange: CGFloat = 0
    private var overlayState: OverlayState?

    private var lastUpdateTime: TimeInterval?
    private var flowOffset: CGFloat = 0
    private var lastNumberTime: TimeInterval = 0

    private var pinchStartScale: CGFloat = 1
    private var touchStartedOnPending = false
    private var touchMoved = false
    private var touchCell: GridPoint?

    private struct OverlayState: Equatable {
        var buildKind: TowerKind?
        var pendingCell: GridPoint?
        var pendingOK: Bool
        var selectedID: Int?
        var selectedRange: Double
        var towerCount: Int
        var pitCount: Int
        var layout: BoardLayout
    }

    init(map: MapDefinition, paths: [PathGeometry]) {
        self.map = map
        self.paths = paths
        boardSprite = SKSpriteNode(texture: Art.board(for: map))
        super.init(size: CGSize(width: 390, height: 390))
        scaleMode = .resizeFill
        backgroundColor = Pal.ink.uiColor
        setUpNodes()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setUpNodes() {
        addChild(world)
        let layers: [(SKNode, CGFloat)] = [
            (boardSprite, 0), (highlightLayer, 1), (flowLayer, 2), (decorLayer, 3), (rangeNode, 4),
            (selectionNode, 5), (towerLayer, 10), (groundLayer, 20), (airLayer, 30),
            (projectileLayer, 40), (effectLayer, 50), (labelLayer, 60),
        ]
        for (node, z) in layers {
            node.zPosition = z
            world.addChild(node)
        }
        rangeNode.isHidden = true
        for line in lineNodes {
            line.zPosition = 4
            line.alpha = 0.5
            line.isHidden = true
            world.addChild(line)
        }
        selectionNode.isHidden = true
        selectionNode.color = Pal.yellow.uiColor
        selectionNode.colorBlendFactor = 1
        selectionNode.run(.repeatForever(.sequence([
            .wait(forDuration: 0.35), .fadeAlpha(to: 0.4, duration: 0), .wait(forDuration: 0.35), .fadeAlpha(to: 1, duration: 0),
        ])))
        highlightLayer.isHidden = true
        highlightLayer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.85, duration: 0.5), .fadeAlpha(to: 0.35, duration: 0.5),
        ])))

        for _ in map.coreCells {
            let pedestal = SKSpriteNode(texture: Art.corePedestal)
            let crystal = SKSpriteNode(texture: Art.coreCrystal)
            pedestal.usePixelAnchor()
            crystal.usePixelAnchor()
            crystal.zPosition = 1
            pedestal.addChild(crystal)
            crystal.position = CGPoint(x: 0, y: 9)
            crystal.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 1, duration: 0), .wait(forDuration: 0.45),
                .moveBy(x: 0, y: -1, duration: 0), .wait(forDuration: 0.45),
            ])))
            decorLayer.addChild(pedestal)
            corePedestals.append(pedestal)
            coreCrystals.append(crystal)
        }

        for path in paths where !portals.contains(where: { $0.path.points[0] == path.points[0] }) {
            let portal = SKSpriteNode(texture: Art.portalFrames[0])
            portal.usePixelAnchor()
            portal.run(.repeatForever(.animate(with: Art.portalFrames, timePerFrame: 0.12)))
            decorLayer.addChild(portal)
            portals.append((portal, path))
        }

        leverNode.usePixelAnchor()
        gateNode.usePixelAnchor()
        if map.lever != nil { decorLayer.addChild(leverNode) }
        if map.gate != nil { decorLayer.addChild(gateNode) }

        for cell in map.obstacles {
            let variant = PixelNoise.value(cell.col, cell.row, seed: 3)
            let sprite = SKSpriteNode(texture: Art.obstacle(variant: variant, terrain: map.terrain))
            sprite.usePixelAnchor(bottom: true)
            decorLayer.addChild(sprite)
            obstacleNodes[cell] = sprite
        }

        for row in 0..<map.rows {
            for col in 0..<map.columns where map.isBuildable(GridPoint(col, row)) || map.water.contains(GridPoint(col, row))
                || map.pathCells.contains(GridPoint(col, row)) {
                let sprite = SKSpriteNode(texture: Art.bracket)
                sprite.colorBlendFactor = 1
                highlightLayer.addChild(sprite)
                highlightNodes[GridPoint(col, row)] = sprite
            }
        }

        chevrons = paths.map { path in
            (0..<max(1, Int(path.totalLength / 1.6))).map { _ in
                let chevron = SKSpriteNode(texture: Art.chevron)
                chevron.usePixelAnchor()
                chevron.alpha = 0.3
                chevron.color = Pal.sand.uiColor
                chevron.colorBlendFactor = 1
                flowLayer.addChild(chevron)
                return chevron
            }
        }
    }

    /// Adds nodes for towers that already exist when a saved match is resumed.
    func restoreTowers() {
        guard let engine = session?.engine else { return }
        for tower in engine.towers {
            let node = TowerNode(towerID: tower.id, kind: tower.kind, tiers: tower.tiers)
            towerLayer.addChild(node)
            towerNodes[tower.id] = node
        }
    }

    // MARK: Layout

    override func didMove(to view: SKView) {
        relayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
    }

    private func relayout() {
        guard size.width > 40, size.height > 40 else { return }
        let scale = view?.contentScaleFactor ?? 3
        let newLayout = BoardLayout(columns: map.columns, rows: map.rows, sceneSize: size, screenScale: scale)
        guard newLayout != layout else { return }
        layout = newLayout

        world.removeAction(forKey: "shake")
        world.setScale(newLayout.pixelSize)
        world.position = newLayout.origin
        let worldSize = newLayout.worldSize
        boardSprite.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        boardSprite.zRotation = newLayout.rotated ? -.pi / 2 : 0

        for (pedestal, cell) in zip(corePedestals, map.coreCells) {
            pedestal.position = newLayout.snappedWorldPoint(cell.center) + CGPoint(x: 0, y: -3)
        }
        for (portal, path) in portals {
            portal.position = newLayout.snappedWorldPoint(path.point(at: 1.0))
        }
        if let lever = map.lever { leverNode.position = newLayout.snappedWorldPoint(lever.center) }
        if let gate = map.gate { gateNode.position = newLayout.snappedWorldPoint(gate.center) }
        for (cell, sprite) in obstacleNodes {
            sprite.position = newLayout.snappedWorldPoint(cell.center) + CGPoint(x: 0, y: -7)
        }
        for (cell, sprite) in highlightNodes {
            sprite.position = newLayout.snappedWorldPoint(cell.center)
        }
        if let engine = session?.engine {
            for tower in engine.towers {
                towerNodes[tower.id]?.position = newLayout.snappedWorldPoint(tower.cell.center)
            }
            for (pit, cell) in zip(pitNodes, engine.pits) {
                pit.position = newLayout.snappedWorldPoint(cell.center)
            }
        }
        effectLayer.removeAllChildren()
        labelLayer.removeAllChildren()
        overlayState = nil
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard let session else { return }
        let realDelta = lastUpdateTime.map { min(max(currentTime - $0, 0), 0.1) } ?? 0
        lastUpdateTime = currentTime
        let events = session.tick(realDelta: realDelta)
        guard let layout else { return }

        let paused = session.isPaused
        let speed = CGFloat(session.speed.rawValue)
        let gameDelta = paused ? 0 : realDelta * Double(speed)
        effectLayer.speed = paused ? 0 : speed
        labelLayer.speed = paused ? 0 : speed
        decorLayer.speed = paused ? 0 : 1

        for event in events { handle(event, layout: layout, now: currentTime) }
        syncTowers(layout, dt: gameDelta)
        syncCommander(layout, now: currentTime)
        syncGate()
        syncPits(layout)
        syncEnemies(layout, dt: gameDelta)
        syncProjectiles(layout)
        updateOverlays(layout)
        animateFlow(layout, dt: gameDelta)
    }

    private func syncTowers(_ layout: BoardLayout, dt: Double) {
        guard let engine = session?.engine else { return }
        for tower in engine.towers {
            towerNodes[tower.id]?.update(tower: tower, aimAngle: layout.worldAngle(of: tower.aim), dt: dt)
        }
    }

    /// Mirrors the commander: a walk cycle while moving, its level and, when selected, its range.
    private func syncCommander(_ layout: BoardLayout, now: TimeInterval) {
        guard let session, let commander = session.engine.commander else { return }
        let frames = Art.commanderFrames(commander.kind, skin: commander.skin, level: commander.level)
        let node: SKNode
        if let commanderNode {
            node = commanderNode
        } else {
            node = SKNode()
            let shadow = SKSpriteNode(texture: Art.shadow(width: 12))
            shadow.position = CGPoint(x: 0, y: -10)
            // A pulsing glow under the commander once it reaches max level.
            commanderGlow.position = shadow.position
            commanderGlow.color = Pal.commander(commander.kind).uiColor
            commanderGlow.colorBlendFactor = 1
            commanderGlow.isHidden = true
            commanderGlow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6),
            ])))
            commanderBody.texture = frames[0]
            commanderBody.size = frames[0].size()
            commanderBody.usePixelAnchor()
            commanderBadge.position = CGPoint(x: 0, y: 14)
            commanderRing.zPosition = -2
            for child in [commanderRing, commanderGlow, shadow, commanderBody, commanderBadge] { node.addChild(child) }
            towerLayer.addChild(node)
            commanderNode = node
        }
        node.position = layout.snappedWorldPoint(commander.position) + CGPoint(x: 0, y: 2)
        node.zPosition = 1
        commanderBody.texture = commander.isWalking ? frames[Int(now * 6) % frames.count] : frames[0]
        commanderBody.xScale = layout.screenDX(of: commander.aim) < 0 ? -1 : 1
        if commanderLevel != commander.level {
            commanderLevel = commander.level
            let badge = Art.text("\(commander.level)", color: Pal.yellow)
            commanderBadge.texture = badge
            commanderBadge.size = badge.size()
            commanderGlow.isHidden = commander.level < CommanderKind.maxLevel
        }
        if commanderRange != commander.range {
            commanderRange = commander.range
            let ring = Art.rangeRing(range: Double(commander.range), color: Pal.commander(commander.kind))
            commanderRing.texture = ring
            commanderRing.size = ring.size()
        }
        commanderRing.isHidden = !session.isCommanderSelected
    }

    /// Pulls the lever and bars the gate while the commander holds it, and darkens the shut road's arrows.
    private func syncGate() {
        guard let engine = session?.engine, map.lever != nil else { return }
        let shut = engine.isGateShut
        leverNode.texture = Art.lever(up: !shut)
        gateNode.texture = Art.gate(shut: shut)
        for chevron in chevrons[1] { chevron.alpha = shut ? 0.08 : 0.3 }
    }

    /// Adds a hole for each tile the Sinkmaw caved in, including those of a resumed match.
    private func syncPits(_ layout: BoardLayout) {
        guard let engine = session?.engine else { return }
        while pitNodes.count < engine.pits.count {
            let pit = SKSpriteNode(texture: Art.pit)
            pit.usePixelAnchor()
            pit.position = layout.snappedWorldPoint(engine.pits[pitNodes.count].center)
            decorLayer.addChild(pit)
            pitNodes.append(pit)
        }
    }

    private func syncEnemies(_ layout: BoardLayout, dt: Double) {
        guard let engine = session?.engine else { return }
        var alive = Set<Int>()
        for enemy in engine.enemies {
            alive.insert(enemy.id)
            let node: EnemyNode
            if let existing = enemyNodes[enemy.id] {
                node = existing
            } else {
                node = EnemyNode(enemyID: enemy.id, kind: enemy.kind)
                node.alpha = 0
                node.run(.fadeIn(withDuration: 0.2))
                (enemy.kind.isFlying ? airLayer : groundLayer).addChild(node)
                enemyNodes[enemy.id] = node
            }
            node.update(enemy: enemy, layout: layout, dt: dt)
        }
        for (id, node) in enemyNodes where !alive.contains(id) {
            node.removeFromParent()
            enemyNodes[id] = nil
        }
    }

    private func syncProjectiles(_ layout: BoardLayout) {
        guard let engine = session?.engine else { return }
        var alive = Set<Int>()
        for projectile in engine.projectiles {
            alive.insert(projectile.id)
            let node: ProjectileNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                node = ProjectileNode(kind: projectile.kind)
                projectileLayer.addChild(node)
                projectileNodes[projectile.id] = node
            }
            node.update(projectile: projectile, layout: layout)
        }
        for (id, node) in projectileNodes where !alive.contains(id) {
            node.removeFromParent()
            projectileNodes[id] = nil
        }
    }

    private func animateFlow(_ layout: BoardLayout, dt: Double) {
        let spacing: CGFloat = 1.6
        flowOffset += CGFloat(dt) * 0.7
        for (path, markers) in zip(paths, chevrons) {
            let loop = CGFloat(markers.count) * spacing
            for (i, chevron) in markers.enumerated() {
                let distance = (CGFloat(i) * spacing + flowOffset).truncatingRemainder(dividingBy: loop)
                guard distance > 1.4, distance < path.totalLength - 0.9 else {
                    chevron.isHidden = true
                    continue
                }
                chevron.isHidden = false
                chevron.position = layout.snappedWorldPoint(path.point(at: distance))
                chevron.zRotation = layout.worldAngle(of: path.direction(at: distance)) - .pi / 2
            }
        }
    }

    // MARK: Selection, ghost and range overlays

    private func updateOverlays(_ layout: BoardLayout) {
        guard let session else { return }
        let selected = session.selectedTower
        let state = OverlayState(
            buildKind: session.buildKind,
            pendingCell: session.pendingCell,
            pendingOK: session.pendingResult == .ok,
            selectedID: selected?.id,
            selectedRange: selected?.stats.range ?? 0,
            towerCount: session.engine.towers.count,
            pitCount: session.engine.pits.count,
            layout: layout
        )
        guard state != overlayState else { return }
        overlayState = state

        highlightLayer.isHidden = state.buildKind == nil
        if let kind = state.buildKind {
            for (cell, sprite) in highlightNodes {
                sprite.isHidden = session.engine.tower(at: cell) != nil || cell == state.pendingCell
                    || map.water.contains(cell) != kind.isNaval || map.pathCells.contains(cell) != kind.holdsPath
                    || session.engine.isRouteEnd(cell) || session.engine.isPit(cell)
                sprite.color = Pal.towerLight(kind).uiColor
            }
        }

        ghost?.removeFromParent()
        ghost = nil
        rangeNode.isHidden = true
        for line in lineNodes { line.isHidden = true }
        selectionNode.isHidden = true

        if let kind = state.buildKind, let cell = state.pendingCell {
            let node = TowerNode(towerID: -1, kind: kind)
            node.position = layout.snappedWorldPoint(cell.center)
            node.zPosition = 45
            node.alpha = state.pendingOK ? 0.8 : 0.55
            node.tint(state.pendingOK ? nil : Pal.red)
            world.addChild(node)
            ghost = node
            let range = kind.baseStats.range + (map.highGround.contains(cell) ? 0.5 : 0)
            showRange(range, of: kind, color: state.pendingOK ? Pal.white : Pal.red, at: cell, layout: layout)
        } else if let selected, let tower = session.engine.tower(id: selected.id) {
            showRange(selected.stats.range, of: selected.kind, color: Pal.towerLight(selected.kind), at: tower.cell, layout: layout)
            selectionNode.position = layout.snappedWorldPoint(tower.cell.center)
            selectionNode.isHidden = false
        }
    }

    private func showRange(_ range: Double, of kind: TowerKind, color: PixelColor, at cell: GridPoint, layout: BoardLayout) {
        if kind.attackStyle == .cross {
            let center = cell.center
            let ends = [(CGPoint(x: 0, y: center.y), CGPoint(x: CGFloat(map.columns), y: center.y)),
                        (CGPoint(x: center.x, y: 0), CGPoint(x: center.x, y: CGFloat(map.rows)))]
            for (line, (start, end)) in zip(lineNodes, ends) {
                let a = layout.snappedWorldPoint(start), b = layout.snappedWorldPoint(end)
                line.color = color.uiColor
                line.size = CGSize(width: max(2, abs(b.x - a.x)), height: max(2, abs(b.y - a.y)))
                line.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                line.isHidden = false
            }
            return
        }
        let texture = Art.rangeRing(range: range, color: color)
        rangeNode.texture = texture
        rangeNode.size = texture.size()
        rangeNode.position = layout.snappedWorldPoint(cell.center)
        rangeNode.isHidden = false
    }

    // MARK: Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // A second finger means a pinch or pan, not a tap.
        guard event?.allTouches?.count ?? 1 == 1 else {
            touchMoved = true
            return
        }
        guard let touch = touches.first, let session, let layout else { return }
        let cell = layout.cell(atWorld: touch.location(in: world))
        touchCell = cell
        touchMoved = false
        touchStartedOnPending = false
        if session.buildKind != nil {
            touchStartedOnPending = cell != nil && cell == session.pendingCell
            if !touchStartedOnPending { session.previewPlacement(at: cell) }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard event?.allTouches?.count ?? 1 == 1, let touch = touches.first, let session, let layout else { return }
        let cell = layout.cell(atWorld: touch.location(in: world))
        guard cell != touchCell else { return }
        touchCell = cell
        touchMoved = true
        if session.buildKind != nil { session.previewPlacement(at: cell) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session else { return }
        if session.buildKind != nil {
            if touchStartedOnPending && !touchMoved { session.confirmBuild() }
        } else if !touchMoved {
            session.tapCell(touchCell)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchMoved = true
    }

    // MARK: Zoom and pan

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view else { return }
        if gesture.state == .began { pinchStartScale = world.xScale }
        zoom(to: pinchStartScale * gesture.scale, around: convertPoint(fromView: gesture.location(in: view)))
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let translation = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        world.removeAction(forKey: "shake")
        world.position = world.position + CGPoint(x: translation.x, y: -translation.y)
        clampWorld()
    }

    @objc func resetZoom() {
        guard let layout else { return }
        zoom(to: layout.pixelSize, around: .zero)
    }

    /// Zooms between the fitted size and 3x, keeping `anchor` (scene coordinates) still.
    /// The scale snaps to whole device pixels per art pixel so the art stays crisp.
    private func zoom(to scale: CGFloat, around anchor: CGPoint) {
        guard let layout else { return }
        let screenScale = view?.contentScaleFactor ?? 3
        let snapped = (min(max(scale, layout.pixelSize), layout.pixelSize * 3) * screenScale).rounded() / screenScale
        let focus = world.convert(anchor, from: self)
        world.removeAction(forKey: "shake")
        world.setScale(snapped)
        world.position = anchor - focus * snapped
        clampWorld()
    }

    /// Keeps a zoomed board covering the view, or centered along an axis where it fits.
    private func clampWorld() {
        guard let layout else { return }
        let screenScale = view?.contentScaleFactor ?? 3
        func clamp(_ value: CGFloat, board: CGFloat, view: CGFloat) -> CGFloat {
            let position = board <= view ? (view - board) / 2 : min(0, max(view - board, value))
            return (position * screenScale).rounded() / screenScale
        }
        world.position = CGPoint(
            x: clamp(world.position.x, board: layout.worldSize.width * world.xScale, view: size.width),
            y: clamp(world.position.y, board: layout.worldSize.height * world.yScale, view: size.height)
        )
    }

    // MARK: Event handling

    private func handle(_ event: GameEvent, layout: BoardLayout, now: TimeInterval) {
        func toWorld(_ p: CGPoint) -> CGPoint { layout.snappedWorldPoint(p) }

        switch event {
        case let .towerBuilt(id, kind, cell):
            let node = TowerNode(towerID: id, kind: kind)
            let target = toWorld(cell.center)
            node.position = target + CGPoint(x: 0, y: 6)
            towerLayer.addChild(node)
            towerNodes[id] = node
            node.run(.sequence([
                .move(to: target + CGPoint(x: 0, y: 3), duration: 0.05),
                .move(to: target, duration: 0.05),
            ]))
            playFrames(Art.dustFrames, at: target + CGPoint(x: 0, y: -6), timePerFrame: 0.07)
            SoundEngine.shared.play(.build)
            Haptics.impact(.light)

        case let .towerUpgraded(id, _, _):
            guard let node = towerNodes[id], let tower = session?.engine.tower(id: id) else { break }
            node.setTiers(tower.tiers)
            let target = toWorld(tower.cell.center)
            node.removeAction(forKey: "hop")
            node.position = target
            node.run(.sequence([
                .move(to: target + CGPoint(x: 0, y: 3), duration: 0.06),
                .move(to: target, duration: 0.06),
            ]), withKey: "hop")
            playFrames(Art.ringFrames(radius: 14, color: Pal.tower(tower.kind), accent: Pal.towerLight(tower.kind)),
                       at: target, timePerFrame: 0.05, z: -2)
            playFrames(Art.sparkleFrames, at: target, timePerFrame: 0.08)
            SoundEngine.shared.play(.upgrade)
            Haptics.impact(.medium)

        case let .towerIncome(_, at, amount):
            floatText("+\(amount)", color: Pal.yellow, at: toWorld(at) + CGPoint(x: 0, y: 8))
            playFrames(Art.sparkleFrames, at: toWorld(at), timePerFrame: 0.08)
            SoundEngine.shared.play(.sell)

        case let .comboFormed(name, first, second):
            playFrames(Art.sparkleFrames, at: toWorld(first), timePerFrame: 0.08)
            playFrames(Art.sparkleFrames, at: toWorld(second), timePerFrame: 0.08)
            floatText(name.uppercased(), color: Pal.yellow, at: toWorld(first.lerp(to: second, 0.5)) + CGPoint(x: 0, y: 14))

        case let .towerSold(id, cell, refund):
            towerNodes[id]?.removeFromParent()
            towerNodes[id] = nil
            playFrames(Art.dustFrames, at: toWorld(cell.center) + CGPoint(x: 0, y: -6), timePerFrame: 0.07)
            floatText("+\(refund)", color: Pal.yellow, at: toWorld(cell.center))
            SoundEngine.shared.play(.sell)

        case let .shotFired(towerID, kind):
            if let node = towerNodes[towerID] {
                switch kind.attackStyle {
                case .bolt, .lob:
                    if kind.rotates { playFrames([Art.muzzleFlash], at: node.position + node.muzzleOffset, timePerFrame: 0.05) }
                    else { node.flash() }
                case .chain, .mind, .aura:
                    node.flash()
                default:
                    break
                }
            }
            switch kind {
            case .pulse, .aegis, .weaver, .tide, .tamer, .bramble, .warden: SoundEngine.shared.play(.pulse)
            case .cyclone: SoundEngine.shared.play(.gust)
            case .mortar, .alchemist: SoundEngine.shared.play(.mortar)
            case .tesla: SoundEngine.shared.play(.tesla)
            case .rail, .star, .sniper, .rook: SoundEngine.shared.play(.rail)
            case .inferno: SoundEngine.shared.play(.flame)
            case .echo, .siren: SoundEngine.shared.play(.scream)
            case .mind, .omen: SoundEngine.shared.play(.psychic)
            case .frost: SoundEngine.shared.play(.frost)
            case .chrono, .midas: SoundEngine.shared.play(.tick)
            }

        case let .auraPulse(towerID, center, radius):
            let kind = session?.engine.tower(id: towerID)?.kind ?? .frost
            let frames = kind == .frost
                ? Art.frostFrames(radius: Int(radius * 16))
                : Art.ringFrames(radius: Int(radius * 16), color: Pal.amber, accent: Pal.yellow)
            playFrames(frames, at: toWorld(center), timePerFrame: 0.06, z: -2)

        case let .coneBlast(towerID, origin, direction, range, angle):
            let kind = session?.engine.tower(id: towerID)?.kind ?? .inferno
            let colors: [PixelColor] = switch kind {
            case .inferno: [Pal.yellow, Pal.orange, Pal.red]
            case .siren: [Pal.white, Pal.cyan, Pal.blue]
            default: [Pal.white, Pal.lime, Pal.green]
            }
            cone(at: toWorld(origin), angle: layout.worldAngle(of: direction), spread: angle, length: range * 16, colors: colors)

        case let .mindBlast(from, to):
            let (texture, origin) = Art.beam(from: toWorld(from), to: toWorld(to), glow: Pal.pink, edge: Pal.magenta)
            flicker(texture, origin: origin)

        case let .immune(at):
            floatText("IMMUNE", color: Pal.silver, at: toWorld(at) + CGPoint(x: 0, y: 10))

        case let .chainLightning(points):
            let (texture, origin) = Art.lightning(through: points.map(toWorld))
            flicker(texture, origin: origin)

        case let .beam(towerID, from, to):
            let kind = session?.engine.tower(id: towerID)?.kind ?? .rail
            let colors: [PixelColor] = switch kind {
            case .star: [Pal.yellow, Pal.amber]
            case .rook: [Pal.amber, Pal.yellow]
            default: [Pal.pink, Pal.hotRed]
            }
            let (texture, origin) = Art.beam(from: toWorld(from), to: toWorld(to), glow: colors[0], edge: colors[1])
            let sprite = SKSpriteNode(texture: texture)
            sprite.anchorPoint = .zero
            sprite.position = origin
            effectLayer.addChild(sprite)
            sprite.run(.sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.16), .removeFromParent()]))

        case let .shellImpact(center, radius):
            playFrames(Art.explosionFrames(radius: Int(radius * 16)), at: toWorld(center), timePerFrame: 0.055)
            sparks(at: toWorld(center), color: Pal.orange, count: 10)
            SoundEngine.shared.play(.explosion)

        case .boltImpact:
            break

        case let .missileImpact(center, radius):
            playFrames(Art.explosionFrames(radius: max(6, Int(radius * 16))), at: toWorld(center), timePerFrame: 0.045)
            SoundEngine.shared.play(.missile)

        case let .powerActivated(towerID, _, name):
            if let node = towerNodes[towerID] {
                floatText(name.uppercased() + "!", color: Pal.yellow, at: node.position + CGPoint(x: 0, y: 14))
            }
            SoundEngine.shared.play(.power)

        case let .powerBurst(towerID, center, radius):
            let kind = session?.engine.tower(id: towerID)?.kind ?? .pulse
            playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.tower(kind), accent: Pal.towerLight(kind)),
                       at: toWorld(center), timePerFrame: 0.06, z: -2)
            sparks(at: toWorld(center), color: Pal.towerLight(kind), count: 24)
            shake(intensity: kind == .mortar ? 3 : 2)
            SoundEngine.shared.play(kind == .frost ? .frost : .explosion)

        case let .powerStrikes(points, splash):
            for point in points.prefix(16) {
                let target = toWorld(point)
                let (texture, origin) = Art.lightning(through: [target + CGPoint(x: 6, y: 80), target + CGPoint(x: -4, y: 40), target])
                flicker(texture, origin: origin)
                playFrames(Art.explosionFrames(radius: max(8, Int(splash * 16))), at: target, timePerFrame: 0.05)
            }
            shake(intensity: 2)
            SoundEngine.shared.play(.tesla)

        case let .frenzyStarted(towerID):
            if let node = towerNodes[towerID] {
                playFrames(Art.sparkleFrames, at: node.position, timePerFrame: 0.08)
            }

        case let .fieldStarted(center, radius, duration, type):
            field(at: toWorld(center), radius: radius * 16, duration: duration, type: type)

        case let .timeStop(duration):
            timeStopOverlay(duration: duration)
            SoundEngine.shared.play(.timeStop)

        case let .rally(towerID, radius):
            if let node = towerNodes[towerID] {
                playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.amber, accent: Pal.yellow), at: node.position, timePerFrame: 0.06, z: -2)
            }

        case let .strip(center, radius):
            playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.lime, accent: Pal.white), at: toWorld(center), timePerFrame: 0.05, z: -2)
            shake(intensity: 2)

        case let .confuseWave(center, radius):
            playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.magenta, accent: Pal.pink), at: toWorld(center), timePerFrame: 0.07, z: -2)

        case let .enemyTeleported(from, to):
            playFrames(Art.poofFrames(color: Pal.cyan), at: toWorld(from), timePerFrame: 0.05)
            playFrames(Art.poofFrames(color: Pal.cyan), at: toWorld(to), timePerFrame: 0.05)
            SoundEngine.shared.play(.warp)

        case let .enemyPetrified(at):
            playFrames(Art.dustFrames, at: toWorld(at), timePerFrame: 0.07)

        case let .enemyShielded(center, radius):
            playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.magenta, accent: Pal.pink), at: toWorld(center), timePerFrame: 0.05, z: -2)
            SoundEngine.shared.play(.shield)

        case let .towersDisrupted(center, radius):
            playFrames(Art.ringFrames(radius: Int(radius * 16), color: Pal.purple, accent: Pal.lime), at: toWorld(center), timePerFrame: 0.06, z: -2)
            shake(intensity: 2)
            SoundEngine.shared.play(.emp)
            Haptics.impact(.medium)

        case let .groundCollapsed(cell):
            playFrames(Art.dustFrames, at: toWorld(cell.center), timePerFrame: 0.07)
            shake(intensity: 2)
            SoundEngine.shared.play(.mortar)

        case let .heavyHit(at, amount):
            // Damage numbers are capped so busy waves stay readable.
            guard now - lastNumberTime > 0.12 else { break }
            lastNumberTime = now
            floatText("\(amount)", color: Pal.white, at: toWorld(at) + CGPoint(x: 0, y: 6))

        case let .enemyKilled(_, kind, at, bounty):
            let point = toWorld(at)
            if kind.isBoss {
                playFrames(Art.explosionFrames(radius: 26), at: point, timePerFrame: 0.07)
                sparks(at: point, color: Pal.hotRed, count: 30)
                shake(intensity: 3)
                SoundEngine.shared.play(.bossDown)
                Haptics.notify(.success)
            } else {
                playFrames(Art.poofFrames(color: Pal.enemy(kind)), at: point, timePerFrame: 0.06)
                SoundEngine.shared.play(.pop)
            }
            floatText("+\(bounty)", color: Pal.yellow, at: point + CGPoint(x: 0, y: 8))

        case let .enemyLeaked(_, _, livesLost):
            // Pickpockets cost no lives; their stolen gold shows instead.
            guard livesLost > 0 else { break }
            // The crystals share one pool of lives, so they all flash.
            for crystal in coreCrystals {
                crystal.removeAction(forKey: "hit")
                crystal.run(.sequence([
                    .run { [weak crystal] in crystal?.color = Pal.red.uiColor; crystal?.colorBlendFactor = 0.8 },
                    .wait(forDuration: 0.1),
                    .run { [weak crystal] in crystal?.colorBlendFactor = 0 },
                    .wait(forDuration: 0.08),
                    .run { [weak crystal] in crystal?.colorBlendFactor = 0.8 },
                    .wait(forDuration: 0.1),
                    .run { [weak crystal] in crystal?.colorBlendFactor = 0 },
                ]), withKey: "hit")
            }
            floatText("-\(livesLost)", color: Pal.red, at: corePedestals[0].position + CGPoint(x: 0, y: 22))
            shake(intensity: 2)
            SoundEngine.shared.play(.leak)
            Haptics.impact(.heavy)

        case let .goldStolen(amount):
            floatText("-\(amount)", color: Pal.red, at: corePedestals[0].position + CGPoint(x: 0, y: 22))
            SoundEngine.shared.play(.leak)

        case let .enemyHealed(center, _):
            let point = toWorld(center)
            for offset in [CGPoint(x: -6, y: 4), CGPoint(x: 5, y: 7), CGPoint(x: 0, y: 12)] {
                let plus = SKSpriteNode(texture: Art.healPlus)
                plus.usePixelAnchor()
                plus.position = point + offset
                labelLayer.addChild(plus)
                plus.run(.sequence([
                    .moveBy(x: 0, y: 3, duration: 0.15), .moveBy(x: 0, y: 3, duration: 0.15),
                    .moveBy(x: 0, y: 3, duration: 0.15), .removeFromParent(),
                ]))
            }
            SoundEngine.shared.play(.heal)

        case let .enemySplit(at):
            sparks(at: toWorld(at), color: Pal.cyan, count: 8)
            SoundEngine.shared.play(.split)

        case let .bossSummon(at):
            playFrames(Art.poofFrames(color: Pal.magenta), at: toWorld(at), timePerFrame: 0.07)

        case let .waveStarted(_, isBoss, _):
            SoundEngine.shared.play(isBoss ? .bossWarning : .waveStart)

        case let .waveCleared(_, bonus):
            floatText("+\(bonus)", color: Pal.yellow, at: corePedestals[0].position + CGPoint(x: 0, y: 22))
            SoundEngine.shared.play(.waveClear)

        case let .earlyCallBonus(amount):
            floatText("+\(amount)", color: Pal.yellow, at: portals[0].sprite.position + CGPoint(x: 0, y: 10))
            SoundEngine.shared.play(.coin)

        case let .commanderAttack(kind, from, to):
            switch kind {
            case .knight:
                sparks(at: toWorld(to), color: Pal.mist, count: 6)
                SoundEngine.shared.play(.pulse)
            case .mage:
                playFrames(Art.explosionFrames(radius: 12), at: toWorld(to), timePerFrame: 0.05)
                SoundEngine.shared.play(.flame)
            case .ranger, .engineer, .healer:
                let (texture, origin) = Art.beam(from: toWorld(from), to: toWorld(to), glow: Pal.commander(kind), edge: Pal.ink)
                flicker(texture, origin: origin)
                SoundEngine.shared.play(.pulse)
            }

        case let .commanderSkill(kind, _, center, radius):
            let color = Pal.commander(kind)
            playFrames(Art.ringFrames(radius: max(8, Int(radius * 16)), color: color, accent: Pal.white),
                       at: toWorld(center), timePerFrame: 0.06, z: -2)
            sparks(at: toWorld(center), color: color, count: 20)
            shake(intensity: 2)
            SoundEngine.shared.play(.explosion)

        case let .commanderLevelUp(level, at):
            playFrames(Art.sparkleFrames, at: toWorld(at), timePerFrame: 0.08)
            if Art.commanderStage(level: level) != Art.commanderStage(level: level - 1), let kind = session?.engine.commander?.kind {
                // New gear: a white flash and a burst in the commander's color.
                playFrames(Art.ringFrames(radius: 16, color: Pal.commander(kind), accent: Pal.white),
                           at: toWorld(at), timePerFrame: 0.05, z: -2)
                sparks(at: toWorld(at), color: Pal.commander(kind), count: 16)
                commanderBody.run(.sequence([
                    .run { [weak commanderBody] in commanderBody?.color = .white; commanderBody?.colorBlendFactor = 1 },
                    .wait(forDuration: 0.15),
                    .run { [weak commanderBody] in commanderBody?.colorBlendFactor = 0 },
                ]))
            }
            floatText("LEVEL \(level)", color: Pal.yellow, at: toWorld(at) + CGPoint(x: 0, y: 14))
            SoundEngine.shared.play(.upgrade)

        case let .commanderEvolved(name, at):
            guard let kind = session?.engine.commander?.kind else { break }
            playFrames(Art.ringFrames(radius: 16, color: Pal.commander(kind), accent: Pal.white),
                       at: toWorld(at), timePerFrame: 0.05, z: -2)
            sparks(at: toWorld(at), color: Pal.commander(kind), count: 16)
            floatText(name.uppercased(), color: Pal.yellow, at: toWorld(at) + CGPoint(x: 0, y: 14))
            SoundEngine.shared.play(.upgrade)
            Haptics.impact(.medium)

        case .victory:
            SoundEngine.shared.play(.victory)
            Haptics.notify(.success)

        case .defeat:
            SoundEngine.shared.play(.defeat)
            Haptics.notify(.error)
        }
    }
}

extension GameScene: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
