import Foundation

/// UserDefaults keys shared with SwiftUI's `@AppStorage`.
enum StorageKey {
    static let soundEnabled = "settings.sound"
    static let hapticsEnabled = "settings.haptics"
    static let onboardingSeen = "progress.onboardingSeen"
    static let coachCompleted = "progress.coachCompleted"
    static let researchPoints = "progress.researchPoints"
    static let researchState = "progress.research"
    static let medals = "progress.medals"
    static let savedMatch = "progress.savedMatch"
    static let commander = "progress.commander"
    static func commanderXP(_ kind: CommanderKind) -> String { "progress.commanderXP.\(kind.rawValue)" }
    static func commanderSkin(_ kind: CommanderKind) -> String { "progress.commanderSkin.\(kind.rawValue)" }
    static func bestStars(_ mapID: String) -> String { "progress.stars.\(mapID)" }
    static func bestEndless(_ mapID: String) -> String { "progress.endless.\(mapID)" }
    static func daily(_ day: Int) -> String { "progress.daily.\(day)" }
    static let bossRush = "progress.bossRush"
    static let combos = "progress.combos"
}

/// Persistent settings and campaign progress.
enum PlayerProgress {
    private static var defaults: UserDefaults { .standard }

    static var soundEnabled: Bool {
        defaults.object(forKey: StorageKey.soundEnabled) as? Bool ?? true
    }

    static var hapticsEnabled: Bool {
        defaults.object(forKey: StorageKey.hapticsEnabled) as? Bool ?? true
    }

    static var coachCompleted: Bool {
        get { defaults.bool(forKey: StorageKey.coachCompleted) }
        set { defaults.set(newValue, forKey: StorageKey.coachCompleted) }
    }

    static func bestStars(for map: MapDefinition) -> Int {
        defaults.integer(forKey: StorageKey.bestStars(map.id))
    }

    static func recordVictory(on map: MapDefinition, stars: Int) {
        if stars > bestStars(for: map) {
            defaults.set(stars, forKey: StorageKey.bestStars(map.id))
        }
    }

    /// The match in progress, kept so it can be resumed after the app is closed.
    static var savedMatch: SavedMatch? {
        get { defaults.data(forKey: StorageKey.savedMatch).flatMap { try? JSONDecoder().decode(SavedMatch.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: StorageKey.savedMatch) }
    }

    static var commander: CommanderProgress {
        get { defaults.data(forKey: StorageKey.commander).flatMap { try? JSONDecoder().decode(CommanderProgress.self, from: $0) } ?? CommanderProgress() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: StorageKey.commander) }
    }

    /// The selected commander with its skills and permanent rank, for the next match.
    static var commanderLoadout: CommanderLoadout {
        var loadout = commander.loadout
        loadout.rank = CommanderKind.rank(forXP: commanderXP(loadout.kind))
        loadout.skin = commanderSkin(loadout.kind)
        return loadout
    }

    static func commanderSkin(_ kind: CommanderKind) -> CommanderSkin {
        CommanderSkin(rawValue: defaults.integer(forKey: StorageKey.commanderSkin(kind))) ?? .classic
    }

    static func setCommanderSkin(_ skin: CommanderSkin, for kind: CommanderKind) {
        defaults.set(skin.rawValue, forKey: StorageKey.commanderSkin(kind))
    }

    static func commanderXP(_ kind: CommanderKind) -> Int {
        defaults.integer(forKey: StorageKey.commanderXP(kind))
    }

    static func addCommanderXP(_ kind: CommanderKind, _ amount: Int) {
        defaults.set(commanderXP(kind) + amount, forKey: StorageKey.commanderXP(kind))
    }

    /// Spends points to raise a commander skill one level. Returns false if not possible.
    static func upgradeSkill(_ kind: CommanderKind, skill: Int) -> Bool {
        var progress = commander
        var levels = progress.skillLevels(kind)
        let next = levels[skill] + 1
        let cost = CommanderSkill.cost(level: next)
        guard next <= CommanderSkill.maxLevel, researchPoints >= cost else { return false }
        researchPoints -= cost
        levels[skill] = next
        progress.levels[kind] = levels
        commander = progress
        return true
    }

    // MARK: Research

