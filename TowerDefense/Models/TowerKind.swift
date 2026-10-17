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

/// Combat numbers for a tower with its purchased upgrades applied.
/// Distances are in tiles, times in seconds.
struct TowerStats: Equatable {
    var damage: Double
    var range: Double
    var fireInterval: Double
    var splashRadius: Double = 0
    var slow: Double = 0
    var slowDuration: Double = 0
    var chainTargets: Int = 0
    var hitsAir: Bool = true
    var piercesArmor: Bool = false
    /// Can see and target cloaked villains.
    var detectsCamo: Bool = false
    var projectileSpeed: Double = 0
    /// How many enemies one bolt can hit (it ricochets to the next one).
    var pierce: Int = 1
    /// Targets attacked per shot.
    var multishot: Int = 1
    var stunChance: Double = 0
    var stunDuration: Double = 0
    /// Homing missiles launched alongside each shot.
    var missiles: Int = 0
    var missileDamage: Double = 0
    /// Damage multiplier against bosses.
    var bossMultiplier: Double = 1

    var shotsPerSecond: Double { 1 / fireInterval }
}

/// The five hero towers. Each is an original hero archetype with two upgrade
/// paths (see `HeroCatalog`) and, from tier 3, an active power.
enum TowerKind: String, CaseIterable, Codable, Identifiable {
    case pulse, frost, mortar, tesla, rail

    var id: String { rawValue }

    /// Hero callsign.
    var name: String {
        switch self {
        case .pulse: "Blitz"
        case .frost: "Glacia"
        case .mortar: "Quake"
        case .tesla: "Stormbringer"
        case .rail: "Vanguard"
        }
    }

    var shortName: String {
        switch self {
        case .tesla: "Storm"
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
        }
    }

    /// One-line description of what the hero is good at.
    var role: String {
        switch self {
        case .pulse: "Rapid kinetic bolts. Hits flyers."
        case .frost: "Chilling aura slows everyone nearby."
        case .mortar: "Hurls boulders that splash. Ground only."
        case .tesla: "Lightning that chains between foes."
        case .rail: "Piercing beam. Ignores armor, sees cloaked foes."
        }
    }

    var cost: Int {
        switch self {
        case .pulse: 50
        case .frost: 70
        case .mortar: 100
        case .tesla: 120
        case .rail: 150
        }
    }

    /// Frost hits everything around it, so a targeting choice is meaningless.
    var usesTargeting: Bool { self != .frost }

    var defaultTargeting: TargetingMode { self == .rail ? .strongest : .first }

    var baseStats: TowerStats {
        switch self {
        case .pulse:
            TowerStats(damage: 8, range: 2.3, fireInterval: 0.45, projectileSpeed: 11)
        case .frost:
            TowerStats(damage: 3, range: 1.7, fireInterval: 1.2, slow: 0.35, slowDuration: 1.6)
        case .mortar:
            TowerStats(damage: 28, range: 3.2, fireInterval: 1.9, splashRadius: 0.9, hitsAir: false)
        case .tesla:
            TowerStats(damage: 16, range: 2.1, fireInterval: 1.0, chainTargets: 3)
        case .rail:
            TowerStats(damage: 65, range: 4.4, fireInterval: 2.3, piercesArmor: true, detectsCamo: true)
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
