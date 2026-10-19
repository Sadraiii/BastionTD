import CoreGraphics

/// A live villain walking the path. All positions are in logical tile units.
final class Enemy {
    let id: Int
    let kind: EnemyKind
    let maxHealth: Double
    let bounty: Int
    /// Index of the route this enemy follows, on maps where the path splits.
    let route: Int
    /// Sideways offset from the path's center line so crowds don't overlap perfectly.
    let laneOffset: CGFloat

    var health: Double
    /// Absorbs damage before health (granted by Hexers).
    var shield: Double = 0
    var distance: CGFloat
    var position: CGPoint = .zero
    var heading = CGPoint(x: 1, y: 0)
    var slowAmount: Double = 0
    var slowTimer: Double = 0
    /// Stunned or frozen enemies stand still.
    var stunTimer: Double = 0
    var burnDPS: Double = 0
    var burnTimer: Double = 0
    var poisonDPS: Double = 0
    var poisonTimer: Double = 0
    /// Confused enemies walk backwards.
    var confuseTimer: Double = 0
    /// Armor temporarily removed by shredding attacks.
    var armorShred: Double = 0
    var armorShredTimer: Double = 0
    /// Gargoyles in stone form ignore all damage.
    var stoneTimer: Double = 0
    /// A cloaked villain that has been exposed (Sonic Shatter) can be seen by anyone.
    var revealed = false
    /// Hidden by a Bog Witch while this counts down, or for good at Night.
    var cloakTimer: Double = 0
    var abilityTimer: Double
    /// Counts down after a hit so the renderer can flash the sprite.
    var hitFlash: Double = 0
    /// Set once the enemy has died or reached the crystal.
    var isResolved = false

    init(id: Int, kind: EnemyKind, maxHealth: Double, bounty: Int, route: Int, distance: CGFloat, laneOffset: CGFloat) {
        self.id = id
        self.kind = kind
        self.maxHealth = maxHealth
        self.health = maxHealth
        self.bounty = bounty
        self.route = route
        self.distance = distance
        self.laneOffset = laneOffset
        self.abilityTimer = kind.abilityInterval
    }

    var healthFraction: Double { max(0, health / maxHealth) }
    var isSlowed: Bool { slowTimer > 0 && slowAmount > 0 && kind.slowResistance < 1 }
    var isStunned: Bool { stunTimer > 0 }
    var isBurning: Bool { burnTimer > 0 }
    var isPoisoned: Bool { poisonTimer > 0 }
    var isConfused: Bool { confuseTimer > 0 }
    var isStone: Bool { stoneTimer > 0 }
    var isHidden: Bool { (kind.isCamo || cloakTimer > 0) && !revealed }
    var effectiveArmor: Double { max(0, kind.armor - armorShred) }

    var currentSpeed: Double {
        guard stunTimer <= 0, stoneTimer <= 0 else { return 0 }
        let enrage = 1 + kind.enrageBonus * (1 - healthFraction)
        return kind.speed * enrage * (1 - slowAmount * (1 - kind.slowResistance))
    }

    var isTargetable: Bool { !isResolved && health > 0 }
}

final class Tower {
    let id: Int
    let kind: TowerKind
    let cell: GridPoint
    /// Purchased tier on each upgrade path.
    private(set) var tiers: [Int] = Array(repeating: 0, count: UpgradeRules.pathCount)
    private(set) var stats: TowerStats
    private(set) var power: PowerDefinition?
    var targeting: TargetingMode
    var cooldown: Double = 0
    /// Logical direction the turret faces.
    var aim = CGPoint(x: 0, y: -1)
    /// Counts down after firing; drives the recoil animation.
    var recoil: Double = 0
    var totalInvested: Int
    var kills = 0
    var damageDealt: Double = 0
    var powerCooldown: Double = 0
    var frenzyTimer: Double = 0
    var frenzyRate: Double = 1
    var frenzyDamage: Double = 1
    var rallyTimer: Double = 0
    var rallyRate: Double = 1
    var rallyDamage: Double = 1
    /// Support from nearby Aegis heroes, recomputed every step.
    var auraRate: Double = 0
    var auraDamage: Double = 0
    /// Own detection or a nearby hero's sonar/spider-sense.
    var hasDetection = false
    /// Knocked offline by an EMP.
    var disabledTimer: Double = 0

    init(id: Int, kind: TowerKind, cell: GridPoint) {
        self.id = id
        self.kind = kind
        self.cell = cell
        self.targeting = kind.defaultTargeting
        self.totalInvested = kind.cost
        self.stats = kind.baseStats
    }

    var position: CGPoint { cell.center }
    var visualLevel: Int { TowerKind.visualLevel(tiers: tiers) }
    var sellValue: Int { Int((Double(totalInvested) * GameEngine.sellRefundRate).rounded()) }
    var isDisabled: Bool { disabledTimer > 0 }
    var isFrenzied: Bool { frenzyTimer > 0 }
    var isRallied: Bool { rallyTimer > 0 }
    var isBuffed: Bool { auraRate > 0 || auraDamage > 0 || isRallied }
    var isPowerReady: Bool { power != nil && powerCooldown <= 0 && !isDisabled }