    /// Unspent Research Points. New players start with a few to try the lab.
    static var researchPoints: Int {
        get { defaults.object(forKey: StorageKey.researchPoints) as? Int ?? ResearchRewards.startingPoints }
        set { defaults.set(newValue, forKey: StorageKey.researchPoints) }
    }

    static var research: ResearchState {
        get {
            guard let data = defaults.data(forKey: StorageKey.researchState),
                  let state = try? JSONDecoder().decode(ResearchState.self, from: data) else { return ResearchState() }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: StorageKey.researchState) }
        }
    }

    /// Spends points to unlock the next tier on a path. Returns false if not possible.
    @discardableResult
    static func research(_ kind: TowerKind, path: Int) -> Bool {
        var state = research
        guard let tier = state.nextResearchable(kind, path: path) else { return false }
        let cost = kind.paths[path].tiers[tier - 1].research
        guard researchPoints >= cost else { return false }
        researchPoints -= cost
        state.unlock(kind, path: path, tier: tier)
        research = state
        return true
    }

    /// Spends points to recruit a new hero. Returns false if not possible.
    @discardableResult
    static func unlockHero(_ kind: TowerKind) -> Bool {
        var state = research
        guard !state.isHeroUnlocked(kind), researchPoints >= kind.unlockCost else { return false }
        researchPoints -= kind.unlockCost
        state.unlockHero(kind)
        research = state
        return true
    }

    static func buyPerk(_ perk: Perk) -> Bool {
        var state = research
        guard !state.has(perk), researchPoints >= perk.cost else { return false }
        researchPoints -= perk.cost
        state.unlock(perk)
        research = state
        return true
    }

    // MARK: Map unlocks and records

    /// Maps unlock in order: beat the previous map to open the next.
    static func isUnlocked(_ map: MapDefinition) -> Bool {
        guard let index = MapDefinition.all.firstIndex(of: map), index > 0 else { return true }
        return bestStars(for: MapDefinition.all[index - 1]) > 0
    }

    static func bestEndlessWave(for map: MapDefinition) -> Int {
        defaults.integer(forKey: StorageKey.bestEndless(map.id))
    }

    /// Most waves cleared in a day's daily challenge.
    static func bestDaily(_ day: Int) -> Int {
        defaults.integer(forKey: StorageKey.daily(day))
    }

    static var bestBossRush: Int { defaults.integer(forKey: StorageKey.bossRush) }

    static func recordBossRush(wavesCleared: Int) {
        if wavesCleared > bestBossRush { defaults.set(wavesCleared, forKey: StorageKey.bossRush) }
    }

    static func recordDaily(_ day: Int, wavesCleared: Int) {
        if wavesCleared > bestDaily(day) {
            defaults.set(wavesCleared, forKey: StorageKey.daily(day))
        }
    }

    static func recordEndless(on map: MapDefinition, wave: Int) {
        if wave > bestEndlessWave(for: map) {
            defaults.set(wave, forKey: StorageKey.bestEndless(map.id))
        }
    }

    // MARK: Medals

    static var earnedMedals: Set<String> {
        Set(defaults.stringArray(forKey: StorageKey.medals) ?? [])
    }

    /// Awards any newly earned medals (and their Research Points). Returns the new ones.
    static func awardMedals(for run: RunSummary?) -> [Medal] {
        var earned = earnedMedals
        let state = research
        let fresh = Medal.allCases.filter { medal in
            guard !earned.contains(medal.id) else { return false }
            if let run { return medal.isEarned(by: run, research: state) }
            return (medal == .researcher && Medal.researchedTiers(state) >= 10)
                || (medal == .fullRoster && TowerKind.allCases.allSatisfy(state.isHeroUnlocked))
        }
        guard !fresh.isEmpty else { return [] }
        for medal in fresh { earned.insert(medal.id) }
        defaults.set(Array(earned), forKey: StorageKey.medals)
        researchPoints += fresh.reduce(0) { $0 + $1.reward }
        return fresh
    }

    // MARK: Combos

    static var discoveredCombos: Set<String> {
        Set(defaults.stringArray(forKey: StorageKey.combos) ?? [])
    }

    /// Remembers a combo for the Codex. Returns true the first time it is found.
    static func discoverCombo(_ name: String) -> Bool {
        var found = discoveredCombos
        guard found.insert(name).inserted else { return false }
        defaults.set(Array(found), forKey: StorageKey.combos)
        return true
    }
}
