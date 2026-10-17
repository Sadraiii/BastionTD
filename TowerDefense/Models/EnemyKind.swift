import Foundation

/// A periodic special move. Villains combine these, so new villains are mostly data.
enum VillainAbility: Equatable {
    /// Restores a fraction of max health to wounded allies nearby.
    case heal(radius: Double, fraction: Double)
    /// Spawns extra enemies at the villain's position.
    case summon(EnemyKind, count: Int)
    /// Gives nearby allies a damage-absorbing shield (fraction of their max health).
    case shieldAllies(radius: Double, fraction: Double)
    /// EMP that knocks nearby towers offline.
    case disruptTowers(radius: Double, duration: Double)
}

/// Every villain in the game. To add one: add a case, fill in its stats and
/// traits below, draw its sprite in `SpriteMaps.enemyFrames`, and use it in a wave.
enum EnemyKind: String, CaseIterable, Codable {
    case drone, runner, brute, medic, wisp, splitter, shardling, berserker, phantom, hexer, titan, overlord

    var name: String {
        switch self {
        case .drone: "Drone"
        case .runner: "Skitter"
        case .brute: "Bulwark"
        case .medic: "Mender"
        case .wisp: "Wisp"
        case .splitter: "Splitter"
        case .shardling: "Shard"
        case .berserker: "Berserker"
        case .phantom: "Phantom"
        case .hexer: "Hexer"
        case .titan: "Titan"
        case .overlord: "Overlord"
        }
    }

    /// Short description of the villain's trait, used in the codex and wave banners.
    var ability: String {
        switch self {
        case .drone: "Standard minion. Nothing special."
        case .runner: "Very fast, but fragile."
        case .brute: "Slow and armored. Weak shots barely scratch it."
        case .medic: "Repairs nearby villains every few seconds."
        case .wisp: "Flies. Quake's boulders can't hit it."
        case .splitter: "Bursts into three Shards when destroyed."
        case .shardling: "Fast fragment of a Splitter."
        case .berserker: "Gets faster the more it's hurt."
        case .phantom: "Cloaked. Only heroes with detection can target it."
        case .hexer: "Wraps nearby villains in magic shields."
        case .titan: "Boss. Heavy armor, resists slows, launches Drones."
        case .overlord: "Final boss. EMP blasts shut down nearby heroes."
        }
    }

    var baseHealth: Double {
        switch self {
        case .drone: 30
        case .runner: 18
        case .brute: 130
        case .medic: 60
        case .wisp: 36
        case .splitter: 80
        case .shardling: 14
        case .berserker: 110
        case .phantom: 45
        case .hexer: 80
        case .titan: 800
        case .overlord: 1500
        }
    }

    /// Movement speed in tiles per second.
    var speed: Double {
        switch self {
        case .drone: 1.15
        case .runner: 2.0
        case .brute: 0.62
        case .medic: 0.95
        case .wisp: 1.35
        case .splitter: 0.9
        case .shardling: 1.7
        case .berserker: 0.8
        case .phantom: 1.3
        case .hexer: 0.85
        case .titan: 0.45
        case .overlord: 0.4
        }
    }

    /// Flat damage reduction per hit (armor-piercing attacks ignore it).
    var armor: Double {
        switch self {
        case .brute: 4
        case .medic, .splitter, .hexer: 1
        case .berserker: 2
        case .titan: 6
        case .overlord: 6
        default: 0
        }
    }

    var bounty: Int {
        switch self {
        case .drone: 4
        case .runner: 3
        case .brute: 10
        case .medic: 8
        case .wisp: 6
        case .splitter: 6
        case .shardling: 1
        case .berserker: 9
        case .phantom: 7
        case .hexer: 10
        case .titan: 120
        case .overlord: 300
        }
    }

    /// Lives lost when this villain reaches the crystal.
    var livesCost: Int {
        switch self {
        case .brute, .splitter, .berserker: 2
        case .titan: 5
        case .overlord: 15
        default: 1
        }
    }

    var isFlying: Bool { self == .wisp }

    /// Cloaked: only towers with detection can target it.
    var isCamo: Bool { self == .phantom }

    var isBoss: Bool { self == .titan || self == .overlord }

    /// Fraction of incoming slow that is ignored.
    var slowResistance: Double {
        switch self {
        case .titan: 0.6
        case .overlord: 0.7
        default: 0
        }
    }

    /// Fraction of stun and freeze time that is ignored.
    var stunResistance: Double {
        switch self {
        case .brute: 0.3
        case .titan: 0.6
        case .overlord: 0.8
        default: 0
        }
    }

    /// Moves faster as it loses health (up to this much extra speed).
    var enrageBonus: Double { self == .berserker ? 1.3 : 0 }

    /// What it breaks into when destroyed.
    var splitsInto: (kind: EnemyKind, count: Int)? {
        self == .splitter ? (.shardling, 3) : nil
    }

    var abilities: [VillainAbility] {
        switch self {
        case .medic: [.heal(radius: 1.6, fraction: 0.1)]
        case .hexer: [.shieldAllies(radius: 1.8, fraction: 0.15)]
        case .titan: [.summon(.drone, count: 2)]
        case .overlord: [.disruptTowers(radius: 2.0, duration: 1.5), .summon(.phantom, count: 2)]
        default: []
        }
    }

    /// Seconds between ability uses.
    var abilityInterval: Double {
        switch self {
        case .medic: 2.5
        case .hexer: 5
        case .titan: 7
        case .overlord: 8
        default: 0
        }
    }

    /// Body radius in tiles, used for hit tests.
    var radius: Double {
        switch self {
        case .drone: 0.22
        case .runner: 0.19
        case .brute: 0.3
        case .medic: 0.24
        case .wisp: 0.23
        case .splitter: 0.27
        case .shardling: 0.15
        case .berserker: 0.28
        case .phantom: 0.23
        case .hexer: 0.25
        case .titan: 0.42
        case .overlord: 0.45
        }
    }

    /// Villains worth showing in the codex (shards only appear from Splitters).
    static var codex: [EnemyKind] { allCases.filter { $0 != .shardling } }
}
