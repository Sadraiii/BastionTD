import Foundation

/// The player's own hero: one per match, movable, levels up from kills during the match.
enum CommanderKind: String, CaseIterable, Codable, Identifiable {
    case knight, mage, ranger

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    var role: String {
        switch self {
        case .knight: "Melee brawler. Stuns crowds and rallies nearby heroes."
        case .mage: "Area spells. Burns groups and slows them down."
        case .ranger: "Long range archer. Sees cloaked villains and snipes bosses."
        }
    }

    var damage: Double {
        switch self {
        case .knight: 18
        case .mage: 16
        case .ranger: 20
        }
    }

    var range: Double {
        switch self {
        case .knight: 1.3
        case .mage: 2.4
        case .ranger: 3.6
        }
    }

    var attackInterval: Double {
        switch self {
        case .knight: 0.7
        case .mage: 1.4
        case .ranger: 0.9
        }
    }

    var damageType: DamageType {
        switch self {
        case .knight: .kinetic
        case .mage: .fire
        case .ranger: .kinetic
        }
    }

    /// Knight swings and mage bolts also hit villains around the target.
    var splash: Double {
        switch self {
        case .knight: 0.5
        case .mage: 0.8
        case .ranger: 0
        }
    }
    var hitsAir: Bool { self != .knight }
    var detectsCamo: Bool { self == .ranger }

    var skills: [CommanderSkill] {
        switch self {
        case .knight: [
            CommanderSkill(name: "Shield Bash", detail: "Damages and stuns villains next to the knight.", cooldown: 14),
            CommanderSkill(name: "Rally Cry", detail: "Nearby heroes attack faster and harder for 6s.", cooldown: 25),
            CommanderSkill(name: "Whirlwind", detail: "Heavy damage to everything around the knight.", cooldown: 30),
        ]
        case .mage: [
            CommanderSkill(name: "Fireball", detail: "Blasts the strongest villain in range and those near it.", cooldown: 12),
            CommanderSkill(name: "Frost Nova", detail: "Freezing field that slows and chills for 5s.", cooldown: 22),
            CommanderSkill(name: "Meteor", detail: "Three meteors crash onto the leading villains.", cooldown: 40),
        ]
        case .ranger: [
            CommanderSkill(name: "Volley", detail: "Arrows hit several villains in range at once.", cooldown: 12),
            CommanderSkill(name: "Hunter's Mark", detail: "Reveals cloaked villains in range and strips armor.", cooldown: 18),
            CommanderSkill(name: "Snipe", detail: "A huge shot at the strongest villain anywhere.", cooldown: 35),
        ]
        }
    }

    // MARK: In-match levels

    static let maxLevel = 10

    /// XP needed to go from `level` to the next one.
    static func xpToNext(level: Int) -> Int { 8 + level * 6 }

    /// Damage and skill strength grow with each level.
    static func power(level: Int) -> Double { 1 + 0.12 * Double(level - 1) }
}

struct CommanderSkill {
    let name: String
    let detail: String
    let cooldown: Double

    static let maxLevel = 3

    /// Research Points to raise a skill to `level`.
    static func cost(level: Int) -> Int { level * 5 }
}

/// The commander a match starts with and its researched skill levels (0 means locked).
struct CommanderLoadout: Codable, Equatable {
    var kind: CommanderKind
    var skillLevels: [Int]
}

/// Saved between matches: the chosen commander and the skill levels of each.
struct CommanderProgress: Codable, Equatable {
    var selected: CommanderKind = .knight
    var levels: [CommanderKind: [Int]] = [:]

    /// The first skill comes free.
    func skillLevels(_ kind: CommanderKind) -> [Int] { levels[kind] ?? [1, 0, 0] }

    var loadout: CommanderLoadout { CommanderLoadout(kind: selected, skillLevels: skillLevels(selected)) }
}
