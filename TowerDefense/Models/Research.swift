import Foundation

/// Which upgrade tiers the player has unlocked in the Research Lab.
/// Tier 1 of every path is always available; tiers 2-4 are researched in order.
struct ResearchState: Codable, Equatable {
    private var unlocked: [String: Int] = [:]
    private var heroes: Set<String> = []

    func isHeroUnlocked(_ kind: TowerKind) -> Bool {
        kind.unlockCost == 0 || heroes.contains(kind.rawValue)
    }

    mutating func unlockHero(_ kind: TowerKind) {
        heroes.insert(kind.rawValue)
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlocked = try container.decodeIfPresent([String: Int].self, forKey: .unlocked) ?? [:]
        heroes = try container.decodeIfPresent(Set<String>.self, forKey: .heroes) ?? []
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
