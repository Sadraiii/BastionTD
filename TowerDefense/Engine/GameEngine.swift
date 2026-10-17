import CoreGraphics
import Foundation

struct GameStats: Equatable {
    var enemiesDefeated = 0
    var kills: [EnemyKind: Int] = [:]
    var goldEarned = 0
    var towersBuilt = 0
    var livesLost = 0
    var powersUsed = 0
    var damageDealt: Double = 0
}

enum PlacementResult: Equatable {
    case ok, outOfBounds, onPath, blocked, occupied, insufficientGold, locked

    var message: String {
        switch self {
        case .ok: "Ready to build"
        case .outOfBounds: "Outside the battlefield"
        case .onPath: "Can't build on the path"
        case .blocked: "That tile is blocked"
        case .occupied: "A hero is already there"
        case .insufficientGold: "Not enough gold"
        case .locked: "Recruit this hero in the Research Lab"
        }
    }
}

/// Whether the next tier on an upgrade path can be bought right now.
enum UpgradeStatus: Equatable {
    case available(cost: Int)
    case unaffordable(cost: Int)
    /// Not yet unlocked in the Research Lab.
    case needsResearch(points: Int)
    /// The other path is past the cross-path cap.
    case blocked
    case maxed
}

/// Small deterministic RNG so simulations are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The pure game simulation: economy, waves, villains, heroes, powers and projectiles.
///
/// It has no rendering or UIKit dependencies. Everything is measured in tiles and
/// seconds; call `step(_:)` with a fixed timestep and read `drainEvents()` afterwards.
final class GameEngine {
    enum Phase: Equatable {
        case preparing, intermission, waveActive, victory, defeat

        var isOver: Bool { self == .victory || self == .defeat }
    }

    static let intermissionDuration: Double = 12
    static let spawnDistance: CGFloat = 0.5
    static let sellRefundRate: Double = 0.7
    static let earlyCallGoldPerSecond: Double = 2
    static let mortarFlightTime: Double = 0.8
    static let chainJumpRange: CGFloat = 1.7
    static let chainFalloff: Double = 0.85
    static let ricochetRange: CGFloat = 1.6
    static let missileSpeed: Double = 7
    static let missileSplash: Double = 0.45
    static let weaknessMultiplier: Double = 2

    let map: MapDefinition
    /// One geometry per route; the first is the main path.
    let paths: [PathGeometry]
    var path: PathGeometry { paths[0] }
    let waves: [WaveDefinition]
    let research: ResearchState

    private(set) var towers: [Tower] = []
    private(set) var enemies: [Enemy] = []
    private(set) var projectiles: [Projectile] = []
    private(set) var fields: [PowerField] = []
    private(set) var gold: Int
    private(set) var lives: Int
    private(set) var phase: Phase = .preparing
    private(set) var waveNumber = 0
    /// After winning, play continues with procedurally generated waves.
    private(set) var isEndless = false
    private(set) var intermissionRemaining: Double = 0
    private(set) var stats = GameStats()
    private(set) var waveEnemyTotal = 0
    private(set) var waveEnemiesResolved = 0
    private(set) var time: Double = 0

    private struct ScheduledSpawn {
        let time: Double
        let kind: EnemyKind
    }

    private var events: [GameEvent] = []
    private var spawnQueue: [ScheduledSpawn] = []
    private var incoming: [Enemy] = []
    private var waveClock: Double = 0
    private var nextID = 1
    private var nextRoute = 0
    private var rng: SplitMix64
    private var towersByCell: [GridPoint: Tower] = [:]
    private var enemiesByID: [Int: Enemy] = [:]
    private var lastImmuneEvent: Double = -1

    init(map: MapDefinition, waves: [WaveDefinition] = WaveLibrary.standard,
         research: ResearchState = ResearchState(), seed: UInt64 = 0x5EED) {
        self.map = map
        self.paths = map.routes.map { PathGeometry(waypoints: $0) }
        self.waves = waves
        self.research = research
        self.gold = map.startingGold
        self.lives = map.startingLives
        self.rng = SplitMix64(seed: seed)
    }

    // MARK: - Queries

    var totalWaves: Int { waves.count }

    var canStartWave: Bool { (phase == .preparing || phase == .intermission) && (isEndless || waveNumber < waves.count) }

    /// Waves survived so far (the current wave counts once it is cleared).
    var wavesCleared: Int { phase == .waveActive || phase == .defeat ? waveNumber - 1 : waveNumber }

    func waveDefinition(number: Int) -> WaveDefinition {
        number <= waves.count ? waves[number - 1] : WaveLibrary.endlessWave(number: number)
    }

    /// Gold awarded for calling the next wave before the countdown ends.
    var earlyCallBonus: Int {
        phase == .intermission ? max(0, Int(intermissionRemaining * Self.earlyCallGoldPerSecond)) : 0
    }

    var waveProgress: Double {
        waveEnemyTotal == 0 ? 0 : Double(waveEnemiesResolved) / Double(waveEnemyTotal)
    }

    var enemiesRemaining: Int { max(0, waveEnemyTotal - waveEnemiesResolved) }

