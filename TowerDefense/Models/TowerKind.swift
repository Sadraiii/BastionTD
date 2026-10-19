import Foundation

/// How a tower picks between several enemies in range.
enum TargetingMode: String, CaseIterable, Codable, Identifiable {
    case first, last, strongest, closest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .first: "First"
        case .last: "Last"
        case .strongest: "Strongest"
        case .closest: "Closest"
        }
    }

    var symbol: String {
        switch self {
        case .first: "arrow.right.to.line"
        case .last: "arrow.left.to.line"
        case .strongest: "bolt.shield"
        case .closest: "scope"
        }
    }
}

/// Combat numbers for a hero with its purchased upgrades applied.
/// Distances are in tiles, times in seconds, angles in radians.
struct TowerStats: Equatable {
    var damage: Double
    var range: Double
    var fireInterval: Double
    var damageType: DamageType = .kinetic
    var splashRadius: Double = 0
    var slow: Double = 0
    var slowDuration: Double = 0
    var chainTargets: Int = 0
    var hitsAir: Bool = true
    var piercesArmor: Bool = false
    /// Can see and target cloaked villains.
    var detectsCamo: Bool = false
    /// Grants camo detection to every hero within this hero's range.
    var revealsCamo: Bool = false
    var projectileSpeed: Double = 0
    /// How many enemies one bolt can hit (it ricochets to the next one).
    var pierce: Int = 1
    /// Targets attacked per shot.
    var multishot: Int = 1
    /// Width of a cone attack.
    var coneAngle: Double = 0
    var stunChance: Double = 0
    var stunDuration: Double = 0
    var burnDPS: Double = 0
    var burnDuration: Double = 0
    var poisonDPS: Double = 0
    var poisonDuration: Double = 0
    /// Pushes non-boss villains back along the path (tiles per hit).
    var knockback: Double = 0
    /// Chance to make a villain walk backwards for `confuseDuration`.
    var confuseChance: Double = 0
    var confuseDuration: Double = 0
    /// Temporarily strips this much armor from villains hit.
    var armorShred: Double = 0
    /// Multiplier against magic shields.
    var shieldBreak: Double = 1
    /// Homing missiles launched alongside each shot.
    var missiles: Int = 0
    var missileDamage: Double = 0
    /// Damage multipliers against bosses and flyers.
    var bossMultiplier: Double = 1
    var airMultiplier: Double = 1
    /// Support aura: extra attack speed and damage for other heroes in range.
    var buffRate: Double = 0
    var buffDamage: Double = 0
    /// Gold paid after each wave.
    var income: Int = 0
    /// Extra damage for every wave the hero survives, up to 20 waves.
    var growth: Double = 0
    /// Villains hit take this much more damage from everyone for `markDuration`.
    var mark: Double = 0
    var markDuration: Double = 0
    /// The support buff also reaches heroes anywhere in this hero's row or column.
    var lineBuff = false

    var shotsPerSecond: Double { 1 / fireInterval }
}

/// The hero roster. The first five are available from the start; the rest are
/// unlocked in the Research Lab. Each hero has two upgrade paths (`HeroCatalog`).
enum TowerKind: String, CaseIterable, Codable, Identifiable {
    case pulse, frost, mortar, tesla, rail
    case inferno, weaver, aegis, cyclone, echo, mind, chrono, star, midas, tide
    case sniper, tamer, alchemist, siren, bramble, omen, rook

    var id: String { rawValue }

    /// Hero callsign.
    var name: String {
        switch self {
        case .pulse: "Blitz"
        case .frost: "Glacia"
        case .mortar: "Quake"
        case .tesla: "Stormbringer"
        case .rail: "Vanguard"
        case .inferno: "Inferno"
        case .weaver: "Weaver"
        case .aegis: "Aegis"
        case .cyclone: "Cyclone"
        case .echo: "Echo"
        case .mind: "Mindwave"
        case .chrono: "Chrono"
        case .star: "Starlight"
        case .midas: "Midas"
        case .tide: "Riptide"
        case .sniper: "Hawkeye"
        case .tamer: "Fang"
        case .alchemist: "Vial"
        case .siren: "Siren"
        case .bramble: "Bramble"
        case .omen: "Omen"
        case .rook: "Rook"
        }
    }

    var shortName: String {
        switch self {
        case .tesla: "Storm"
        case .mind: "Mind"
        case .star: "Star"
        default: name
        }
    }

    var archetype: String {
        switch self {
        case .pulse: "Speedster"
        case .frost: "Ice Hero"
        case .mortar: "Strongman"
        case .tesla: "Thunder Hero"
        case .rail: "Armored Genius"
        case .inferno: "Fire Hero"
        case .weaver: "Spider Hero"
        case .aegis: "Shield Captain"
        case .cyclone: "Wind Hero"
        case .echo: "Sonic Hero"
        case .mind: "Psychic"
        case .chrono: "Time Keeper"
        case .star: "Cosmic Hero"
        case .midas: "Gold Hero"
        case .tide: "Sea Hero"
        case .sniper: "Sniper"
        case .tamer: "Beast Tamer"
        case .alchemist: "Alchemist"
        case .siren: "Sea Singer"
        case .bramble: "Thorn Bush"
        case .omen: "Seer"
        case .rook: "Tactician"
        }
    }

