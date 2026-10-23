import Foundation

/// What happened in a finished run, used to check medals.
struct RunSummary {
    let map: MapDefinition
    let victory: Bool
    let wavesCleared: Int
    let livesLost: Int
    let stats: GameStats
    let towerCount: Int
    let highestTier: Int
}

/// Achievements that reward Research Points. Each is earned once.
enum Medal: String, CaseIterable, Identifiable {
    case firstStand, flawless, mapMaster, powerPlayer, ascended, titanSlayer, overthrown
    case endless25, endless30, hardHero, fewHeroes, researcher, fullRoster, skyGuard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstStand: "First Stand"
        case .flawless: "Flawless"
        case .mapMaster: "Map Master"
        case .powerPlayer: "Power Player"
        case .ascended: "Ascended"
        case .titanSlayer: "Titan Slayer"
        case .overthrown: "Overthrown"
        case .endless25: "Endless I"
        case .endless30: "Endless II"
        case .hardHero: "Overload Hero"
        case .fewHeroes: "Elite Squad"
        case .researcher: "Mad Scientist"
        case .fullRoster: "Full Roster"
        case .skyGuard: "Sky Guard"
        }
    }

    var detail: String {
        switch self {
        case .firstStand: "Win any map."
        case .flawless: "Win a map without losing a life."
        case .mapMaster: "Earn 3 stars on every map."
        case .powerPlayer: "Use 10 hero powers in one match."
        case .ascended: "Buy a tier 4 upgrade."
        case .titanSlayer: "Defeat a Titan."
        case .overthrown: "Defeat the Overlord."
        case .endless25: "Reach wave 25 in Endless."
        case .endless30: "Reach wave 30 in Endless."
        case .hardHero: "Beat the Overload map."
        case .fewHeroes: "Win with 6 heroes or fewer on the field."
        case .researcher: "Research 10 upgrade tiers."
        case .fullRoster: "Recruit all \(TowerKind.allCases.count) heroes."
        case .skyGuard: "Shoot down the Dreadnought."
        }
    }

    var reward: Int {
        switch self {
        case .firstStand, .powerPlayer, .titanSlayer: 5
        case .ascended, .overthrown, .endless25, .researcher: 10
        case .flawless, .fewHeroes: 15
        case .endless30, .hardHero, .fullRoster: 20
        case .skyGuard: 10
        case .mapMaster: 25
        }
    }

    /// Whether a finished run (plus saved progress) earns this medal.
    func isEarned(by run: RunSummary, research: ResearchState) -> Bool {
        switch self {
        case .firstStand: run.victory
        case .flawless: run.victory && run.livesLost == 0
        case .mapMaster: MapDefinition.all.allSatisfy { PlayerProgress.bestStars(for: $0) == 3 }
        case .powerPlayer: run.stats.powersUsed >= 10
        case .ascended: run.highestTier >= UpgradeRules.maxTier
        case .titanSlayer: run.stats.kills[.titan, default: 0] > 0
        case .overthrown: run.stats.kills[.overlord, default: 0] > 0
        case .endless25: run.wavesCleared >= 25
        case .endless30: run.wavesCleared >= 30
        case .hardHero: run.victory && run.map.difficulty == .hard
        case .fewHeroes: run.victory && run.towerCount <= 6 && run.map != .courtyard
        case .researcher: Self.researchedTiers(research) >= 10
        case .fullRoster: TowerKind.allCases.allSatisfy(research.isHeroUnlocked)
        case .skyGuard: run.stats.kills[.dreadnought, default: 0] > 0
        }
    }

    static func researchedTiers(_ research: ResearchState) -> Int {
        TowerKind.allCases.reduce(0) { total, kind in
            total + (0..<UpgradeRules.pathCount).reduce(0) { $0 + research.unlockedTier(kind, path: $1) - 1 }
        }
    }
}
