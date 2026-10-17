import Foundation

/// What an active hero power does when triggered. Distances scale the tower's range.
enum PowerEffect: Equatable {
    /// Instant blast around the tower: damage, stun and knockback.
    case burst(damage: Double, stun: Double, knockback: Double, rangeScale: Double, groundOnly: Bool)
    /// Temporary attack-speed and damage boost.
    case frenzy(duration: Double, rate: Double, damage: Double)
    /// Lightning from the sky on the toughest enemies in range.
    case strikes(targets: Int, damage: Double, stun: Double, splash: Double, rangeScale: Double)
    /// A lingering zone that damages and slows.
    case field(duration: Double, dps: Double, slow: Double, rangeScale: Double)
    /// A volley of homing missiles.
    case missiles(count: Int, damage: Double, splash: Double)
}

struct PowerDefinition: Equatable {
    let name: String
    let detail: String
    let cooldown: Double
    let effect: PowerEffect
}

/// One purchasable step on an upgrade path.
struct UpgradeTier {
    let name: String
    let detail: String
    /// In-game gold price.
    let cost: Int
    /// Research Points needed to unlock it in the Research Lab (0 = always available).
    let research: Int
    var power: PowerDefinition? = nil
    let apply: (inout TowerStats) -> Void
}

struct UpgradePath {
    let name: String
    let tiers: [UpgradeTier]
}

/// Upgrade paths and powers for every hero. Each path has four tiers; tier 3
/// grants an active power and tier 4 empowers it.
enum HeroCatalog {
    static func paths(for kind: TowerKind) -> [UpgradePath] {
        switch kind {
        case .pulse: blitz
        case .frost: glacia
        case .mortar: quake
        case .tesla: stormbringer
        case .rail: vanguard
        }
    }

    // MARK: Blitz - speedster

    private static let blitz: [UpgradePath] = [
        UpgradePath(name: "Velocity", tiers: [
            UpgradeTier(name: "Quick Hands", detail: "Attacks 33% faster.", cost: 40, research: 0) {
                $0.fireInterval *= 0.75
            },
            UpgradeTier(name: "Afterimage", detail: "Strikes two enemies at once.", cost: 90, research: 4) {
                $0.multishot = 2
            },
            UpgradeTier(name: "Hyperdrive", detail: "POWER: triple attack speed for 5s.", cost: 190, research: 10,
                        power: PowerDefinition(name: "Hyperdrive", detail: "Triple attack speed for 5 seconds.", cooldown: 30,
                                               effect: .frenzy(duration: 5, rate: 3, damage: 1))) {
                $0.damage *= 1.2
            },
            UpgradeTier(name: "Light Barrier", detail: "Three targets, even faster. Hyperdrive lasts 8s at 4x.", cost: 700, research: 20,
                        power: PowerDefinition(name: "Hyperdrive+", detail: "4x attack speed and +50% damage for 8 seconds.", cooldown: 30,
                                               effect: .frenzy(duration: 8, rate: 4, damage: 1.5))) {
                $0.fireInterval *= 0.7
                $0.multishot = 3
            },
        ]),
        UpgradePath(name: "Impact", tiers: [
            UpgradeTier(name: "Heavy Knuckles", detail: "+5 damage per bolt.", cost: 45, research: 0) {
                $0.damage += 5
            },
            UpgradeTier(name: "Sharp Eyes", detail: "More range and spots cloaked villains.", cost: 70, research: 4) {
                $0.range += 0.5
                $0.detectsCamo = true
            },
            UpgradeTier(name: "Sonic Boom", detail: "POWER: shockwave knocks enemies back.", cost: 220, research: 10,
                        power: PowerDefinition(name: "Sonic Boom", detail: "Blast nearby enemies backward and daze them.", cooldown: 25,
                                               effect: .burst(damage: 60, stun: 0.5, knockback: 1.2, rangeScale: 1.1, groundOnly: false))) {
                $0.damage += 8
                $0.pierce = 2
            },
            UpgradeTier(name: "Shockwave Fist", detail: "Bolts ricochet 3 times. Mighty Sonic Boom.", cost: 700, research: 20,
                        power: PowerDefinition(name: "Sonic Boom+", detail: "Huge shockwave: heavy damage, long knockback.", cooldown: 25,
                                               effect: .burst(damage: 220, stun: 1, knockback: 2, rangeScale: 1.3, groundOnly: false))) {
                $0.damage += 20
                $0.pierce = 3
            },
        ]),
    ]

    // MARK: Glacia - ice hero

