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
    /// Turns to stone and ignores all damage for a while.
    case stoneForm(duration: Double)
    /// Blinks forward along the path.
    case teleport(distance: Double)
    /// Digs underground: stands still and ignores all damage for a while.
    case burrow(duration: Double)
    /// Hides nearby allies from heroes without detection.
    case cloakAllies(radius: Double, duration: Double)
}

/// Every villain in the game. To add one: add a case, fill in its stats and
/// traits below, draw its sprite in `SpriteMaps.enemyFrames`, give it a color in
/// `Pal.enemy`, and use it in a wave.
enum EnemyKind: String, CaseIterable, Codable {
    case drone, runner, brute, medic, wisp, splitter, shardling, berserker, phantom, hexer
    case ironclad, pyrefiend, frostborn, voidling, blastguard, husk, mirage, gargoyle, warper
    case titan, dreadnought, overlord
    case sandworm, yeti, magmaGolem, lavaBlob, bogWitch, crab, caveBat
    case sapper, pickpocket, chameleon, gravecaller, shade

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
        case .ironclad: "Ironclad"
        case .pyrefiend: "Pyrefiend"
        case .frostborn: "Frostborn"
        case .voidling: "Voidling"
        case .blastguard: "Blastguard"
        case .husk: "Husk"
        case .mirage: "Mirage"
        case .gargoyle: "Gargoyle"
        case .warper: "Warper"
        case .titan: "Titan"
        case .dreadnought: "Dreadnought"
        case .overlord: "Overlord"
        case .sandworm: "Sandworm"
        case .yeti: "Yeti"
        case .magmaGolem: "Magma Golem"
        case .lavaBlob: "Lava Blob"
        case .bogWitch: "Bog Witch"
        case .crab: "Crab"
        case .caveBat: "Cave Bat"
        case .sapper: "Sapper"
        case .pickpocket: "Pickpocket"
        case .chameleon: "Chameleon"
        case .gravecaller: "Gravecaller"
        case .shade: "Shade"
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
        case .hexer: "Wraps nearby villains in magic shields. Echo cracks them."
        case .ironclad: "Kinetic attacks bounce off. Use fire, energy or explosives."
        case .pyrefiend: "Immune to fire. Cold hits it twice as hard."
        case .frostborn: "Immune to cold and can't be slowed or frozen. Weak to fire."
        case .voidling: "Swallows energy attacks. Use kinetic or explosive heroes."
        case .blastguard: "Bomb-proof suit: immune to explosives."
        case .husk: "Mindless: immune to psychic and toxic attacks."
        case .mirage: "Flies AND is cloaked. Needs detection that hits air."
        case .gargoyle: "Flies, and turns to stone to ignore all damage."
        case .warper: "Teleports forward along the path."
        case .titan: "Boss. Heavy armor, resists slows, launches Drones."
        case .dreadnought: "Flying boss airship. Can't be slowed. Drops Ironclads."
        case .overlord: "Final boss. EMP blasts shut down nearby heroes."
        case .sandworm: "Burrows underground now and then to dodge hits."
        case .yeti: "Freezes nearby heroes for a moment. Immune to cold."
        case .magmaGolem: "Splits into lava blobs. Immune to fire."
        case .lavaBlob: "Hot leftovers of a Magma Golem."
        case .bogWitch: "Heals nearby villains and hides them from heroes."
        case .crab: "Thick shell. Explosives crack it."
        case .caveBat: "Fast flying swarm."
        case .sapper: "Blows up when defeated and knocks nearby heroes out for 3s."
        case .pickpocket: "Steals gold instead of lives if it gets through."
        case .chameleon: "After each hit it ignores that damage type for 1.5s. Burning and poison still hurt it."
        case .gravecaller: "Villains that fall near it rise again as Shades."
        case .shade: "A risen villain. Fast and flying."
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
        case .ironclad: 90
        case .pyrefiend: 70
        case .frostborn: 120
        case .voidling: 60
        case .blastguard: 100
        case .husk: 85
        case .mirage: 50
        case .gargoyle: 140
        case .warper: 70
        case .titan: 800
        case .dreadnought: 950
        case .overlord: 1300
        case .sandworm: 90
        case .yeti: 160
        case .magmaGolem: 180
        case .lavaBlob: 22
        case .bogWitch: 75
        case .crab: 120
        case .caveBat: 20
        case .sapper: 70
        case .pickpocket: 40
        case .chameleon: 90
        case .gravecaller: 110
        case .shade: 20
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
        case .ironclad: 0.9
        case .pyrefiend: 1.15
        case .frostborn: 0.8
        case .voidling: 1.2
        case .blastguard: 0.85
        case .husk: 0.75
        case .mirage: 1.4
        case .gargoyle: 0.9
        case .warper: 0.9
        case .titan: 0.45
        case .dreadnought: 0.42
        case .overlord: 0.4
        case .sandworm: 1.0
        case .yeti: 0.75
        case .magmaGolem: 0.7
        case .lavaBlob: 1.5
        case .bogWitch: 0.85
        case .crab: 0.85
        case .caveBat: 2.3
        case .sapper: 1.0
        case .pickpocket: 1.8
        case .chameleon: 0.95
        case .gravecaller: 0.8
        case .shade: 1.6
        }
    }

    /// Flat damage reduction per hit (armor-piercing attacks ignore it).
    var armor: Double {
        switch self {
        case .brute: 4
        case .medic, .splitter, .hexer, .bogWitch, .sapper, .chameleon: 1
        case .berserker, .ironclad, .frostborn, .yeti, .gravecaller: 2
        case .crab: 5
        case .magmaGolem: 3
        case .blastguard: 3
        case .gargoyle: 4
        case .titan, .overlord: 6
        case .dreadnought: 6
        default: 0
        }
    }

    /// Damage types that do nothing to this villain.
    var immunities: Set<DamageType> {
        switch self {
        case .ironclad: [.kinetic]
        case .pyrefiend: [.fire]
        case .frostborn, .yeti: [.cold]
        case .magmaGolem, .lavaBlob: [.fire]
        case .voidling: [.energy]
        case .blastguard: [.explosive]
        case .husk: [.psychic, .toxic]
        default: []
        }
    }

    /// Damage types that hit this villain twice as hard.
    var weaknesses: Set<DamageType> {
        switch self {
        case .pyrefiend, .magmaGolem, .lavaBlob: [.cold]
        case .frostborn, .yeti: [.fire]
        case .crab: [.explosive]
        case .ironclad: [.sonic]
        default: []
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
        case .ironclad: 8
        case .pyrefiend: 7
        case .frostborn: 9
        case .voidling: 7
        case .blastguard: 9
        case .husk: 7
        case .mirage: 9
        case .gargoyle: 12
        case .warper: 9
        case .titan: 120
        case .dreadnought: 200
        case .overlord: 300
        case .sandworm: 8
        case .yeti: 11
        case .magmaGolem: 12
        case .lavaBlob: 2
        case .bogWitch: 11
        case .crab: 9
        case .caveBat: 2
        case .sapper: 9
        case .pickpocket: 15
        case .chameleon: 10
        case .gravecaller: 12
        case .shade: 1
        }
    }

    /// Lives lost when this villain reaches the crystal.
    var livesCost: Int {
        switch self {
        case .brute, .splitter, .berserker, .frostborn, .blastguard, .gargoyle, .yeti, .magmaGolem, .gravecaller: 2
        case .pickpocket: 0
        case .titan: 5
        case .dreadnought: 8
        case .overlord: 15
        default: 1
        }
    }

    var isFlying: Bool {
        switch self {
        case .wisp, .mirage, .gargoyle, .dreadnought, .caveBat, .shade: true
        default: false
        }
    }

    /// Cloaked: only towers with detection can target it.
    var isCamo: Bool { self == .phantom || self == .mirage }

    var isBoss: Bool { self == .titan || self == .dreadnought || self == .overlord }

    /// Fraction of incoming slow that is ignored.
    var slowResistance: Double {
        switch self {
        case .frostborn, .dreadnought: 1
        case .titan: 0.6
        case .overlord: 0.7
        case .yeti: 0.5
        default: 0
        }
    }

    /// Fraction of stun and freeze time that is ignored.
    var stunResistance: Double {
        switch self {
        case .frostborn, .dreadnought: 1
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
        switch self {
        case .splitter: (.shardling, 3)
        case .dreadnought: (.ironclad, 4)
        case .magmaGolem: (.lavaBlob, 3)
        default: nil
        }
    }

    var abilities: [VillainAbility] {
        switch self {
        case .medic: [.heal(radius: 1.6, fraction: 0.1)]
        case .hexer: [.shieldAllies(radius: 1.8, fraction: 0.15)]
        case .gargoyle: [.stoneForm(duration: 2)]
        case .warper: [.teleport(distance: 2)]
        case .titan: [.summon(.drone, count: 2)]
        case .overlord: [.disruptTowers(radius: 2.0, duration: 1.5), .summon(.phantom, count: 2)]
        case .sandworm: [.burrow(duration: 2)]
        case .yeti: [.disruptTowers(radius: 1.4, duration: 1.2)]
        case .bogWitch: [.heal(radius: 1.6, fraction: 0.08), .cloakAllies(radius: 1.6, duration: 3)]
        default: []
        }
    }

    /// Seconds between ability uses.
    var abilityInterval: Double {
        switch self {
        case .medic: 2.5
        case .hexer: 5
        case .gargoyle: 7
        case .warper: 4
        case .titan: 7
        case .overlord: 8
        case .sandworm: 5
        case .yeti: 6
        case .bogWitch: 4
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
        case .ironclad, .frostborn, .blastguard: 0.26
        case .pyrefiend, .voidling, .husk, .warper: 0.23
        case .mirage: 0.24
        case .gargoyle: 0.27
        case .titan: 0.42
        case .dreadnought: 0.5
        case .overlord: 0.45
        case .sandworm, .bogWitch: 0.25
        case .yeti, .magmaGolem: 0.29
        case .lavaBlob, .caveBat: 0.17
        case .crab: 0.27
        case .sapper: 0.24
        case .pickpocket: 0.2
        case .chameleon: 0.25
        case .gravecaller: 0.26
        case .shade: 0.18
        }
    }

    /// Short tags for the codex and wave banners.
    var traitTags: [String] {
        var tags: [String] = []
        if isBoss { tags.append("BOSS") }
        if isFlying { tags.append("FLYING") }
        if isCamo { tags.append("CLOAKED") }
        if armor >= 3 { tags.append("ARMORED") }
        if !immunities.isEmpty {
            tags.append("IMMUNE: " + immunities.map { $0.title.uppercased() }.sorted().joined(separator: "/"))
        }
        return tags
    }

    /// Villains worth showing in the codex (shards only appear from Splitters).
    static var codex: [EnemyKind] { allCases.filter { $0 != .shardling && $0 != .lavaBlob && $0 != .shade } }
}
