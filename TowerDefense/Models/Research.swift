import Foundation

/// Permanent bonuses bought in the Research Lab.
enum Perk: String, CaseIterable, Identifiable {
    case richStart, sturdyCrystal, cheapUpgrades, bounty, quickPowers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .richStart: "Rich Start"
        case .sturdyCrystal: "Sturdy Crystal"
        case .cheapUpgrades: "Bulk Deals"
        case .bounty: "Bounty"
        case .quickPowers: "Quick Powers"
        }
    }

    var detail: String {
        switch self {
        case .richStart: "Start every match with 50 more gold."
        case .sturdyCrystal: "The crystal has 5 more lives."
        case .cheapUpgrades: "Upgrades cost 10% less."
        case .bounty: "Villains drop 10% more gold."
        case .quickPowers: "Hero powers recharge 15% faster."
        }
    }

    var cost: Int {
        switch self {
        case .richStart, .sturdyCrystal: 10
        case .quickPowers: 12
        case .cheapUpgrades, .bounty: 15
        }
    }
}

/// Which upgrade tiers the player has unlocked in the Research Lab.
/// Tier 1 of every path is always available; tiers 2-4 are researched in order.
struct ResearchState: Codable, Equatable {
    /// Waves a hero must have stayed on the field, over all matches, for each mastery star.
    static let masteryThresholds = [20, 60, 150, 400, 1000]

    private var unlocked: [String: Int] = [:]
    private var heroes: Set<String> = []
    private var perks: Set<String> = []
    /// Waves each hero has stayed on the field, for mastery. Kept here so a saved match replays with the stars it began with.
    private var heroWaves: [String: Int] = [:]

    func isHeroUnlocked(_ kind: TowerKind) -> Bool {
        kind.unlockCost == 0 || heroes.contains(kind.rawValue)
    }

    mutating func unlockHero(_ kind: TowerKind) {
        heroes.insert(kind.rawValue)
    }

    func has(_ perk: Perk) -> Bool { perks.contains(perk.rawValue) }

    mutating func unlock(_ perk: Perk) {
        perks.insert(perk.rawValue)
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlocked = try container.decodeIfPresent([String: Int].self, forKey: .unlocked) ?? [:]
        heroes = try container.decodeIfPresent(Set<String>.self, forKey: .heroes) ?? []
        perks = try container.decodeIfPresent(Set<String>.self, forKey: .perks) ?? []
        heroWaves = try container.decodeIfPresent([String: Int].self, forKey: .heroWaves) ?? [:]
    }

    private static func key(_ kind: TowerKind, _ path: Int) -> String { "\(kind.rawValue).\(path)" }

    /// Highest tier that may be bought in a match.
    func unlockedTier(_ kind: TowerKind, path: Int) -> Int {
        max(1, unlocked[Self.key(kind, path)] ?? 1)
    }

    func isUnlocked(_ kind: TowerKind, path: Int, tier: Int) -> Bool {
        tier <= unlockedTier(kind, path: path)
    }

    /// The next tier that can be researched on a path, if any.
    func nextResearchable(_ kind: TowerKind, path: Int) -> Int? {
        let next = unlockedTier(kind, path: path) + 1
        return next <= UpgradeRules.maxTier ? next : nil
    }

    mutating func unlock(_ kind: TowerKind, path: Int, tier: Int) {
        unlocked[Self.key(kind, path)] = max(unlockedTier(kind, path: path), tier)
    }

    func wavesOnField(_ kind: TowerKind) -> Int { heroWaves[kind.rawValue] ?? 0 }

    /// Each star adds 2% damage to the hero.
    func masteryStars(_ kind: TowerKind) -> Int {
        Self.masteryThresholds.filter { wavesOnField(kind) >= $0 }.count
    }

    mutating func addHeroWaves(_ kind: TowerKind, _ count: Int) {
        heroWaves[kind.rawValue, default: 0] += count
    }

    /// Everything researched (used by the balance simulation).
    static var complete: ResearchState {
        var state = ResearchState()
        for kind in TowerKind.allCases {
            state.unlockHero(kind)
            for path in 0..<UpgradeRules.pathCount { state.unlock(kind, path: path, tier: UpgradeRules.maxTier) }
        }
        return state
    }
}

/// Research Points earned at the end of a match.
enum ResearchRewards {
    static let startingPoints = 12

    static func points(for map: MapDefinition, wavesCleared: Int, victory: Bool, stars: Int) -> Int {
        let perWave: Double = switch map.difficulty {
        case .easy: 1
        case .normal: 1.5
        case .hard: 2
        }
        let victoryBonus: Int = switch map.difficulty {
        case .easy: 10
        case .normal: 15
        case .hard: 20
        }
        let base = Int((Double(wavesCleared) * perWave).rounded())
        return victory ? base + victoryBonus + stars * 2 : base
    }
}