    func tower(at cell: GridPoint) -> Tower? { towersByCell[cell] }

    func tower(id: Int) -> Tower? { towers.first { $0.id == id } }

    func enemy(id: Int) -> Enemy? { enemiesByID[id] }

    func drainEvents() -> [GameEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func placementCheck(_ kind: TowerKind, at cell: GridPoint) -> PlacementResult {
        guard research.isHeroUnlocked(kind) else { return .locked }
        guard map.contains(cell) else { return .outOfBounds }
        if map.pathCells.contains(cell) { return .onPath }
        if map.obstacles.contains(cell) { return .blocked }
        if towersByCell[cell] != nil { return .occupied }
        if gold < kind.cost { return .insufficientGold }
        return .ok
    }

    func upgradeStatus(towerID: Int, path: Int) -> UpgradeStatus {
        guard let tower = tower(id: towerID), let next = tower.nextTier(onPath: path) else { return .maxed }
        if UpgradeRules.isBlockedByOtherPath(tower.tiers, path: path) { return .blocked }
        let tier = tower.tiers[path] + 1
        if !research.isUnlocked(tower.kind, path: path, tier: tier) { return .needsResearch(points: next.research) }
        return gold >= next.cost ? .available(cost: next.cost) : .unaffordable(cost: next.cost)
    }

    /// Whether a power would hit anything right now (buffs, fields and time stop always work).
    func powerHasTargets(towerID: Int) -> Bool {
        guard let tower = tower(id: towerID), let power = tower.power else { return false }
        let range = tower.stats.range
        let reach: Double
        switch power.effect {
        case .frenzy, .field, .rally: return true
        case .timeStop: return enemies.contains { $0.isTargetable }
        case let .burst(_, _, _, scale, _): reach = range * scale
        case let .strikes(_, _, _, _, scale): reach = range * scale
        case let .strip(_, scale): reach = range * scale
        case let .confuse(_, _, scale): reach = range * scale
        case .missiles: reach = range * 1.5
        }
        return enemies.contains { $0.isTargetable && $0.position.distance(to: tower.position) <= CGFloat(reach) }
    }

    // MARK: - Player commands

    @discardableResult
    func build(_ kind: TowerKind, at cell: GridPoint) -> Tower? {
        guard !phase.isOver, placementCheck(kind, at: cell) == .ok else { return nil }
        gold -= kind.cost
        let tower = Tower(id: makeID(), kind: kind, cell: cell)
        towers.append(tower)
        towersByCell[cell] = tower
        stats.towersBuilt += 1
        events.append(.towerBuilt(towerID: tower.id, kind: kind, cell: cell))
        return tower
    }

    @discardableResult
    func upgrade(towerID: Int, path: Int) -> Bool {
        guard !phase.isOver, let tower = tower(id: towerID),
              case let .available(cost) = upgradeStatus(towerID: towerID, path: path) else { return false }
        gold -= cost
        tower.totalInvested += cost
        tower.advance(path: path)
        events.append(.towerUpgraded(towerID: tower.id, path: path, tier: tower.tiers[path]))
        return true
    }

    @discardableResult
    func sell(towerID: Int) -> Int? {
        guard !phase.isOver, let index = towers.firstIndex(where: { $0.id == towerID }) else { return nil }
        let tower = towers.remove(at: index)
        towersByCell[tower.cell] = nil
        let refund = tower.sellValue
        gold += refund
        events.append(.towerSold(towerID: tower.id, cell: tower.cell, refund: refund))
        return refund
    }

    func setTargeting(_ mode: TargetingMode, towerID: Int) {
        tower(id: towerID)?.targeting = mode
    }

    @discardableResult
    func startNextWave() -> Bool {
        guard canStartWave else { return false }
        let bonus = earlyCallBonus
        if bonus > 0 {
            earn(bonus)
            events.append(.earlyCallBonus(amount: bonus))
        }
        beginWave()
        return true
    }

    /// Keeps playing after victory with ever-harder procedural waves.
    func continueEndless() {
        guard phase == .victory else { return }
        isEndless = true
        phase = .intermission
        intermissionRemaining = Self.intermissionDuration
    }

    /// Triggers the tower's hero power. Returns false if it isn't ready or would hit nothing.
    @discardableResult
    func activatePower(towerID: Int) -> Bool {
        guard !phase.isOver, let tower = tower(id: towerID), let power = tower.power, tower.isPowerReady,
              powerHasTargets(towerID: towerID) else { return false }
        tower.powerCooldown = power.cooldown
        stats.powersUsed += 1
        let range = CGFloat(tower.stats.range)
        let type = tower.stats.damageType
        func inReach(_ scale: Double) -> [Enemy] {
            enemies.filter { $0.isTargetable && $0.position.distance(to: tower.position) <= range * CGFloat(scale) }
        }

        switch power.effect {
        case let .burst(damage, stun, knockback, scale, groundOnly):
            for enemy in inReach(scale) where !(groundOnly && enemy.kind.isFlying) {
                apply(HitPayload(damage: damage, type: type, piercesArmor: true, stunChance: stun > 0 ? 1 : 0, stunDuration: stun,
                                 bossMultiplier: tower.stats.bossMultiplier, knockback: knockback),
                      to: enemy, from: tower, showNumber: false)
            }
            events.append(.powerBurst(towerID: tower.id, center: tower.position, radius: range * CGFloat(scale)))

        case let .frenzy(duration, rate, damage):
            tower.frenzyTimer = duration
            tower.frenzyRate = rate
            tower.frenzyDamage = damage
            events.append(.frenzyStarted(towerID: tower.id))

        case let .strikes(count, damage, stun, splash, scale):
            let targets = inReach(scale).sorted { $0.health > $1.health }.prefix(count)
            let points = targets.map(\.position)
            for target in targets {
                apply(HitPayload(damage: damage, type: type, piercesArmor: true, stunChance: stun > 0 ? 1 : 0, stunDuration: stun,
                                 bossMultiplier: tower.stats.bossMultiplier),
                      to: target, from: tower, showNumber: true)
                if splash > 0 {
                    for other in enemies where other !== target && other.isTargetable
                        && other.position.distance(to: target.position) <= CGFloat(splash) {
                        apply(HitPayload(damage: damage * 0.4, type: type, piercesArmor: true,
                                         stunChance: stun > 0 ? 1 : 0, stunDuration: stun * 0.5),
                              to: other, from: tower, showNumber: false)
                    }
                }
            }
            events.append(.powerStrikes(points: Array(points), splash: CGFloat(splash)))

        case let .field(duration, dps, slow, scale, fieldType):
            let radius = range * CGFloat(scale)
            fields.append(PowerField(id: makeID(), center: tower.position, radius: radius, dps: dps, slow: slow,
                                     type: fieldType, duration: duration))
            events.append(.fieldStarted(center: tower.position, radius: radius, duration: duration, type: fieldType))

        case let .missiles(count, damage, splash):
            let targets = inReach(1.5).sorted { remaining($0) < remaining($1) }
            for i in 0..<count {
                launchMissile(from: tower, at: targets[i % targets.count],
                              payload: HitPayload(damage: damage, type: .explosive, piercesArmor: true), splash: splash, index: i)
            }

        case let .timeStop(duration):
            for enemy in enemies where enemy.isTargetable { stun(enemy, for: duration) }
            events.append(.timeStop(duration: duration))

        case let .rally(duration, rate, damage, scale):
            let radius = range * CGFloat(scale)
            for ally in towers where ally.position.distance(to: tower.position) <= radius {
                ally.rallyTimer = duration
                ally.rallyRate = rate
                ally.rallyDamage = damage
            }
            events.append(.rally(towerID: tower.id, radius: radius))

        case let .strip(damage, scale):
            for enemy in inReach(scale) {
                enemy.revealed = true
                enemy.shield = 0
                enemy.armorShred = 99
                enemy.armorShredTimer = 8
                apply(HitPayload(damage: damage, type: type, piercesArmor: true), to: enemy, from: tower, showNumber: false)
            }
            events.append(.strip(center: tower.position, radius: range * CGFloat(scale)))

        case let .confuse(duration, damage, scale):
            for enemy in inReach(scale) {
                apply(HitPayload(damage: damage, type: type, piercesArmor: true, confuseChance: 1, confuseDuration: duration),
                      to: enemy, from: tower, showNumber: false)
            }
            events.append(.confuseWave(center: tower.position, radius: range * CGFloat(scale)))
        }
        events.append(.powerActivated(towerID: tower.id, kind: tower.kind, name: power.name))
        return true
    }

    // MARK: - Simulation

    func step(_ dt: Double) {
        guard !phase.isOver else { return }
        time += dt

        switch phase {
        case .intermission:
            intermissionRemaining -= dt
            if intermissionRemaining <= 0 { beginWave() }
        case .waveActive:
            processSpawns(dt)
        default:
            break
        }

        updateEnemies(dt)
        updateFields(dt)
        updateTowers(dt)
        updateProjectiles(dt)
        flushIncoming()
        removeResolvedEnemies()
        checkWaveCompletion()
    }

    private func beginWave() {
        waveNumber += 1
        let index = waveNumber - 1
        let definition = waveDefinition(number: waveNumber)
        spawnQueue = definition.groups
            .flatMap { group in
                (0..<group.count).map { ScheduledSpawn(time: group.delay + Double($0) * group.interval, kind: group.kind) }
            }
            .sorted { $0.time < $1.time }
        waveClock = 0
        waveEnemyTotal = spawnQueue.count
        waveEnemiesResolved = 0
        intermissionRemaining = 0
        phase = .waveActive
        events.append(.waveStarted(
            number: waveNumber,
            isBoss: definition.hasBoss,
            newKinds: index < waves.count ? WaveLibrary.newKinds(in: waves, at: index) : []
        ))
    }

    private func processSpawns(_ dt: Double) {
        waveClock += dt
        while let next = spawnQueue.first, next.time <= waveClock {
            spawnQueue.removeFirst()
            spawn(next.kind, at: Self.spawnDistance, route: nextRoute)
            nextRoute = (nextRoute + 1) % paths.count
        }
        flushIncoming()
    }

    @discardableResult
    private func spawn(_ kind: EnemyKind, at distance: CGFloat, route: Int) -> Enemy {
        let wave = max(1, waveNumber)
        let health = kind.baseHealth * WaveLibrary.healthMultiplier(wave: wave) * map.difficulty.healthMultiplier
        let bounty = max(1, Int((Double(kind.bounty) * WaveLibrary.bountyMultiplier(wave: wave)).rounded()))
        let lane = kind.isBoss ? 0 : CGFloat(Double.random(in: -0.14...0.14, using: &rng))
        let enemy = Enemy(id: makeID(), kind: kind, maxHealth: health, bounty: bounty, route: route, distance: distance, laneOffset: lane)
        place(enemy)
        incoming.append(enemy)
        return enemy
    }

    /// Spawns an extra enemy mid-wave (split fragments, boss summons) and counts it toward the wave.
    private func spawnChild(_ kind: EnemyKind, at distance: CGFloat, route: Int) {
        spawn(kind, at: max(Self.spawnDistance, min(distance, paths[route].totalLength - 0.1)), route: route)
        waveEnemyTotal += 1
    }

    private func flushIncoming() {
        guard !incoming.isEmpty else { return }
        for enemy in incoming { enemiesByID[enemy.id] = enemy }
        enemies.append(contentsOf: incoming)
        incoming.removeAll(keepingCapacity: true)
    }

    /// Distance left to the crystal, comparable across routes of different lengths.
    private func remaining(_ enemy: Enemy) -> CGFloat {
        paths[enemy.route].totalLength - enemy.distance
    }

    private func place(_ enemy: Enemy) {
        let path = paths[enemy.route]
        let direction = path.direction(at: enemy.distance)
        enemy.heading = direction
        enemy.position = path.point(at: enemy.distance) + direction.perpendicular * enemy.laneOffset
    }

    private func updateEnemies(_ dt: Double) {
        for enemy in enemies where !enemy.isResolved {
            if enemy.hitFlash > 0 { enemy.hitFlash -= dt }
            if enemy.slowTimer > 0 {
                enemy.slowTimer -= dt
                if enemy.slowTimer <= 0 { enemy.slowAmount = 0 }
            }
            if enemy.armorShredTimer > 0 {
                enemy.armorShredTimer -= dt
                if enemy.armorShredTimer <= 0 { enemy.armorShred = 0 }
            }
            tickDamageOverTime(enemy, dt)
            if enemy.isResolved { continue }
            if enemy.stoneTimer > 0 {
                enemy.stoneTimer -= dt
                continue
            }
            if enemy.stunTimer > 0 {
                enemy.stunTimer -= dt
                continue
            }
            if enemy.confuseTimer > 0 {
                enemy.confuseTimer -= dt
                enemy.distance = max(Self.spawnDistance, enemy.distance - CGFloat(enemy.currentSpeed * 0.7 * dt))
                place(enemy)
                continue
            }
            enemy.distance += CGFloat(enemy.currentSpeed * dt)
            if remaining(enemy) <= 0 {
                leak(enemy)
                if phase.isOver { return }
                continue
            }
            place(enemy)
            useAbilities(of: enemy, dt)
        }
    }

    /// Burning and poison ignore armor and shields.
    private func tickDamageOverTime(_ enemy: Enemy, _ dt: Double) {
        var amount = 0.0
        if enemy.burnTimer > 0 {
            enemy.burnTimer -= dt
            amount += enemy.burnDPS * dt
        }
        if enemy.poisonTimer > 0 {
            enemy.poisonTimer -= dt
            amount += enemy.poisonDPS * dt
        }
        guard amount > 0, !enemy.isStone else { return }
        enemy.health -= amount
        stats.damageDealt += amount
        if enemy.health <= 0 { kill(enemy, by: nil) }
    }

    private func useAbilities(of enemy: Enemy, _ dt: Double) {
        guard enemy.kind.abilityInterval > 0 else { return }
        enemy.abilityTimer -= dt
        guard enemy.abilityTimer <= 0 else { return }
        enemy.abilityTimer += enemy.kind.abilityInterval

        for ability in enemy.kind.abilities {
            switch ability {
            case let .heal(radius, fraction):
                var healedAny = false
                for other in enemies where other !== enemy && other.isTargetable && other.health < other.maxHealth
                    && other.position.distance(to: enemy.position) <= CGFloat(radius) {
                    other.health = min(other.maxHealth, other.health + other.maxHealth * fraction)
                    healedAny = true
                }
                if healedAny { events.append(.enemyHealed(center: enemy.position, radius: CGFloat(radius))) }

            case let .summon(kind, count):
                for i in 0..<count {
                    let offset = (CGFloat(i) - CGFloat(count - 1) / 2) * 0.7
                    spawnChild(kind, at: enemy.distance + offset, route: enemy.route)
                }
                events.append(.bossSummon(at: enemy.position))

            case let .shieldAllies(radius, fraction):
                var shieldedAny = false
                for other in enemies where other !== enemy && other.isTargetable
                    && other.position.distance(to: enemy.position) <= CGFloat(radius) {
                    other.shield = max(other.shield, other.maxHealth * fraction)
                    shieldedAny = true
                }
                if shieldedAny { events.append(.enemyShielded(center: enemy.position, radius: CGFloat(radius))) }

            case let .disruptTowers(radius, duration):
                for tower in towers where tower.position.distance(to: enemy.position) <= CGFloat(radius) {
                    tower.disabledTimer = max(tower.disabledTimer, duration)
                    tower.frenzyTimer = 0
                }
                events.append(.towersDisrupted(center: enemy.position, radius: CGFloat(radius)))

            case let .stoneForm(duration):
                enemy.stoneTimer = duration
                events.append(.enemyPetrified(at: enemy.position))

            case let .teleport(distance):
                let from = enemy.position
                enemy.distance = min(enemy.distance + CGFloat(distance), paths[enemy.route].totalLength - 0.6)
                place(enemy)
                events.append(.enemyTeleported(from: from, to: enemy.position))
            }
        }
    }

    private func leak(_ enemy: Enemy) {
        enemy.isResolved = true
        let cost = enemy.kind.livesCost
        lives = max(0, lives - cost)
        stats.livesLost += cost
        waveEnemiesResolved += 1
        events.append(.enemyLeaked(enemyID: enemy.id, kind: enemy.kind, livesLost: cost))
        if lives == 0 {
            phase = .defeat
            events.append(.defeat)
        }
    }

    private func updateFields(_ dt: Double) {
        guard !fields.isEmpty, !phase.isOver else { return }
        for field in fields {
            field.remaining -= dt
            for enemy in enemies where enemy.isTargetable && enemy.position.distance(to: field.center) <= field.radius {
                apply(HitPayload(damage: field.dps * dt, type: field.type, piercesArmor: true, slow: field.slow, slowDuration: 0.3),
                      to: enemy, from: nil, showNumber: false, flash: false)
            }
        }
        fields.removeAll { $0.remaining <= 0 }
    }

    // MARK: Towers

    /// Detection from sonar/spider-sense and attack buffs from Aegis auras.
    private func refreshSupport() {
        let revealers = towers.filter { $0.stats.revealsCamo && !$0.isDisabled }
        let supporters = towers.filter { ($0.stats.buffRate > 0 || $0.stats.buffDamage > 0) && !$0.isDisabled }
        for tower in towers {
            tower.hasDetection = tower.stats.detectsCamo || revealers.contains {
                $0 !== tower && $0.position.distance(to: tower.position) <= CGFloat($0.stats.range)
            }
            var rate = 0.0, damage = 0.0
            for supporter in supporters where supporter !== tower
                && supporter.position.distance(to: tower.position) <= CGFloat(supporter.stats.range) {
                rate = max(rate, supporter.stats.buffRate)
                damage = max(damage, supporter.stats.buffDamage)
            }
            tower.auraRate = rate
            tower.auraDamage = damage
        }
    }

    private func updateTowers(_ dt: Double) {
        guard !phase.isOver else { return }
        refreshSupport()
        for tower in towers {
            tower.cooldown = max(0, tower.cooldown - dt)
            tower.powerCooldown = max(0, tower.powerCooldown - dt)
            if tower.recoil > 0 { tower.recoil = max(0, tower.recoil - dt) }
            if tower.rallyTimer > 0 { tower.rallyTimer -= dt }
            if tower.disabledTimer > 0 {
                tower.disabledTimer -= dt
                continue
            }
            if tower.frenzyTimer > 0 {
                tower.frenzyTimer -= dt
                if tower.frenzyTimer <= 0 {
                    tower.frenzyRate = 1
                    tower.frenzyDamage = 1
                }
            }
            let stats = tower.stats
            let targets = acquireTargets(for: tower, count: max(stats.multishot, stats.missiles, 1))
            guard let primary = targets.first else { continue }
            tower.aim = (primary.position - tower.position).normalized
            guard tower.cooldown <= 0 else { continue }
            tower.cooldown = stats.fireInterval / tower.rateMultiplier
            tower.recoil = 0.12
            fire(tower, targets: targets)
        }
    }

    private func canSee(_ enemy: Enemy, from tower: Tower) -> Bool {
        (!enemy.kind.isFlying || tower.stats.hitsAir) && (!enemy.isHidden || tower.hasDetection)
    }

    /// Best visible targets in range by the tower's targeting mode, best first.
    private func acquireTargets(for tower: Tower, count: Int) -> [Enemy] {
        let range = tower.stats.range
        var scored: [(score: Double, enemy: Enemy)] = []
        for enemy in enemies where enemy.isTargetable && canSee(enemy, from: tower) {
            let distance = tower.position.distance(to: enemy.position)
            guard distance <= CGFloat(range + enemy.kind.radius * 0.5) else { continue }
            let score: Double = switch tower.targeting {
            case .first: -Double(remaining(enemy))
            case .last: Double(remaining(enemy))
            case .strongest: (enemy.health + enemy.shield) * 1000 - Double(remaining(enemy))
            case .closest: -Double(distance)
            }
            scored.append((score, enemy))
        }
        if count == 1 {
            return scored.max { $0.score < $1.score }.map { [$0.enemy] } ?? []
        }
        return scored.sorted { $0.score > $1.score }.prefix(count).map(\.enemy)
    }

    private func payload(for tower: Tower) -> HitPayload {
        let s = tower.stats
        return HitPayload(
            damage: s.damage * tower.damageMultiplier, type: s.damageType, piercesArmor: s.piercesArmor,
            stunChance: s.stunChance, stunDuration: s.stunDuration,
            bossMultiplier: s.bossMultiplier, airMultiplier: s.airMultiplier, detectsCamo: tower.hasDetection,
            slow: s.slow, slowDuration: s.slowDuration, burnDPS: s.burnDPS, burnDuration: s.burnDuration,
            poisonDPS: s.poisonDPS, poisonDuration: s.poisonDuration, knockback: s.knockback,
            confuseChance: s.confuseChance, confuseDuration: s.confuseDuration,
            armorShred: s.armorShred, shieldBreak: s.shieldBreak
        )
    }

    private func fire(_ tower: Tower, targets: [Enemy]) {
        let stats = tower.stats
        let primary = targets[0]
        let hit = payload(for: tower)

        switch tower.kind.attackStyle {
        case .bolt:
            for target in targets.prefix(stats.multishot) {
                let direction = (target.position - tower.position).normalized
                projectiles.append(Projectile(
                    id: makeID(), kind: .bolt, towerID: tower.id, towerKind: tower.kind,
                    origin: tower.position + direction * 0.35, targetID: target.id, targetPoint: target.position,
                    payload: hit, speed: stats.projectileSpeed, hits: stats.pierce
                ))
            }

        case .lob:
            let path = paths[primary.route]
            let lead = primary.distance + CGFloat(primary.currentSpeed * Self.mortarFlightTime)
            let clamped = min(lead, path.totalLength)
            let impact = path.point(at: clamped) + path.direction(at: clamped).perpendicular * primary.laneOffset
            projectiles.append(Projectile(
                id: makeID(), kind: .shell, towerID: tower.id, towerKind: tower.kind, origin: tower.position,
                targetID: nil, targetPoint: impact, payload: hit,
                splashRadius: stats.splashRadius, flightTime: Self.mortarFlightTime
            ))

        case .aura:
            for enemy in enemies where enemy.isTargetable
                && tower.position.distance(to: enemy.position) <= CGFloat(stats.range + enemy.kind.radius * 0.5) {
                apply(hit, to: enemy, from: tower, showNumber: false)
            }
            events.append(.auraPulse(towerID: tower.id, center: tower.position, radius: CGFloat(stats.range)))

        case .chain:
            var chain: [Enemy] = [primary]
            var linked: Set<Int> = [primary.id]
            var current = primary
            while chain.count < stats.chainTargets {
                var nearest: Enemy?
                var nearestDistance = Self.chainJumpRange
                for enemy in enemies where enemy.isTargetable && !linked.contains(enemy.id) && canSee(enemy, from: tower) {
                    let d = enemy.position.distance(to: current.position)
                    if d <= nearestDistance {
                        nearestDistance = d
                        nearest = enemy
                    }
                }
                guard let next = nearest else { break }
                chain.append(next)
                linked.insert(next.id)
                current = next
            }
            let points = [tower.position] + chain.map(\.position)
            var jump = hit
            for (index, enemy) in chain.enumerated() {
                if index > 0 { jump.stunChance = 0 }
                apply(jump, to: enemy, from: tower, showNumber: false)
                jump.damage *= Self.chainFalloff
            }
            events.append(.chainLightning(points: points))

        case .beam:
            let direction = tower.aim
            let start = tower.position + direction * 0.4
            let end = tower.position + direction * CGFloat(stats.range)
            for enemy in enemies where enemy.isTargetable {
                if enemy.position.distance(toSegment: start, end) <= CGFloat(enemy.kind.radius + 0.12) {
                    apply(hit, to: enemy, from: tower, showNumber: !tower.isFrenzied)
                }
            }
            events.append(.beam(towerID: tower.id, from: start, to: end))

        case .cone:
            let direction = tower.aim
            let halfAngle = CGFloat(stats.coneAngle / 2)
            let reach = CGFloat(stats.range)
            for enemy in enemies where enemy.isTargetable && (!enemy.kind.isFlying || stats.hitsAir) {
                let offset = enemy.position - tower.position
                let distance = offset.length
                guard distance <= reach + CGFloat(enemy.kind.radius) else { continue }
                let cosine = distance > 0 ? (offset.x * direction.x + offset.y * direction.y) / distance : 1
                if acos(max(-1, min(1, cosine))) <= halfAngle {
                    apply(hit, to: enemy, from: tower, showNumber: false)
                }
            }
            events.append(.coneBlast(towerID: tower.id, origin: tower.position, direction: direction, range: reach,
                                     angle: CGFloat(stats.coneAngle)))

        case .mind:
            for target in targets.prefix(stats.multishot) {
                apply(hit, to: target, from: tower, showNumber: false)
                events.append(.mindBlast(from: tower.position, to: target.position))
            }
        }
        events.append(.shotFired(towerID: tower.id, kind: tower.kind))

        if stats.missiles > 0 {
            let missileHit = HitPayload(damage: stats.missileDamage * tower.damageMultiplier, type: .explosive, piercesArmor: true,
                                        bossMultiplier: stats.bossMultiplier, detectsCamo: tower.hasDetection)
            for i in 0..<stats.missiles {
                launchMissile(from: tower, at: targets[i % targets.count], payload: missileHit, splash: Self.missileSplash, index: i)
            }
        }
    }

    private func launchMissile(from tower: Tower, at target: Enemy, payload: HitPayload, splash: Double, index: Int) {
        // Fan the launch points out a little so volleys read as a swarm.
        let angle = Double(index) * 2.4
        let offset = CGPoint(x: cos(angle) * 0.25, y: sin(angle) * 0.25)
        projectiles.append(Projectile(
            id: makeID(), kind: .missile, towerID: tower.id, towerKind: tower.kind, origin: tower.position + offset,
            targetID: target.id, targetPoint: target.position, payload: payload,
            speed: Self.missileSpeed - Double(index % 4) * 0.4, splashRadius: splash
        ))
    }

    // MARK: Projectiles

    private func updateProjectiles(_ dt: Double) {
        guard !phase.isOver else { return }
        for projectile in projectiles where !projectile.isDone {
            switch projectile.kind {
            case .bolt, .missile:
                if let id = projectile.targetID, let target = enemiesByID[id], target.isTargetable {
                    projectile.targetPoint = target.position
                } else {
                    projectile.targetID = nil
                }
                let delta = projectile.targetPoint - projectile.position
                let distance = delta.length
                let travel = CGFloat(projectile.speed * dt)
                if distance > travel + 0.05 {
                    projectile.position = projectile.position + delta * (travel / distance)
                    continue
                }
                projectile.position = projectile.targetPoint
                if projectile.kind == .missile {
                    projectile.isDone = true
                    detonate(projectile)
                } else {
                    boltArrived(projectile)
                }

            case .shell:
                projectile.elapsed += dt
                let t = min(1, projectile.elapsed / projectile.flightTime)
                projectile.position = projectile.origin.lerp(to: projectile.targetPoint, CGFloat(t))
                projectile.height = 4 * t * (1 - t)
                if t >= 1 {
                    projectile.isDone = true
                    explode(projectile)
                }
            }
        }
        projectiles.removeAll { $0.isDone }
    }

    /// Damages the bolt's target, then ricochets to a fresh enemy if it has hits left.
    private func boltArrived(_ bolt: Projectile) {
        guard let id = bolt.targetID, let target = enemiesByID[id] else {
            bolt.isDone = true
            events.append(.boltImpact(at: bolt.position))
            return
        }
        bolt.hitIDs.insert(id)
        apply(bolt.payload, to: target, from: tower(id: bolt.towerID), showNumber: false)
        bolt.remainingHits -= 1
        events.append(.boltImpact(at: bolt.position))
        guard bolt.remainingHits > 0 else {
            bolt.isDone = true
            return
        }
        var next: Enemy?
        var best = Self.ricochetRange
        for enemy in enemies where enemy.isTargetable && !bolt.hitIDs.contains(enemy.id)
            && (!enemy.isHidden || bolt.payload.detectsCamo) {
            let d = enemy.position.distance(to: bolt.position)
            if d <= best {
                best = d
                next = enemy
            }
        }
        if let next {
            bolt.targetID = next.id
            bolt.targetPoint = next.position
        } else {
            bolt.isDone = true
        }
    }

    private func detonate(_ missile: Projectile) {
        let radius = CGFloat(missile.splashRadius)
        let source = tower(id: missile.towerID)
        for enemy in enemies where enemy.isTargetable
            && enemy.position.distance(to: missile.position) <= radius + CGFloat(enemy.kind.radius) {
            apply(missile.payload, to: enemy, from: source, showNumber: false)
        }
        events.append(.missileImpact(center: missile.position, radius: radius))
    }

    private func explode(_ shell: Projectile) {
        let source = tower(id: shell.towerID)
        let radius = CGFloat(shell.splashRadius)
        var hitAny = false
        for enemy in enemies where enemy.isTargetable && !enemy.kind.isFlying {
            if enemy.position.distance(to: shell.position) <= radius + CGFloat(enemy.kind.radius) {
                apply(shell.payload, to: enemy, from: source, showNumber: false)
                hitAny = true
            }
        }
        events.append(.shellImpact(center: shell.position, radius: radius))
        if hitAny {
            events.append(.heavyHit(at: shell.position, amount: Int(shell.payload.damage.rounded())))
        }
    }

    // MARK: Damage and status effects

    private func stun(_ enemy: Enemy, for duration: Double) {
        let effective = duration * (1 - enemy.kind.stunResistance)
        guard effective > 0.05 else { return }
        enemy.stunTimer = max(enemy.stunTimer, effective)
    }

    private func roll(_ chance: Double) -> Bool {
        chance >= 1 || (chance > 0 && Double.random(in: 0..<1, using: &rng) < chance)
    }

    /// Applies one hit: immunity, status effects, armor, weaknesses, shields, then health.
    private func apply(_ hit: HitPayload, to enemy: Enemy, from tower: Tower?, showNumber: Bool, flash: Bool = true) {
        guard enemy.isTargetable else { return }
        if enemy.isStone || enemy.kind.immunities.contains(hit.type) {
            if flash && time - lastImmuneEvent > 0.25 {
                lastImmuneEvent = time
                events.append(.immune(at: enemy.position))
            }
            return
        }

        if roll(hit.stunChance) { stun(enemy, for: hit.stunDuration) }
        if hit.slow > 0 && enemy.kind.slowResistance < 1 {
            enemy.slowAmount = max(enemy.slowAmount, hit.slow)
            enemy.slowTimer = max(enemy.slowTimer, hit.slowDuration)
        }
        if hit.burnDPS > 0 && !enemy.kind.immunities.contains(.fire) {
            enemy.burnDPS = max(enemy.burnDPS, hit.burnDPS)
            enemy.burnTimer = max(enemy.burnTimer, hit.burnDuration)
        }
        if hit.poisonDPS > 0 && !enemy.kind.immunities.contains(.toxic) {
            enemy.poisonDPS = max(enemy.poisonDPS, hit.poisonDPS)
            enemy.poisonTimer = max(enemy.poisonTimer, hit.poisonDuration)
        }
        if hit.knockback > 0 && !enemy.kind.isBoss {
            enemy.distance = max(Self.spawnDistance, enemy.distance - CGFloat(hit.knockback))
            place(enemy)
        }
        if !enemy.kind.isBoss, roll(hit.confuseChance) {
            enemy.confuseTimer = max(enemy.confuseTimer, hit.confuseDuration * (1 - enemy.kind.stunResistance))
        }
        if hit.armorShred > 0 {
            enemy.armorShred = max(enemy.armorShred, hit.armorShred)
            enemy.armorShredTimer = max(enemy.armorShredTimer, 4)
        }

        let psychic = hit.type == .psychic
        var dealt = hit.piercesArmor || psychic ? hit.damage : max(hit.damage - enemy.effectiveArmor, hit.damage * 0.25)
        if enemy.kind.weaknesses.contains(hit.type) { dealt *= Self.weaknessMultiplier }
        if enemy.kind.isBoss { dealt *= hit.bossMultiplier }
        if enemy.kind.isFlying { dealt *= hit.airMultiplier }
        if enemy.shield > 0 && !psychic {
            let shieldDamage = dealt * hit.shieldBreak
            let absorbed = min(enemy.shield, shieldDamage)
            enemy.shield -= absorbed
            dealt -= absorbed / hit.shieldBreak
        }
        let applied = min(dealt, enemy.health)
        enemy.health -= dealt
        if flash { enemy.hitFlash = 0.08 }
        tower?.damageDealt += applied
        stats.damageDealt += applied
        if showNumber && dealt >= 1 {
            events.append(.heavyHit(at: enemy.position, amount: Int(dealt.rounded())))
        }
        if enemy.health <= 0 {
            kill(enemy, by: tower)
        }
    }

    private func kill(_ enemy: Enemy, by tower: Tower?) {
        enemy.isResolved = true
        enemy.health = 0
        tower?.kills += 1
        earn(enemy.bounty)
        stats.enemiesDefeated += 1
        stats.kills[enemy.kind, default: 0] += 1
        waveEnemiesResolved += 1
        events.append(.enemyKilled(enemyID: enemy.id, kind: enemy.kind, at: enemy.position, bounty: enemy.bounty))
        if let split = enemy.kind.splitsInto {
            for i in 0..<split.count {
                let offset = (CGFloat(i) - CGFloat(split.count - 1) / 2) * 0.3
                spawnChild(split.kind, at: enemy.distance + offset, route: enemy.route)
            }
            events.append(.enemySplit(at: enemy.position))
        }
    }

    private func earn(_ amount: Int) {
        gold += amount
        stats.goldEarned += amount
    }

    private func removeResolvedEnemies() {
        guard enemies.contains(where: \.isResolved) else { return }
        for enemy in enemies where enemy.isResolved { enemiesByID[enemy.id] = nil }
        enemies.removeAll(where: \.isResolved)
    }

    private func checkWaveCompletion() {
        guard phase == .waveActive, spawnQueue.isEmpty, incoming.isEmpty, enemies.isEmpty else { return }
        let bonus = WaveLibrary.clearBonus(wave: waveNumber)
        earn(bonus)
        fields.removeAll()
        events.append(.waveCleared(number: waveNumber, bonus: bonus))
        if waveNumber == waves.count && !isEndless {
            phase = .victory
            events.append(.victory)
        } else {
            phase = .intermission
            intermissionRemaining = Self.intermissionDuration
        }
    }

    #if DEBUG
    /// Test hook for simulator checks (`-richStart`).
    func debugGrantGold(_ amount: Int) { gold += amount }
    #endif

    private func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }
}
