import Foundation

/// The player's own hero: one per match, movable, levels up from kills during the match.
enum CommanderKind: String, CaseIterable, Codable, Identifiable {
    case knight, mage, ranger, engineer, healer

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    var role: String {
        switch self {
        case .knight: "Close combat. Stuns villains and boosts nearby heroes."
        case .mage: "Spells that hit groups and slow them."
        case .ranger: "Long range. Sees cloaked villains."
        case .engineer: "Rapid nail gun. Speeds up heroes and lays mines."
        case .healer: "Repairs the crystal and strengthens heroes."
        }
    }

    var damage: Double {
        switch self {
        case .knight: 18
        case .mage: 16
        case .ranger: 20
        case .engineer: 9
        case .healer: 10
        }
    }

    var range: Double {
        switch self {
        case .knight: 1.3
        case .mage: 2.4
        case .ranger: 3.6
        case .engineer: 2.6
        case .healer: 2.2
        }
    }

    var attackInterval: Double {
        switch self {
        case .knight: 0.7
        case .mage: 1.4
        case .ranger: 0.9
        case .engineer: 0.45
        case .healer: 0.9
        }
    }

    var damageType: DamageType {
        switch self {
        case .knight: .kinetic
        case .mage: .fire
        case .ranger, .engineer: .kinetic
        case .healer: .energy
        }
    }

    /// Knight swings and mage bolts also hit villains around the target.
    var splash: Double {
        switch self {
        case .knight: 0.5
        case .mage: 0.8
        case .ranger, .engineer, .healer: 0
        }
    }
    var hitsAir: Bool { self != .knight }
    var detectsCamo: Bool { self == .ranger }

    var skills: [CommanderSkill] {
        switch self {
        case .knight: [
            CommanderSkill(name: "Shield Bash", detail: "Hits and stuns villains next to it.", cooldown: 14),
            CommanderSkill(name: "Rally Cry", detail: "Nearby heroes attack faster for 6s.", cooldown: 25),
            CommanderSkill(name: "Whirlwind", detail: "Big damage all around it.", cooldown: 30),
            CommanderSkill(name: "Earthquake", detail: "Stuns every villain on the ground for 3s.", cooldown: 60),
        ]
        case .mage: [
            CommanderSkill(name: "Fireball", detail: "Big hit on the toughest villain in range.", cooldown: 12),
            CommanderSkill(name: "Frost Nova", detail: "Slows villains around it for 5s.", cooldown: 22),
            CommanderSkill(name: "Meteor", detail: "Hits the three villains closest to the crystal.", cooldown: 40),
            CommanderSkill(name: "Armageddon", detail: "Meteors hit the eight villains closest to the crystal.", cooldown: 60),
        ]
        case .ranger: [
            CommanderSkill(name: "Volley", detail: "Hits several villains at once.", cooldown: 12),
            CommanderSkill(name: "Hunter's Mark", detail: "Shows cloaked villains and removes armor.", cooldown: 18),
            CommanderSkill(name: "Snipe", detail: "A huge shot at the toughest villain on the map.", cooldown: 35),
            CommanderSkill(name: "Arrow Storm", detail: "Hits every villain on the map.", cooldown: 60),
        ]
        case .engineer: [
            CommanderSkill(name: "Sentry Mode", detail: "Attacks three times as fast for 8s.", cooldown: 20),
            CommanderSkill(name: "Overclock", detail: "Nearby heroes attack faster for 8s.", cooldown: 25),
            CommanderSkill(name: "Mine Field", detail: "Mines on the nearest path hurt and slow villains for 8s.", cooldown: 30),
            CommanderSkill(name: "Recharge", detail: "Every hero power is ready again.", cooldown: 90),
        ]
        case .healer: [
            CommanderSkill(name: "Mend", detail: "Gives the crystal back lives.", cooldown: 40),
            CommanderSkill(name: "Blessing", detail: "Nearby heroes deal more damage for 8s.", cooldown: 25),
            CommanderSkill(name: "Purify", detail: "Removes shields, armor and cloaks in range.", cooldown: 20),
            CommanderSkill(name: "Sanctuary", detail: "Gives the crystal back 5 lives.", cooldown: 90),
        ]
        }
    }

    // MARK: In-match levels

    static let maxLevel = 10
    /// Skills you research in the lab; the last skill is the ultimate, unlocked at max level in a match.
    static let researchableSkills = 3

    /// XP needed to go from `level` to the next one.
    static func xpToNext(level: Int) -> Int { 8 + level * 6 }

    /// Damage and skill strength grow with each level, plus 2% per permanent rank.
    static func power(level: Int, rank: Int) -> Double { (1 + 0.12 * Double(level - 1)) * (1 + 0.02 * Double(rank)) }

    // MARK: Permanent rank

    static let maxRank = 20

    /// Total XP needed to reach `rank`: 100, 300, 600, ...
    static func xpForRank(_ rank: Int) -> Int { 50 * rank * (rank + 1) }

    static func rank(forXP xp: Int) -> Int {
        var rank = 0
        while rank < maxRank && xp >= xpForRank(rank + 1) { rank += 1 }
        return rank
    }
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
    var rank = 0
    var skin = CommanderSkin.classic
}

/// Colour variants for commanders, unlocked by earning medals.
enum CommanderSkin: Int, CaseIterable, Codable {
    case classic, shadow, gold, crystal

    var name: String {
        switch self {
        case .classic: "Classic"
        case .shadow: "Shadow"
        case .gold: "Gold"
        case .crystal: "Crystal"
        }
    }

    var medalsNeeded: Int {
        switch self {
        case .classic: 0
        case .shadow: 3
        case .gold: 7
        case .crystal: 12
        }
    }
}

/// Saved between matches: the chosen commander and the skill levels of each.
struct CommanderProgress: Codable, Equatable {
    var selected: CommanderKind = .knight
    var levels: [CommanderKind: [Int]] = [:]

    /// The first skill comes free.
    func skillLevels(_ kind: CommanderKind) -> [Int] { levels[kind] ?? [1, 0, 0] }

    var loadout: CommanderLoadout { CommanderLoadout(kind: selected, skillLevels: skillLevels(selected)) }
}