    /// One-line description of what the hero is good at.
    var role: String {
        switch self {
        case .pulse: "Rapid kinetic bolts. Hits flyers."
        case .frost: "Chilling aura slows everyone nearby."
        case .mortar: "Explosive boulders that splash. Ground only."
        case .tesla: "Lightning that chains between foes."
        case .rail: "Piercing energy beam. Ignores armor, sees cloaked foes."
        case .inferno: "Flamethrower cone that sets villains ablaze."
        case .weaver: "Sticky webs slow foes. Spider-sense sees cloaked foes."
        case .aegis: "Ricocheting shield; can inspire nearby heroes."
        case .cyclone: "Wind blades knock foes back. Shreds flyers."
        case .echo: "Sonic scream cone that cracks shields and armor."
        case .mind: "Psychic blasts ignore armor and shields."
        case .chrono: "Time aura slows villains; can freeze time itself."
        case .star: "Long-range cosmic beam. Bonus damage to bosses."
        case .midas: "Makes gold after every wave. Doesn't attack."
        case .tide: "Fires torpedoes from water tiles. Sees cloaked foes."
        case .sniper: "Huge range, slow and heavy shots."
        case .tamer: "Beasts pounce and stun. Can block the path."
        case .alchemist: "Acid flasks that poison and melt armor."
        case .siren: "Turns villains around and cracks shields. Goes on water."
        case .bramble: "Grows stronger every wave it stays on the field."
        case .omen: "Marks villains so every hero hits them harder. Husks can't be marked."
        case .rook: "Fires along its whole row and column."
        }
    }

    var attackStyle: AttackStyle {
        switch self {
        case .pulse, .weaver, .aegis, .cyclone, .tide, .sniper, .tamer, .bramble: .bolt
        case .mortar, .alchemist: .lob
        case .frost, .chrono, .midas: .aura
        case .tesla: .chain
        case .rail, .star: .beam
        case .inferno, .echo, .siren: .cone
        case .mind, .omen: .mind
        case .rook: .cross
        }
    }

    var cost: Int {
        switch self {
        case .pulse: 50
        case .frost: 70
        case .mortar: 100
        case .tesla: 120
        case .rail: 150
        case .inferno: 110
        case .weaver: 80
        case .aegis: 100
        case .cyclone: 90
        case .echo: 110
        case .mind: 140
        case .chrono: 130
        case .star: 170
        case .midas: 120
        case .tide: 110
        case .sniper: 160
        case .tamer: 100
        case .alchemist: 120
        case .siren: 100
        case .bramble: 90
        case .omen: 120
        case .rook: 130
        }
    }

    /// Research Points needed to recruit this hero (0 = available from the start).
    var unlockCost: Int {
        switch self {
        case .pulse, .frost, .mortar, .tesla, .rail: 0
        case .inferno, .weaver: 6
        case .aegis, .cyclone, .midas, .bramble: 8
        case .echo, .tide, .tamer, .siren: 10
        case .alchemist, .omen, .rook: 12
        case .sniper: 14
        case .mind: 12
        case .chrono: 15
        case .star: 18
        }
    }

    /// Naval heroes can only be placed on water.
    var isNaval: Bool { self == .tide || self == .siren }

    static var starters: [TowerKind] { allCases.filter { $0.unlockCost == 0 } }

    /// Aura heroes and the Rook hit everything they reach, so a targeting choice is meaningless.
    var usesTargeting: Bool { attackStyle != .aura && attackStyle != .cross }

    /// Turrets that turn to face their target.
    var rotates: Bool {
        switch self {
        case .pulse, .mortar, .rail, .inferno, .weaver, .echo, .star, .tide, .sniper, .tamer, .alchemist, .siren: true
        default: false
        }
    }

    var defaultTargeting: TargetingMode { self == .rail || self == .star || self == .sniper ? .strongest : .first }

