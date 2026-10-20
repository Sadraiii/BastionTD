import Foundation

/// A bonus picked in Endless after every third wave. It lasts for the rest of the run.
enum Boon: Equatable {
    case gold, lives, haste, power(DamageType), discount, slowVillains, interest, recharge, veteran, reach

    var title: String {
        switch self {
        case .gold: "+200 Gold"
        case .lives: "+5 Lives"
        case .haste: "Faster Heroes"
        case let .power(type): "\(type.title) Damage"
        case .discount: "Cheaper Upgrades"
        case .slowVillains: "Slower Villains"
        case .interest: "Interest"
        case .recharge: "Faster Powers"
        case .veteran: "Commander Level"
        case .reach: "Wide Combos"
        }
    }

    var detail: String {
        switch self {
        case .gold: "Take 200 gold now."
        case .lives: "The crystal gets 5 more lives."
        case .haste: "Heroes attack 10% faster."
        case let .power(type): "\(type.title) attacks deal 20% more damage."
        case .discount: "Upgrades cost 10% less."
        case .slowVillains: "Villains walk 10% slower."
        case .interest: "After each wave, earn 10% of your gold, up to 50."
        case .recharge: "Hero powers recharge 15% faster."
        case .veteran: "Your commander goes up a level."
        case .reach: "Combos work between heroes up to two tiles apart."
        }
    }

    /// How many times one run can take it.
    var limit: Int {
        switch self {
        case .gold, .lives: Int.max
        case .reach: 1
        case .haste, .power, .discount, .slowVillains, .interest, .recharge, .veteran: 3
        }
    }

    /// Up to three different boons for the break after `wave`. Damage boons only come for types
    /// the heroes on the field deal, faster powers only while powers are on, and a commander level
    /// only while the commander can still level up.
    static func offer(seed: UInt64, wave: Int, taken: [Boon], types: [DamageType], powers: Bool, canLevel: Bool) -> [Boon] {
        var rng = SplitMix64(seed: seed &+ UInt64(wave) &* 0x9E37_79B9)
        var pool: [Boon] = [.gold, .lives, .haste, .discount, .slowVillains, .interest, .reach]
        if powers { pool.append(.recharge) }
        pool += types.map(Boon.power)
        if canLevel { pool.append(.veteran) }
        let open = pool.filter { boon in taken.filter { $0 == boon }.count < boon.limit }
        return Array(open.shuffled(using: &rng).prefix(3))
    }
}
