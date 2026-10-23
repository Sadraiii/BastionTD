import Foundation

/// Optional rules that make a match harder in exchange for extra Research Points.
enum Modifier: String, CaseIterable, Codable, Identifiable {
    case noFire, fastVillains, halfGold, ironCrystal, noPowers, hardMode, night, swarm, noBreaks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noFire: "No Fire"
        case .fastVillains: "Fast Villains"
        case .halfGold: "Half Gold"
        case .ironCrystal: "Iron Crystal"
        case .noPowers: "No Powers"
        case .hardMode: "Hard Mode"
        case .night: "Night"
        case .swarm: "Swarm"
        case .noBreaks: "No Breaks"
        }
    }

    var detail: String {
        switch self {
        case .noFire: "Fire heroes can't be recruited."
        case .fastVillains: "Villains move 50% faster."
        case .halfGold: "Villains drop half the gold."
        case .ironCrystal: "The crystal has a single life."
        case .noPowers: "Hero powers are switched off."
        case .hardMode: "One life, no selling and no bonus gold."
        case .night: "All villains but bosses are cloaked until revealed."
        case .swarm: "50% more villains, each one weaker."
        case .noBreaks: "4 seconds between waves instead of 12."
        }
    }

    /// Extra Research Points, in percent.
    var bonus: Int {
        switch self {
        case .noFire: 15
        case .fastVillains: 30
        case .halfGold: 30
        case .ironCrystal: 50
        case .noPowers: 25
        case .hardMode: 100
        case .night: 40
        case .swarm: 25
        case .noBreaks: 20
        }
    }
}

/// The rules a match is played with, besides the map.
struct MatchSetup: Codable, Equatable {
    var modifiers: Set<Modifier> = []
    /// The only heroes allowed, for daily challenges and expeditions. Nil allows every recruited hero.
    var heroPool: Set<TowerKind>?
    var seed: UInt64 = 0x5EED
    /// The daily challenge's date, such as 20261018.
    var day: Int?
    var commander: CommanderLoadout?
    /// The Boss Rush event: ten waves of tougher bosses on the Arena map.
    var bossRush = false
    /// An expedition: a random map and squad, boons from wave 3 and no victory, only Endless.
    var expedition: Bool?
    /// Lone Commander: ten waves on the Courtyard with no heroes, only the commander.
    var lone: Bool?

    /// Daily challenges and events don't count toward map progress.
    var isEvent: Bool { day != nil || bossRush || expedition == true || lone == true }

    var bonusPercent: Int { modifiers.reduce(0) { $0 + $1.bonus } }

    /// The challenge for a date: a map, two modifiers and four heroes, one of which can see cloaked villains.
    static func daily(for date: Date) -> (map: MapDefinition, setup: MatchSetup) {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let day = parts.year! * 10000 + parts.month! * 100 + parts.day!
        var rng = SplitMix64(seed: UInt64(day))
        let map = MapDefinition.all.randomElement(using: &rng)!
        let modifiers = [Modifier.noFire, .fastVillains, .halfGold, .noPowers].shuffled(using: &rng).prefix(2)
        let land = TowerKind.allCases.filter { !$0.isNaval }
        let spotter = land.filter(\.baseStats.detectsCamo).randomElement(using: &rng)!
        let others = land.filter { $0 != spotter }.shuffled(using: &rng).prefix(3)
        let setup = MatchSetup(modifiers: Set(modifiers), heroPool: Set(others + [spotter]), seed: UInt64(day), day: day)
        return (map, setup)
    }

    /// An expedition: one of `maps` and three of the recruited `heroes`, one of which can see cloaked villains.
    static func expedition(seed: UInt64, maps: [MapDefinition], heroes: [TowerKind]) -> (map: MapDefinition, setup: MatchSetup) {
        var rng = SplitMix64(seed: seed)
        let map = maps.randomElement(using: &rng)!
        let land = heroes.filter { !$0.isNaval }
        // Vanguard is a starter, so there is always a spotter.
        let spotter = land.filter(\.baseStats.detectsCamo).randomElement(using: &rng)!
        let others = land.filter { $0 != spotter }.shuffled(using: &rng).prefix(2)
        return (map, MatchSetup(heroPool: Set(others + [spotter]), seed: seed, expedition: true))
    }
}