    var baseStats: TowerStats {
        switch self {
        case .pulse:
            TowerStats(damage: 8, range: 2.3, fireInterval: 0.45, projectileSpeed: 11)
        case .frost:
            TowerStats(damage: 3, range: 1.7, fireInterval: 1.2, damageType: .cold, slow: 0.35, slowDuration: 1.6)
        case .mortar:
            TowerStats(damage: 28, range: 3.2, fireInterval: 1.9, damageType: .explosive, splashRadius: 0.9, hitsAir: false)
        case .tesla:
            TowerStats(damage: 16, range: 2.1, fireInterval: 1.0, damageType: .energy, chainTargets: 3)
        case .rail:
            TowerStats(damage: 65, range: 4.4, fireInterval: 2.3, damageType: .energy, piercesArmor: true, detectsCamo: true)
        case .inferno:
            TowerStats(damage: 5, range: 1.8, fireInterval: 0.3, damageType: .fire, coneAngle: 1.0, burnDPS: 5, burnDuration: 2)
        case .weaver:
            TowerStats(damage: 6, range: 2.4, fireInterval: 0.8, slow: 0.4, slowDuration: 1.5, detectsCamo: true, projectileSpeed: 9)
        case .aegis:
            TowerStats(damage: 12, range: 2.4, fireInterval: 1.0, projectileSpeed: 9, pierce: 3)
        case .cyclone:
            TowerStats(damage: 10, range: 2.6, fireInterval: 0.7, projectileSpeed: 10, pierce: 2, knockback: 0.15, airMultiplier: 2)
        case .echo:
            TowerStats(damage: 9, range: 2.0, fireInterval: 0.9, damageType: .sonic, coneAngle: 1.2, shieldBreak: 3)
        case .mind:
            TowerStats(damage: 22, range: 2.6, fireInterval: 1.4, damageType: .psychic, piercesArmor: true, detectsCamo: true)
        case .chrono:
            TowerStats(damage: 4, range: 2.2, fireInterval: 1.0, damageType: .energy, slow: 0.3, slowDuration: 1.2)
        case .star:
            TowerStats(damage: 90, range: 5.5, fireInterval: 2.6, damageType: .energy, bossMultiplier: 1.25)
        case .midas:
            TowerStats(damage: 0, range: 2.0, fireInterval: 1, income: 25)
        case .tide:
            TowerStats(damage: 12, range: 3.2, fireInterval: 0.7, detectsCamo: true, projectileSpeed: 9, pierce: 2)
        case .sniper:
            TowerStats(damage: 60, range: 7, fireInterval: 2.4, projectileSpeed: 25)
        case .tamer:
            TowerStats(damage: 14, range: 2.2, fireInterval: 0.9, projectileSpeed: 8, stunChance: 0.15, stunDuration: 0.6)
        case .alchemist:
            TowerStats(damage: 10, range: 2.6, fireInterval: 1.5, damageType: .toxic, splashRadius: 0.7,
                       poisonDPS: 6, poisonDuration: 3, armorShred: 1)
        case .siren:
            TowerStats(damage: 6, range: 2.4, fireInterval: 1.0, damageType: .sonic, coneAngle: 1.0,
                       confuseChance: 0.12, confuseDuration: 1.2, shieldBreak: 2)
        case .bramble:
            TowerStats(damage: 7, range: 2.2, fireInterval: 0.8, projectileSpeed: 9, growth: 0.05)
        case .omen:
            TowerStats(damage: 6, range: 2.6, fireInterval: 1.2, damageType: .psychic, mark: 0.2, markDuration: 3)
        case .rook:
            // Range only sizes the Field Marshal rally; the lances cross the whole board.
            TowerStats(damage: 30, range: 1.0, fireInterval: 2.0)
        }
    }

    var paths: [UpgradePath] { HeroCatalog.paths(for: self) }

    /// Base stats with every purchased tier applied, path by path.
    func stats(tiers: [Int]) -> TowerStats {
        var stats = baseStats
        for (pathIndex, path) in paths.enumerated() {
            for tier in path.tiers.prefix(tiers[pathIndex]) {
                tier.apply(&stats)
            }
        }
        return stats
    }

    /// The active power granted by the highest tier that has one.
    func power(tiers: [Int]) -> PowerDefinition? {
        var best: (tier: Int, power: PowerDefinition)?
        for (pathIndex, path) in paths.enumerated() {
            for (index, tier) in path.tiers.prefix(tiers[pathIndex]).enumerated() {
                if let power = tier.power, index + 1 > (best?.tier ?? 0) {
                    best = (index + 1, power)
                }
            }
        }
        return best?.power
    }

    /// Which turret art to show (1-3), based on the furthest upgrade.
    static func visualLevel(tiers: [Int]) -> Int {
        let top = tiers.max() ?? 0
        return top >= UpgradeRules.maxTier ? 3 : top >= 2 ? 2 : 1
    }
}

/// Upgrade-path rules, modeled on Bloons TD: tiers are bought in order and only
/// one path may go beyond the cross-path cap.
enum UpgradeRules {
    static let pathCount = 2
    static let maxTier = 4
    static let crossPathCap = 2

    static func canAdvance(_ tiers: [Int], path: Int) -> Bool {
        let next = tiers[path] + 1
        guard next <= maxTier else { return false }
        let other = tiers[1 - path]
        return !(next > crossPathCap && other > crossPathCap)
    }

    /// True when the other path has gone past the cap, blocking this one.
    static func isBlockedByOtherPath(_ tiers: [Int], path: Int) -> Bool {
        tiers[path] + 1 > crossPathCap && tiers[1 - path] > crossPathCap
    }
}