    private static let glacia: [UpgradePath] = [
        UpgradePath(name: "Permafrost", tiers: [
            UpgradeTier(name: "Deep Chill", detail: "Stronger, longer slow.", cost: 50, research: 0) {
                $0.slow = 0.45
                $0.slowDuration += 0.4
            },
            UpgradeTier(name: "Frostbite", detail: "Pulses may freeze enemies solid.", cost: 110, research: 4) {
                $0.stunChance = 0.15
                $0.stunDuration = 1
            },
            UpgradeTier(name: "Flash Freeze", detail: "POWER: freeze everything nearby.", cost: 200, research: 10,
                        power: PowerDefinition(name: "Flash Freeze", detail: "Freeze all enemies in range for 3 seconds.", cooldown: 30,
                                               effect: .burst(damage: 20, stun: 3, knockback: 0, rangeScale: 1.2, groundOnly: false))) {
                $0.range += 0.3
            },
            UpgradeTier(name: "Absolute Zero", detail: "Brutal slow, frequent freezes. 5s freeze power.", cost: 650, research: 20,
                        power: PowerDefinition(name: "Absolute Zero", detail: "Freeze all enemies in a wide area for 5 seconds.", cooldown: 30,
                                               effect: .burst(damage: 80, stun: 5, knockback: 0, rangeScale: 1.6, groundOnly: false))) {
                $0.slow = 0.6
                $0.stunChance = 0.3
            },
        ]),
        UpgradePath(name: "Hailstorm", tiers: [
            UpgradeTier(name: "Sharp Ice", detail: "+4 damage per pulse.", cost: 60, research: 0) {
                $0.damage += 4
            },
            UpgradeTier(name: "Cold Snap", detail: "Wider field, faster pulses.", cost: 120, research: 4) {
                $0.range += 0.4
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Blizzard", detail: "POWER: a storm that shreds and slows.", cost: 230, research: 10,
                        power: PowerDefinition(name: "Blizzard", detail: "6-second storm: damage over time and a 70% slow.", cooldown: 35,
                                               effect: .field(duration: 6, dps: 40, slow: 0.7, rangeScale: 1.3))) {
                $0.damage += 8
            },
            UpgradeTier(name: "Ice Age", detail: "Massive pulses. Blizzard lasts 8s.", cost: 700, research: 20,
                        power: PowerDefinition(name: "Ice Age", detail: "8-second storm with crushing damage and an 80% slow.", cooldown: 35,
                                               effect: .field(duration: 8, dps: 130, slow: 0.8, rangeScale: 1.5))) {
                $0.damage += 20
                $0.fireInterval *= 0.8
            },
        ]),
    ]

    // MARK: Quake - strongman

