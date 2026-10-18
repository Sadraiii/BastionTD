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
    case field(duration: Double, dps: Double, slow: Double, rangeScale: Double, type: DamageType)
    /// A volley of homing missiles.
    case missiles(count: Int, damage: Double, splash: Double)
    /// Freezes every villain on the map (bosses resist).
    case timeStop(duration: Double)
    /// Boosts attack speed and damage of every hero in range.
    case rally(duration: Double, rate: Double, damage: Double, rangeScale: Double)
    /// Strips cloaks, shields and armor from villains in range.
    case strip(damage: Double, rangeScale: Double)
    /// Villains in range turn around and walk backwards.
    case confuse(duration: Double, damage: Double, rangeScale: Double)
    /// Instant gold.
    case payout(gold: Int)
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
        case .inferno: inferno
        case .weaver: weaver
        case .aegis: aegis
        case .cyclone: cyclone
        case .echo: echo
        case .mind: mindwave
        case .chrono: chrono
        case .star: starlight
        case .midas: midas
        case .tide: riptide
        case .sniper: hawkeye
        case .tamer: fang
        case .alchemist: vial
        }
    }

    private static func power(_ name: String, _ detail: String, cooldown: Double, _ effect: PowerEffect) -> PowerDefinition {
        PowerDefinition(name: name, detail: detail, cooldown: cooldown, effect: effect)
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
                                               effect: .field(duration: 6, dps: 40, slow: 0.7, rangeScale: 1.3, type: .cold))) {
                $0.damage += 8
            },
            UpgradeTier(name: "Ice Age", detail: "Massive pulses. Blizzard lasts 8s.", cost: 700, research: 20,
                        power: PowerDefinition(name: "Ice Age", detail: "8-second storm with crushing damage and an 80% slow.", cooldown: 35,
                                               effect: .field(duration: 8, dps: 130, slow: 0.8, rangeScale: 1.5, type: .cold))) {
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
                        power: PowerDefinition(name: "Skyhammer", detail: "Drop a huge bolt on the strongest enemy.", cooldown: 25,
                                               effect: .strikes(targets: 1, damage: 800, stun: 2, splash: 0.8, rangeScale: 1.5))) {
                $0.damage += 16
            },
            UpgradeTier(name: "Godspark", detail: "Searing bolts. Skyhammer hits 3x harder.", cost: 800, research: 20,
                        power: PowerDefinition(name: "Godspark", detail: "A huge bolt with a wide blast.", cooldown: 25,
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

    // MARK: Inferno - fire hero

    private static let inferno: [UpgradePath] = [
        UpgradePath(name: "Wildfire", tiers: [
            UpgradeTier(name: "Hotter Flames", detail: "+3 damage, fiercer burn.", cost: 70, research: 0) {
                $0.damage += 3
                $0.burnDPS += 4
            },
            UpgradeTier(name: "Spreading Fire", detail: "Wider, longer flame cone.", cost: 130, research: 4) {
                $0.coneAngle = 1.5
                $0.range += 0.3
            },
            UpgradeTier(name: "Firestorm", detail: "POWER: a raging fire zone.", cost: 220, research: 10,
                        power: power("Firestorm", "6-second inferno that burns everything in range.", cooldown: 30,
                                     .field(duration: 6, dps: 60, slow: 0.2, rangeScale: 1.3, type: .fire))) {
                $0.damage += 3
            },
            UpgradeTier(name: "Hellfire", detail: "Searing burns. Firestorm lasts 8s.", cost: 600, research: 20,
                        power: power("Hellfire", "8-second firestorm with crushing heat.", cooldown: 30,
                                     .field(duration: 8, dps: 170, slow: 0.3, rangeScale: 1.5, type: .fire))) {
                $0.damage += 8
                $0.burnDPS += 12
                $0.burnDuration = 3
            },
        ]),
        UpgradePath(name: "Phoenix", tiers: [
            UpgradeTier(name: "Long Flame", detail: "More range.", cost: 60, research: 0) {
                $0.range += 0.4
            },
            UpgradeTier(name: "Blue Flame", detail: "Melts 3 armor off villains.", cost: 120, research: 4) {
                $0.armorShred = 3
                $0.damage += 3
            },
            UpgradeTier(name: "Phoenix Dive", detail: "POWER: explode in a blazing nova.", cost: 250, research: 10,
                        power: power("Phoenix Dive", "Blazing nova that scorches villains around the hero.", cooldown: 25,
                                     .burst(damage: 260, stun: 0, knockback: 0.5, rangeScale: 1.5, groundOnly: false))) {
                $0.damage += 4
            },
            UpgradeTier(name: "Rebirth", detail: "White-hot flames. Huge Phoenix Dive.", cost: 700, research: 20,
                        power: power("Rebirth", "Colossal nova that leaves villains reeling.", cooldown: 25,
                                     .burst(damage: 750, stun: 1, knockback: 1, rangeScale: 1.8, groundOnly: false))) {
                $0.damage += 10
                $0.armorShred = 6
            },
        ]),
    ]

    // MARK: Weaver - spider hero

    private static let weaver: [UpgradePath] = [
        UpgradePath(name: "Webmaster", tiers: [
            UpgradeTier(name: "Sticky Webs", detail: "Stronger, longer slow.", cost: 50, research: 0) {
                $0.slow = 0.55
                $0.slowDuration = 2
            },
            UpgradeTier(name: "Web Snare", detail: "Webs may pin villains in place.", cost: 110, research: 4) {
                $0.stunChance = 0.2
                $0.stunDuration = 1.2
            },
            UpgradeTier(name: "Web Prison", detail: "POWER: cocoon every villain in range.", cost: 210, research: 10,
                        power: power("Web Prison", "Wrap all villains in range for 3.5 seconds.", cooldown: 28,
                                     .burst(damage: 10, stun: 3.5, knockback: 0, rangeScale: 1.3, groundOnly: false))) {
                $0.multishot = 2
            },
            UpgradeTier(name: "Cocoon", detail: "Frequent snares. 5s Web Prison.", cost: 560, research: 20,
                        power: power("Cocoon", "Wrap all villains in a wide area for 5 seconds.", cooldown: 28,
                                     .burst(damage: 40, stun: 5, knockback: 0, rangeScale: 1.6, groundOnly: false))) {
                $0.stunChance = 0.35
                $0.multishot = 3
            },
        ]),
        UpgradePath(name: "Venom", tiers: [
            UpgradeTier(name: "Venom Fangs", detail: "Toxic bites poison villains.", cost: 70, research: 0) {
                $0.damageType = .toxic
                $0.poisonDPS = 8
                $0.poisonDuration = 3
            },
            UpgradeTier(name: "Spider Sense", detail: "Nearby heroes see cloaked foes.", cost: 100, research: 4) {
                $0.range += 0.4
                $0.revealsCamo = true
            },
            UpgradeTier(name: "Venom Burst", detail: "POWER: a toxic cloud.", cost: 220, research: 10,
                        power: power("Venom Burst", "5-second toxic cloud that eats through armor.", cooldown: 30,
                                     .field(duration: 5, dps: 70, slow: 0.3, rangeScale: 1.3, type: .toxic))) {
                $0.poisonDPS += 6
            },
            UpgradeTier(name: "Black Widow", detail: "Deadly venom. Bigger, longer cloud.", cost: 640, research: 20,
                        power: power("Black Widow", "7-second deadly cloud.", cooldown: 30,
                                     .field(duration: 7, dps: 190, slow: 0.4, rangeScale: 1.5, type: .toxic))) {
                $0.poisonDPS += 20
                $0.poisonDuration = 4
                $0.damage += 10
            },
        ]),
    ]

    // MARK: Aegis - shield captain

    private static let aegis: [UpgradePath] = [
        UpgradePath(name: "Ricochet", tiers: [
            UpgradeTier(name: "Extra Bounce", detail: "Shield bounces 2 more times.", cost: 60, research: 0) {
                $0.pierce += 2
            },
            UpgradeTier(name: "Star Shield", detail: "+8 damage, knocks villains back.", cost: 120, research: 4) {
                $0.damage += 8
                $0.knockback = 0.2
            },
            UpgradeTier(name: "Shield Storm", detail: "POWER: a blur of thrown shields.", cost: 220, research: 10,
                        power: power("Shield Storm", "Triple throwing speed for 5 seconds.", cooldown: 28,
                                     .frenzy(duration: 5, rate: 3, damage: 1.3))) {
                $0.damage += 6
            },
            UpgradeTier(name: "Unbreakable", detail: "Shield bounces 9 times.", cost: 600, research: 20,
                        power: power("Shield Storm+", "4x throwing speed and +60% damage for 8 seconds.", cooldown: 28,
                                     .frenzy(duration: 8, rate: 4, damage: 1.6))) {
                $0.pierce += 4
                $0.damage += 20
            },
        ]),
        UpgradePath(name: "Commander", tiers: [
            UpgradeTier(name: "Inspire", detail: "Heroes in range attack 10% faster.", cost: 80, research: 0) {
                $0.buffRate = 0.1
            },
            UpgradeTier(name: "Tactics", detail: "Heroes in range deal 15% more damage.", cost: 150, research: 4) {
                $0.buffDamage = 0.15
                $0.range += 0.4
            },
            UpgradeTier(name: "Rally Cry", detail: "POWER: supercharge nearby heroes.", cost: 260, research: 10,
                        power: power("Rally Cry", "Heroes in range: +60% speed, +30% damage for 8s.", cooldown: 35,
                                     .rally(duration: 8, rate: 1.6, damage: 1.3, rangeScale: 1.5))) {
                $0.buffRate = 0.15
            },
            UpgradeTier(name: "Legend", detail: "Massive aura. Rally doubles speed.", cost: 680, research: 20,
                        power: power("Legend", "Heroes in a wide area: 2x speed, +60% damage for 10s.", cooldown: 35,
                                     .rally(duration: 10, rate: 2, damage: 1.6, rangeScale: 2))) {
                $0.buffRate = 0.25
                $0.buffDamage = 0.3
            },
        ]),
    ]

    // MARK: Cyclone - wind hero

    private static let cyclone: [UpgradePath] = [
        UpgradePath(name: "Gale", tiers: [
            UpgradeTier(name: "Tailwind", detail: "Attacks 25% faster.", cost: 60, research: 0) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Downdraft", detail: "Triple damage to flyers, more range.", cost: 120, research: 4) {
                $0.airMultiplier = 3
                $0.range += 0.3
            },
            UpgradeTier(name: "Tornado", detail: "POWER: hurl villains back down the path.", cost: 230, research: 10,
                        power: power("Tornado", "Fling villains in range 2.5 tiles back and dizzy them.", cooldown: 28,
                                     .burst(damage: 100, stun: 1, knockback: 2.5, rangeScale: 1.3, groundOnly: false))) {
                $0.pierce += 1
            },
            UpgradeTier(name: "Hurricane", detail: "Shreds flyers. Massive Tornado.", cost: 640, research: 20,
                        power: power("Hurricane", "Fling villains 4 tiles back with a 2s stun.", cooldown: 28,
                                     .burst(damage: 300, stun: 2, knockback: 4, rangeScale: 1.6, groundOnly: false))) {
                $0.airMultiplier = 4
                $0.pierce += 2
            },
        ]),
        UpgradePath(name: "Squall", tiers: [
            UpgradeTier(name: "Sharp Wind", detail: "+6 damage.", cost: 70, research: 0) {
                $0.damage += 6
            },
            UpgradeTier(name: "Headwind", detail: "Stronger knockback.", cost: 130, research: 4) {
                $0.knockback = 0.35
            },
            UpgradeTier(name: "Jet Stream", detail: "POWER: 4x attack speed.", cost: 220, research: 10,
                        power: power("Jet Stream", "4x attack speed for 5 seconds.", cooldown: 28,
                                     .frenzy(duration: 5, rate: 4, damage: 1))) {
                $0.damage += 6
            },
            UpgradeTier(name: "Eye Wall", detail: "Brutal gusts. Jet Stream lasts 8s.", cost: 640, research: 20,
                        power: power("Jet Stream+", "5x attack speed and +50% damage for 8 seconds.", cooldown: 28,
                                     .frenzy(duration: 8, rate: 5, damage: 1.5))) {
                $0.damage += 20
                $0.knockback = 0.5
            },
        ]),
    ]

    // MARK: Echo - sonic hero

    private static let echo: [UpgradePath] = [
        UpgradePath(name: "Resonance", tiers: [
            UpgradeTier(name: "Pitch Perfect", detail: "+5 damage.", cost: 70, research: 0) {
                $0.damage += 5
            },
            UpgradeTier(name: "Shatter Note", detail: "Cracks 3 armor off villains.", cost: 130, research: 4) {
                $0.armorShred = 3
            },
            UpgradeTier(name: "Sonic Shatter", detail: "POWER: strip cloaks, shields and armor.", cost: 240, research: 10,
                        power: power("Sonic Shatter", "Reveal cloaked villains and shatter shields and armor in range.", cooldown: 30,
                                     .strip(damage: 100, rangeScale: 1.4))) {
                $0.shieldBreak = 4
            },
            UpgradeTier(name: "Glass Breaker", detail: "Deep shred. Map-wide shatter.", cost: 640, research: 20,
                        power: power("Glass Breaker", "Shatter every villain's defenses in a huge area.", cooldown: 30,
                                     .strip(damage: 400, rangeScale: 2.5))) {
                $0.armorShred = 6
                $0.shieldBreak = 6
                $0.damage += 8
            },
        ]),
        UpgradePath(name: "Echolocation", tiers: [
            UpgradeTier(name: "Sonar", detail: "Sees cloaked villains and reveals them to nearby heroes.", cost: 80, research: 0) {
                $0.detectsCamo = true
                $0.revealsCamo = true
            },
            UpgradeTier(name: "Wide Cry", detail: "Much wider cone, more range.", cost: 120, research: 4) {
                $0.coneAngle = 2.0
                $0.range += 0.4
            },
            UpgradeTier(name: "Deafening Wail", detail: "POWER: stun everything nearby.", cost: 250, research: 10,
                        power: power("Deafening Wail", "Stun villains in range for 2.5 seconds.", cooldown: 30,
                                     .burst(damage: 80, stun: 2.5, knockback: 0, rangeScale: 1.3, groundOnly: false))) {
                $0.damage += 5
            },
            UpgradeTier(name: "Banshee", detail: "Screams may stun. 4s mega-wail.", cost: 680, research: 20,
                        power: power("Banshee", "Stun villains in a wide area for 4 seconds.", cooldown: 30,
                                     .burst(damage: 250, stun: 4, knockback: 0, rangeScale: 1.6, groundOnly: false))) {
                $0.stunChance = 0.2
                $0.stunDuration = 0.8
                $0.damage += 10
            },
        ]),
    ]

    // MARK: Mindwave - psychic

    private static let mindwave: [UpgradePath] = [
        UpgradePath(name: "Telepathy", tiers: [
            UpgradeTier(name: "Focus", detail: "+10 damage.", cost: 90, research: 0) {
                $0.damage += 10
            },
            UpgradeTier(name: "Confusion", detail: "Blasts may send villains walking backwards.", cost: 160, research: 4) {
                $0.confuseChance = 0.2
                $0.confuseDuration = 1.5
            },
            UpgradeTier(name: "Mass Hysteria", detail: "POWER: everyone in range turns around.", cost: 280, research: 10,
                        power: power("Mass Hysteria", "Villains in range walk backwards for 4 seconds.", cooldown: 32,
                                     .confuse(duration: 4, damage: 40, rangeScale: 1.4))) {
                $0.multishot = 2
            },
            UpgradeTier(name: "Puppet Master", detail: "Frequent confusion. 6s hysteria.", cost: 720, research: 20,
                        power: power("Puppet Master", "Villains in a huge area walk backwards for 6 seconds.", cooldown: 32,
                                     .confuse(duration: 6, damage: 150, rangeScale: 1.8))) {
                $0.confuseChance = 0.35
                $0.multishot = 3
            },
        ]),
        UpgradePath(name: "Telekinesis", tiers: [
            UpgradeTier(name: "Quick Thoughts", detail: "Attacks 25% faster.", cost: 100, research: 0) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Mind Over Matter", detail: "More range and knockback.", cost: 150, research: 4) {
                $0.range += 0.6
                $0.knockback = 0.3
            },
            UpgradeTier(name: "Mind Crush", detail: "POWER: obliterate the strongest foe.", cost: 300, research: 10,
                        power: power("Mind Crush", "Crush the strongest villain with 1500 psychic damage.", cooldown: 25,
                                     .strikes(targets: 1, damage: 1500, stun: 1, splash: 0, rangeScale: 1.5))) {
                $0.damage += 15
            },
            UpgradeTier(name: "Singularity Mind", detail: "+50% vs bosses. Crushes 3 foes.", cost: 820, research: 20,
                        power: power("Singularity Mind", "Crush the 3 strongest villains for 3500 each.", cooldown: 25,
                                     .strikes(targets: 3, damage: 3500, stun: 2, splash: 0, rangeScale: 2))) {
                $0.damage += 40
                $0.bossMultiplier = 1.5
            },
        ]),
    ]

    // MARK: Chrono - time keeper

    private static let chrono: [UpgradePath] = [
        UpgradePath(name: "Stasis", tiers: [
            UpgradeTier(name: "Slow Time", detail: "Stronger slow.", cost: 80, research: 0) {
                $0.slow = 0.45
            },
            UpgradeTier(name: "Time Lock", detail: "Pulses may freeze villains in time.", cost: 150, research: 4) {
                $0.stunChance = 0.15
                $0.stunDuration = 1
            },
            UpgradeTier(name: "Time Stop", detail: "POWER: stop time across the whole map.", cost: 300, research: 10,
                        power: power("Time Stop", "Every villain on the map freezes for 3 seconds.", cooldown: 40,
                                     .timeStop(duration: 3))) {
                $0.range += 0.3
            },
            UpgradeTier(name: "Eternity", detail: "Crushing slow. 5s Time Stop.", cost: 750, research: 20,
                        power: power("Eternity", "Every villain on the map freezes for 5 seconds.", cooldown: 40,
                                     .timeStop(duration: 5))) {
                $0.slow = 0.6
                $0.stunChance = 0.25
            },
        ]),
        UpgradePath(name: "Rewind", tiers: [
            UpgradeTier(name: "Temporal Shock", detail: "+6 damage.", cost: 70, research: 0) {
                $0.damage += 6
            },
            UpgradeTier(name: "Paradox", detail: "Pulses push villains back in time.", cost: 140, research: 4) {
                $0.knockback = 0.3
            },
            UpgradeTier(name: "Rewind", detail: "POWER: send villains far back.", cost: 260, research: 10,
                        power: power("Rewind", "Rewind villains in range 4 tiles back along the path.", cooldown: 30,
                                     .burst(damage: 50, stun: 0.5, knockback: 4, rangeScale: 1.4, groundOnly: false))) {
                $0.damage += 6
            },
            UpgradeTier(name: "Time Loop", detail: "Heavy pushback. Huge rewind.", cost: 720, research: 20,
                        power: power("Time Loop", "Rewind villains in a wide area 7 tiles back.", cooldown: 30,
                                     .burst(damage: 200, stun: 1, knockback: 7, rangeScale: 2, groundOnly: false))) {
                $0.damage += 15
                $0.knockback = 0.5
            },
        ]),
    ]

    // MARK: Starlight - cosmic hero

    // MARK: Midas - gold hero

    private static let midas: [UpgradePath] = [
        UpgradePath(name: "Treasury", tiers: [
            UpgradeTier(name: "Coin Purse", detail: "+15 gold per wave.", cost: 80, research: 0) {
                $0.income += 15
            },
            UpgradeTier(name: "Strongbox", detail: "+30 gold per wave.", cost: 200, research: 4) {
                $0.income += 30
            },
            UpgradeTier(name: "Gold Rush", detail: "POWER: get 150 gold now. +20 per wave.", cost: 400, research: 10,
                        power: power("Gold Rush", "Get 150 gold right away.", cooldown: 45, .payout(gold: 150))) {
                $0.income += 20
            },
            UpgradeTier(name: "Royal Mint", detail: "+100 gold per wave. Gold Rush gives 400.", cost: 1200, research: 20,
                        power: power("Gold Rush+", "Get 400 gold right away.", cooldown: 45, .payout(gold: 400))) {
                $0.income += 100
            },
        ]),
        UpgradePath(name: "Golden Touch", tiers: [
            UpgradeTier(name: "Gilded Banner", detail: "Heroes in range deal 10% more damage.", cost: 90, research: 0) {
                $0.buffDamage += 0.1
            },
            UpgradeTier(name: "Pep Talk", detail: "Heroes in range attack 10% faster.", cost: 160, research: 4) {
                $0.buffRate += 0.1
            },
            UpgradeTier(name: "Golden Hour", detail: "POWER: heroes in range attack 50% faster for 8s.", cost: 350, research: 10,
                        power: power("Golden Hour", "Heroes in range attack 50% faster for 8 seconds.", cooldown: 40,
                                     .rally(duration: 8, rate: 1.5, damage: 1.2, rangeScale: 1))) {
                $0.range += 0.5
            },
            UpgradeTier(name: "Midas Reign", detail: "Stronger auras. Golden Hour doubles attack speed.", cost: 1000, research: 20,
                        power: power("Golden Hour+", "Heroes in range attack twice as fast for 10 seconds.", cooldown: 40,
                                     .rally(duration: 10, rate: 2, damage: 1.5, rangeScale: 1.2))) {
                $0.buffDamage += 0.1
                $0.buffRate += 0.1
            },
        ]),
    ]

    // MARK: Riptide - sea hero

    private static let riptide: [UpgradePath] = [
        UpgradePath(name: "Torpedoes", tiers: [
            UpgradeTier(name: "Twin Tubes", detail: "Fires at two enemies at once.", cost: 70, research: 0) {
                $0.multishot = 2
            },
            UpgradeTier(name: "Heavy Warheads", detail: "+8 damage per torpedo.", cost: 150, research: 4) {
                $0.damage += 8
            },
            UpgradeTier(name: "Depth Charge", detail: "POWER: a big blast around Riptide.", cost: 300, research: 10,
                        power: power("Depth Charge", "Damage and stun everything nearby.", cooldown: 25,
                                     .burst(damage: 200, stun: 1, knockback: 0.5, rangeScale: 1.1, groundOnly: false))) {
                $0.multishot = 3
            },
            UpgradeTier(name: "Kraken", detail: "Five torpedoes at once. Much bigger Depth Charge.", cost: 900, research: 20,
                        power: power("Kraken", "Huge damage and a long stun nearby.", cooldown: 25,
                                     .burst(damage: 600, stun: 2, knockback: 1, rangeScale: 1.4, groundOnly: false))) {
                $0.multishot = 5
                $0.damage += 10
            },
        ]),
        UpgradePath(name: "Sonar", tiers: [
            UpgradeTier(name: "Long Sonar", detail: "Much longer range.", cost: 80, research: 0) {
                $0.range += 0.8
            },
            UpgradeTier(name: "Armor Piercing", detail: "Torpedoes ignore armor.", cost: 160, research: 4) {
                $0.piercesArmor = true
            },
            UpgradeTier(name: "Whirlpool", detail: "POWER: a whirlpool that slows and hurts.", cost: 280, research: 10,
                        power: power("Whirlpool", "6-second whirlpool: damage and a 50% slow.", cooldown: 30,
                                     .field(duration: 6, dps: 30, slow: 0.5, rangeScale: 1, type: .kinetic))) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Maelstrom", detail: "Faster torpedoes. Whirlpool lasts 9s.", cost: 850, research: 20,
                        power: power("Maelstrom", "9-second whirlpool: heavy damage and a 70% slow.", cooldown: 30,
                                     .field(duration: 9, dps: 80, slow: 0.7, rangeScale: 1.3, type: .kinetic))) {
                $0.fireInterval *= 0.7
            },
        ]),
    ]

    // MARK: Hawkeye - sniper

    private static let hawkeye: [UpgradePath] = [
        UpgradePath(name: "Marksman", tiers: [
            UpgradeTier(name: "Heavy Rounds", detail: "+30 damage per shot.", cost: 120, research: 0) {
                $0.damage += 30
            },
            UpgradeTier(name: "Armor Breaker", detail: "Shots ignore armor.", cost: 220, research: 4) {
                $0.piercesArmor = true
            },
            UpgradeTier(name: "Headshot", detail: "POWER: one huge shot at the toughest foe.", cost: 400, research: 10,
                        power: power("Headshot", "A huge shot at the toughest enemy in range.", cooldown: 25,
                                     .strikes(targets: 1, damage: 800, stun: 0, splash: 0.3, rangeScale: 1))) {
                $0.bossMultiplier = 1.5
            },
            UpgradeTier(name: "Deadeye", detail: "Double damage. Headshot hits 3 foes.", cost: 1200, research: 20,
                        power: power("Deadeye", "Huge shots at the 3 toughest enemies in range.", cooldown: 25,
                                     .strikes(targets: 3, damage: 2000, stun: 0, splash: 0.3, rangeScale: 1))) {
                $0.damage *= 2
            },
        ]),
        UpgradePath(name: "Spotter", tiers: [
            UpgradeTier(name: "Scope", detail: "Spots cloaked villains.", cost: 90, research: 0) {
                $0.detectsCamo = true
            },
            UpgradeTier(name: "Steady Aim", detail: "Shoots 25% faster.", cost: 200, research: 4) {
                $0.fireInterval *= 0.75
            },
            UpgradeTier(name: "Flare", detail: "POWER: strips cloaks, shields and armor.", cost: 350, research: 10,
                        power: power("Flare", "Strip cloaks, shields and armor in range.", cooldown: 30,
                                     .strip(damage: 50, rangeScale: 1))) {
                $0.revealsCamo = true
            },
            UpgradeTier(name: "Overwatch", detail: "Shoots twice as fast. Stronger Flare.", cost: 1000, research: 20,
                        power: power("Overwatch", "Strip everything in range and deal heavy damage.", cooldown: 30,
                                     .strip(damage: 300, rangeScale: 1))) {
                $0.fireInterval *= 0.5
            },
        ]),
    ]

    // MARK: Fang - beast tamer

    private static let fang: [UpgradePath] = [
        UpgradePath(name: "Pack", tiers: [
            UpgradeTier(name: "Two Wolves", detail: "Attacks two enemies at once.", cost: 70, research: 0) {
                $0.multishot = 2
            },
            UpgradeTier(name: "Sharp Fangs", detail: "+6 damage per bite.", cost: 150, research: 4) {
                $0.damage += 6
            },
            UpgradeTier(name: "Beast Wall", detail: "POWER: beasts block the path for 4s.", cost: 300, research: 10,
                        power: power("Beast Wall", "Beasts hold villains in place for 4 seconds.", cooldown: 25,
                                     .field(duration: 4, dps: 10, slow: 0.95, rangeScale: 1, type: .kinetic))) {
                $0.multishot = 3
            },
            UpgradeTier(name: "Stampede", detail: "Four wolves. Beasts hold for 6s.", cost: 900, research: 20,
                        power: power("Stampede", "Beasts hold villains in place for 6 seconds and maul them.", cooldown: 25,
                                     .field(duration: 6, dps: 50, slow: 1, rangeScale: 1.2, type: .kinetic))) {
                $0.multishot = 4
                $0.damage += 10
            },
        ]),
        UpgradePath(name: "Wild", tiers: [
            UpgradeTier(name: "Pounce", detail: "Bites push enemies back.", cost: 80, research: 0) {
                $0.knockback = 0.2
            },
            UpgradeTier(name: "Savage", detail: "Stuns more often.", cost: 160, research: 4) {
                $0.stunChance = 0.3
            },
            UpgradeTier(name: "Howl", detail: "POWER: a howl that stuns everything nearby.", cost: 280, research: 10,
                        power: power("Howl", "Stun everything nearby for 2 seconds.", cooldown: 25,
                                     .burst(damage: 40, stun: 2, knockback: 0.3, rangeScale: 1.2, groundOnly: false))) {
                $0.range += 0.4
            },
            UpgradeTier(name: "Alpha", detail: "Bites stun longer. Howl stuns for 4s.", cost: 850, research: 20,
                        power: power("Alpha Howl", "Stun everything nearby for 4 seconds.", cooldown: 25,
                                     .burst(damage: 150, stun: 4, knockback: 0.6, rangeScale: 1.5, groundOnly: false))) {
                $0.stunDuration = 1.2
            },
        ]),
    ]

    // MARK: Vial - alchemist

    private static let vial: [UpgradePath] = [
        UpgradePath(name: "Acids", tiers: [
            UpgradeTier(name: "Strong Acid", detail: "Melts 2 more armor.", cost: 80, research: 0) {
                $0.armorShred += 2
            },
            UpgradeTier(name: "Venom", detail: "Stronger poison.", cost: 170, research: 4) {
                $0.poisonDPS += 8
            },
            UpgradeTier(name: "Acid Rain", detail: "POWER: a cloud that poisons and slows.", cost: 320, research: 10,
                        power: power("Acid Rain", "6-second acid cloud: damage and a 20% slow.", cooldown: 30,
                                     .field(duration: 6, dps: 40, slow: 0.2, rangeScale: 1.2, type: .toxic))) {
                $0.splashRadius += 0.3
            },
            UpgradeTier(name: "Meltdown", detail: "Brutal poison. Acid Rain lasts 9s.", cost: 950, research: 20,
                        power: power("Meltdown", "9-second acid cloud: heavy damage and a 30% slow.", cooldown: 30,
                                     .field(duration: 9, dps: 120, slow: 0.3, rangeScale: 1.4, type: .toxic))) {
                $0.poisonDPS += 25
            },
        ]),
        UpgradePath(name: "Brews", tiers: [
            UpgradeTier(name: "Long Toss", detail: "More range.", cost: 70, research: 0) {
                $0.range += 0.6
            },
            UpgradeTier(name: "Quick Brew", detail: "Throws 20% faster.", cost: 160, research: 4) {
                $0.fireInterval *= 0.8
            },
            UpgradeTier(name: "Elixir", detail: "POWER: heroes in range get stronger for 8s.", cost: 300, research: 10,
                        power: power("Elixir", "Heroes in range attack 40% faster and hit 30% harder for 8 seconds.", cooldown: 35,
                                     .rally(duration: 8, rate: 1.4, damage: 1.3, rangeScale: 1.2))) {
                $0.damage += 8
            },
            UpgradeTier(name: "Philosopher's Stone", detail: "Strong flasks. Elixir lasts 12s.", cost: 900, research: 20,
                        power: power("Philosopher's Stone", "Heroes in range attack 70% faster and hit 60% harder for 12 seconds.", cooldown: 35,
                                     .rally(duration: 12, rate: 1.7, damage: 1.6, rangeScale: 1.5))) {
                $0.damage += 20
            },
        ]),
    ]

    private static let starlight: [UpgradePath] = [
        UpgradePath(name: "Solar", tiers: [
            UpgradeTier(name: "Sunspot", detail: "+40 beam damage.", cost: 120, research: 0) {
                $0.damage += 40
            },
            UpgradeTier(name: "Corona", detail: "Beams set villains ablaze.", cost: 200, research: 4) {
                $0.burnDPS = 20
                $0.burnDuration = 2
            },
            UpgradeTier(name: "Solar Flare", detail: "POWER: rain flares on 5 foes.", cost: 330, research: 10,
                        power: power("Solar Flare", "Blast the 5 toughest villains in range with 600 each.", cooldown: 30,
                                     .strikes(targets: 5, damage: 600, stun: 0.5, splash: 0.8, rangeScale: 1.3))) {
                $0.damage += 40
            },
            UpgradeTier(name: "Supernova", detail: "Blinding beam. Map-wide nova.", cost: 980, research: 20,
                        power: power("Supernova", "A nova that hits every villain on the map for 1200.", cooldown: 40,
                                     .burst(damage: 1200, stun: 1, knockback: 0, rangeScale: 12, groundOnly: false))) {
                $0.damage += 120
            },
        ]),
        UpgradePath(name: "Gravity", tiers: [
            UpgradeTier(name: "Gravity Well", detail: "Beams slow villains.", cost: 100, research: 0) {
                $0.slow = 0.3
                $0.slowDuration = 1.5
            },
            UpgradeTier(name: "Event Horizon", detail: "More range, sees cloaked foes.", cost: 180, research: 4) {
                $0.range += 1
                $0.detectsCamo = true
            },
            UpgradeTier(name: "Black Hole", detail: "POWER: a crushing gravity well.", cost: 350, research: 10,
                        power: power("Black Hole", "5-second gravity well that crushes and holds villains.", cooldown: 32,
                                     .field(duration: 5, dps: 130, slow: 0.85, rangeScale: 0.8, type: .energy))) {
                $0.damage += 30
            },
            UpgradeTier(name: "Singularity", detail: "2x vs bosses. Devastating Black Hole.", cost: 980, research: 20,
                        power: power("Singularity", "7-second singularity that nearly stops time.", cooldown: 32,
                                     .field(duration: 7, dps: 380, slow: 0.92, rangeScale: 1, type: .energy))) {
                $0.damage += 80
                $0.bossMultiplier = 2
            },
        ]),
    ]
}