    /// Combined attack-speed multiplier from powers and allies.
    var rateMultiplier: Double { frenzyRate * (1 + auraRate) * (isRallied ? rallyRate : 1) }
    var damageMultiplier: Double { frenzyDamage * (1 + auraDamage) * (isRallied ? rallyDamage : 1) }

    func nextTier(onPath path: Int) -> UpgradeTier? {
        let current = tiers[path]
        return current < UpgradeRules.maxTier ? kind.paths[path].tiers[current] : nil
    }

    func advance(path: Int) {
        tiers[path] += 1
        stats = kind.stats(tiers: tiers)
        power = kind.power(tiers: tiers)
    }
}

/// Damage and side effects carried by an attack.
struct HitPayload {
    var damage: Double
    var type: DamageType = .kinetic
    var piercesArmor = false
    var stunChance: Double = 0
    var stunDuration: Double = 0
    var bossMultiplier: Double = 1
    var airMultiplier: Double = 1
    var detectsCamo = false
    var slow: Double = 0
    var slowDuration: Double = 0
    var burnDPS: Double = 0
    var burnDuration: Double = 0
    var poisonDPS: Double = 0
    var poisonDuration: Double = 0
    var knockback: Double = 0
    var confuseChance: Double = 0
    var confuseDuration: Double = 0
    var armorShred: Double = 0
    var shieldBreak: Double = 1
}

final class Projectile {
    enum Kind { case bolt, shell, missile }

    let id: Int
    let kind: Kind
    let towerID: Int
    /// Which hero fired it, so the renderer can pick the right sprite.
    let towerKind: TowerKind
    let origin: CGPoint
    let payload: HitPayload
    let speed: Double
    let splashRadius: Double
    let flightTime: Double

    var position: CGPoint
    var targetID: Int?
    var targetPoint: CGPoint
    var elapsed: Double = 0
    /// 0 on the ground, 1 at the top of a mortar arc.
    var height: Double = 0
    /// Ricochets left for bolts.
    var remainingHits: Int
    var hitIDs: Set<Int> = []
    var isDone = false

    init(id: Int, kind: Kind, towerID: Int, towerKind: TowerKind, origin: CGPoint, targetID: Int?, targetPoint: CGPoint,
         payload: HitPayload, speed: Double = 0, splashRadius: Double = 0, flightTime: Double = 0, hits: Int = 1) {
        self.id = id
        self.kind = kind
        self.towerID = towerID
        self.towerKind = towerKind
        self.origin = origin
        self.position = origin
        self.targetID = targetID
        self.targetPoint = targetPoint
        self.payload = payload
        self.speed = speed
        self.splashRadius = splashRadius
        self.flightTime = flightTime
        self.remainingHits = hits
    }

    /// Direction of travel, used to orient missile sprites.
    var heading: CGPoint { (targetPoint - position).normalized }
}

/// A lingering power zone (Blizzard, Firestorm, Black Hole...) that damages and slows.
final class PowerField {
    let id: Int
    let center: CGPoint
    let radius: CGFloat
    let dps: Double
    let slow: Double
    let type: DamageType
    var remaining: Double

    init(id: Int, center: CGPoint, radius: CGFloat, dps: Double, slow: Double, type: DamageType, duration: Double) {
        self.id = id
        self.center = center
        self.radius = radius
        self.dps = dps
        self.slow = slow
        self.type = type
        self.remaining = duration
    }
}

/// The player's commander: walks between grass tiles, attacks on its own and gains levels.
final class Commander {
    let kind: CommanderKind
    let rank: Int
    let skin: CommanderSkin
    /// Level of each skill; 0 means locked. The ultimate unlocks at max level.
    var skillLevels: [Int]
    /// The tile it stands on or is walking to.
    var cell: GridPoint
    var position: CGPoint
    var aim = CGPoint(x: 0, y: -1)
    var level = 1
    var xp = 0
    /// All XP gained this match, kept toward the permanent rank.
    var earnedXP = 0
    var cooldown: Double = 0
    /// Sentry Mode: attacks faster while this counts down.
    var overdriveTimer: Double = 0
    var skillCooldowns: [Double]

    init(loadout: CommanderLoadout, cell: GridPoint) {
        kind = loadout.kind
        rank = loadout.rank
        skin = loadout.skin
        skillLevels = loadout.skillLevels + [0]
        self.cell = cell
        position = cell.center
        skillCooldowns = Array(repeating: 0, count: skillLevels.count)
    }

    var isWalking: Bool { position != cell.center }
    var power: Double { CommanderKind.power(level: level, rank: rank) }
    var range: CGFloat { CGFloat(kind.range * (1 + 0.04 * Double(level - 1))) }
}