    private static let quake: [UpgradePath] = [
        UpgradePath(name: "Seismic", tiers: [
            UpgradeTier(name: "Bigger Boulders", detail: "+10 damage and a wider splash.", cost: 70, research: 0) {
                $0.damage += 10
                $0.splashRadius += 0.25
            },
            UpgradeTier(name: "Aftershock", detail: "Impacts may stun.", cost: 140, research: 4) {
                $0.stunChance = 0.25
                $0.stunDuration = 0.6
            },
            UpgradeTier(name: "Earthshatter", detail: "POWER: ground slam stuns all ground foes.", cost: 250, research: 10,
                        power: PowerDefinition(name: "Earthshatter", detail: "Slam the ground: damage and a 2s stun nearby.", cooldown: 30,
                                               effect: .burst(damage: 120, stun: 2, knockback: 0, rangeScale: 1.2, groundOnly: true))) {
                $0.damage += 15
            },
            UpgradeTier(name: "Tectonic Fury", detail: "Huge blasts, frequent stuns.", cost: 750, research: 20,
                        power: PowerDefinition(name: "Tectonic Fury", detail: "Devastating slam with a 3s stun.", cooldown: 30,
                                               effect: .burst(damage: 400, stun: 3, knockback: 0, rangeScale: 1.4, groundOnly: true))) {
                $0.splashRadius += 0.4
                $0.stunChance = 0.4
                $0.stunDuration = 1
            },
        ]),
        UpgradePath(name: "Fury", tiers: [
            UpgradeTier(name: "Fast Throws", detail: "Throws 25% faster.", cost: 80, research: 0) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Long Arm", detail: "Much longer range.", cost: 110, research: 4) {
                $0.range += 0.8
            },
            UpgradeTier(name: "Rampage", detail: "POWER: throw like crazy for 6s.", cost: 270, research: 10,
                        power: PowerDefinition(name: "Rampage", detail: "2.5x throw speed and +50% damage for 6 seconds.", cooldown: 35,
                                               effect: .frenzy(duration: 6, rate: 2.5, damage: 1.5))) {
                $0.damage += 20
            },
            UpgradeTier(name: "Unstoppable", detail: "Heavier, faster boulders. Rampage lasts 8s.", cost: 800, research: 20,
                        power: PowerDefinition(name: "Rampage+", detail: "3.5x throw speed and double damage for 8 seconds.", cooldown: 35,
                                               effect: .frenzy(duration: 8, rate: 3.5, damage: 2))) {
                $0.damage += 50
                $0.fireInterval *= 0.75
            },
        ]),
    ]

    // MARK: Stormbringer - thunder hero

    private static let stormbringer: [UpgradePath] = [
        UpgradePath(name: "Tempest", tiers: [
            UpgradeTier(name: "Static Charge", detail: "Chains to one more enemy.", cost: 80, research: 0) {
                $0.chainTargets += 1
            },
            UpgradeTier(name: "Storm Sight", detail: "More range and spots cloaked villains.", cost: 120, research: 4) {
                $0.range += 0.4
                $0.detectsCamo = true
            },
            UpgradeTier(name: "Thunderstrike", detail: "POWER: lightning hits 8 foes.", cost: 270, research: 10,
                        power: PowerDefinition(name: "Thunderstrike", detail: "Call lightning on up to 8 enemies, stunning them.", cooldown: 30,
                                               effect: .strikes(targets: 8, damage: 150, stun: 1, splash: 0, rangeScale: 1.5))) {
                $0.chainTargets += 2
            },
            UpgradeTier(name: "Eye of the Storm", detail: "Massive chains. Thunderstrike hits 16.", cost: 750, research: 20,
                        power: PowerDefinition(name: "Eye of the Storm", detail: "Lightning on up to 16 enemies for huge damage.", cooldown: 30,
                                               effect: .strikes(targets: 16, damage: 400, stun: 1.5, splash: 0, rangeScale: 2))) {
                $0.chainTargets += 3
                $0.damage += 15
            },
        ]),
        UpgradePath(name: "Skyhammer", tiers: [
            UpgradeTier(name: "High Voltage", detail: "+8 damage per bolt.", cost: 90, research: 0) {
                $0.damage += 8
            },
            UpgradeTier(name: "Conductor", detail: "Bolts may stun.", cost: 150, research: 4) {
                $0.stunChance = 0.2
                $0.stunDuration = 0.5
            },
            UpgradeTier(name: "Skyhammer", detail: "POWER: a giant bolt crushes the strongest foe.", cost: 290, research: 10,
                        power: PowerDefinition(name: "Skyhammer", detail: "Drop a colossal bolt on the strongest enemy.", cooldown: 25,
                                               effect: .strikes(targets: 1, damage: 800, stun: 2, splash: 0.8, rangeScale: 1.5))) {
                $0.damage += 16
            },
            UpgradeTier(name: "Godspark", detail: "Searing bolts. Skyhammer hits 3x harder.", cost: 800, research: 20,
                        power: PowerDefinition(name: "Godspark", detail: "A world-splitting bolt with a wide blast.", cooldown: 25,
                                               effect: .strikes(targets: 1, damage: 2600, stun: 3, splash: 1.3, rangeScale: 2))) {
                $0.damage += 40
                $0.bossMultiplier = 1.5
            },
        ]),
    ]

    // MARK: Vanguard - armored genius

    private static let vanguard: [UpgradePath] = [
        UpgradePath(name: "Repulsor", tiers: [
            UpgradeTier(name: "Focused Lens", detail: "+30 beam damage.", cost: 110, research: 0) {
                $0.damage += 30
            },
            UpgradeTier(name: "Power Cells", detail: "Fires 25% faster.", cost: 180, research: 4) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Overload Beam", detail: "POWER: a sustained mega-beam.", cost: 320, research: 10,
                        power: PowerDefinition(name: "Overload Beam", detail: "Fire non-stop for 3 seconds.", cooldown: 35,
                                               effect: .frenzy(duration: 3, rate: 10, damage: 1))) {
                $0.damage += 50
                $0.range += 0.6
            },
            UpgradeTier(name: "Singularity Core", detail: "Crushing beam, +50% vs bosses.", cost: 1000, research: 20,
                        power: PowerDefinition(name: "Overload Beam+", detail: "Fire non-stop for 5 seconds at 12x speed.", cooldown: 35,
                                               effect: .frenzy(duration: 5, rate: 12, damage: 1))) {
                $0.damage += 150
                $0.bossMultiplier = 1.5
            },
        ]),
        UpgradePath(name: "Arsenal", tiers: [
            UpgradeTier(name: "Micro Missiles", detail: "Each shot adds 2 homing missiles.", cost: 120, research: 0) {
                $0.missiles = 2
                $0.missileDamage = 18
            },
            UpgradeTier(name: "Targeting AI", detail: "Longer range, 3 missiles.", cost: 160, research: 4) {
                $0.range += 0.8
                $0.missiles = 3
            },
            UpgradeTier(name: "Missile Swarm", detail: "POWER: a 12-missile barrage.", cost: 300, research: 10,
                        power: PowerDefinition(name: "Missile Swarm", detail: "Launch 12 homing missiles at enemies in range.", cooldown: 30,
                                               effect: .missiles(count: 12, damage: 120, splash: 0.6))) {
                $0.missiles = 4
                $0.missileDamage = 30
            },
            UpgradeTier(name: "Siege Protocol", detail: "6 heavy missiles per shot. 30-missile swarm.", cost: 900, research: 20,
                        power: PowerDefinition(name: "Siege Protocol", detail: "Launch 30 heavy missiles.", cooldown: 30,
                                               effect: .missiles(count: 30, damage: 250, splash: 0.8))) {
                $0.missiles = 6
                $0.missileDamage = 60
            },
        ]),
    ]
}
