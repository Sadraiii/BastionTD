import Foundation

/// Optional rules that make a match harder in exchange for extra Research Points.
enum Modifier: String, CaseIterable, Codable, Identifiable {
    case noFire, fastVillains, halfGold, ironCrystal, noPowers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noFire: "No Fire"
        case .fastVillains: "Fast Villains"
        case .halfGold: "Half Gold"
        case .ironCrystal: "Iron Crystal"
        case .noPowers: "No Powers"
        }
    }

    var detail: String {
        switch self {
        case .noFire: "Fire heroes can't be recruited."
        case .fastVillains: "Villains move 50% faster."
        case .halfGold: "Villains drop half the gold."
        case .ironCrystal: "The crystal has a single life."
        case .noPowers: "Hero powers are switched off."
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
        }
    }
}

/// The rules a match is played with, besides the map.
struct MatchSetup: Codable, Equatable {
    var modifiers: Set<Modifier> = []

    var bonusPercent: Int { modifiers.reduce(0) { $0 + $1.bonus } }
}
