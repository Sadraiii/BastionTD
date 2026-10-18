import Foundation

/// A batch of identical enemies inside a wave.
struct SpawnGroup {
    let kind: EnemyKind
    let count: Int
    /// Seconds between consecutive spawns in this group.
    let interval: Double
    /// Seconds after the wave starts before the first spawn of this group.
    let delay: Double
}

/// How a level's waves are made: how many, which villains (introduced in this order),
/// the boss of the last wave and extra health for later worlds.
struct WavePlan {
    let count: Int
    let villains: [EnemyKind]
    let boss: EnemyKind
    var healthScale: Double = 1
}

struct WaveDefinition {
    let groups: [SpawnGroup]

    var enemyCount: Int { groups.reduce(0) { $0 + $1.count } }
    var hasBoss: Bool { groups.contains { $0.kind.isBoss } }
    var kinds: Set<EnemyKind> { Set(groups.map(\.kind)) }
}

/// The campaign's wave list plus the difficulty curve applied on top of it.
enum WaveLibrary {
    private static func g(_ kind: EnemyKind, _ count: Int, every interval: Double, after delay: Double = 0) -> SpawnGroup {
        SpawnGroup(kind: kind, count: count, interval: interval, delay: delay)
    }

    /// Twenty waves. New villains are introduced one or two at a time, then mixed
    /// so that no single damage type can handle a whole wave.
    static let standard: [WaveDefinition] = [
        WaveDefinition(groups: [g(.drone, 8, every: 1.1)]),
        WaveDefinition(groups: [g(.drone, 12, every: 0.9)]),
        WaveDefinition(groups: [g(.drone, 8, every: 1.0), g(.runner, 6, every: 0.7, after: 4)]),
        WaveDefinition(groups: [g(.runner, 10, every: 0.5), g(.ironclad, 4, every: 1.6, after: 3)]),
        WaveDefinition(groups: [g(.drone, 8, every: 0.9), g(.brute, 3, every: 2.5, after: 2)]),
        WaveDefinition(groups: [g(.wisp, 8, every: 1.0), g(.drone, 8, every: 0.9, after: 2)]),
        WaveDefinition(groups: [g(.drone, 10, every: 0.8), g(.medic, 4, every: 2.0, after: 1.5), g(.berserker, 3, every: 2.2, after: 6)]),
        WaveDefinition(groups: [g(.splitter, 6, every: 1.6), g(.pyrefiend, 6, every: 1.0, after: 3), g(.runner, 8, every: 0.45, after: 6)]),
        WaveDefinition(groups: [g(.voidling, 8, every: 0.9), g(.brute, 4, every: 1.8, after: 2), g(.medic, 3, every: 2.4, after: 4)]),
        WaveDefinition(groups: [g(.drone, 10, every: 0.8), g(.titan, 1, every: 1, after: 5), g(.ironclad, 6, every: 1, after: 9)]),
        WaveDefinition(groups: [g(.phantom, 8, every: 1.0), g(.runner, 12, every: 0.4, after: 3), g(.wisp, 6, every: 0.9, after: 6)]),
        WaveDefinition(groups: [g(.blastguard, 5, every: 1.4), g(.medic, 3, every: 2, after: 1), g(.hexer, 2, every: 3, after: 4), g(.voidling, 5, every: 0.9, after: 6)]),
        WaveDefinition(groups: [g(.frostborn, 6, every: 1.4), g(.mirage, 6, every: 1.1, after: 3), g(.splitter, 6, every: 1.1, after: 5)]),
        WaveDefinition(groups: [g(.husk, 10, every: 0.9), g(.berserker, 5, every: 1.5, after: 3), g(.pyrefiend, 8, every: 0.7, after: 6)]),
        WaveDefinition(groups: [g(.dreadnought, 1, every: 1, after: 3), g(.wisp, 8, every: 0.7), g(.hexer, 2, every: 2.5, after: 6), g(.ironclad, 4, every: 1, after: 8)]),
        WaveDefinition(groups: [g(.warper, 10, every: 0.9), g(.runner, 20, every: 0.3, after: 3), g(.phantom, 6, every: 0.9, after: 6)]),
        WaveDefinition(groups: [g(.gargoyle, 6, every: 1.4), g(.brute, 8, every: 1.2, after: 2), g(.medic, 6, every: 1.4, after: 4), g(.frostborn, 6, every: 1.1, after: 7)]),
        WaveDefinition(groups: [g(.splitter, 10, every: 0.9), g(.mirage, 8, every: 0.8, after: 4), g(.blastguard, 6, every: 1, after: 7), g(.hexer, 3, every: 2, after: 8)]),
        WaveDefinition(groups: [g(.voidling, 14, every: 0.5), g(.ironclad, 12, every: 0.7, after: 3), g(.husk, 10, every: 0.8, after: 6), g(.gargoyle, 6, every: 1.2, after: 9), g(.warper, 8, every: 0.9, after: 10)]),
        WaveDefinition(groups: [g(.overlord, 1, every: 1, after: 2), g(.brute, 6, every: 1.3, after: 4), g(.hexer, 2, every: 3, after: 5), g(.mirage, 5, every: 0.9, after: 8), g(.pyrefiend, 8, every: 0.7, after: 10)]),
    ]

    /// A level's waves: the first two use only the plan's first villain, then the rest join
    /// one by one, waves grow and speed up, and the boss arrives in the last wave.
    static func level(_ plan: WavePlan, seed: UInt64) -> [WaveDefinition] {
        var rng = SplitMix64(seed: seed)
        return (1...plan.count).map { n in
            let progress = Double(max(0, n - 2)) / Double(max(1, plan.count - 3))
            let unlocked = min(plan.villains.count, 1 + Int((Double(plan.villains.count - 1) * progress).rounded(.down)))
            let available = Array(plan.villains.prefix(unlocked))
            let groupCount = n < 4 ? 1 : n < 9 ? 2 : 3
            // Total villain health per wave, close to the classic campaign's curve.
            let budget = 240 + 90 * Double(n - 1) + 6 * Double((n - 1) * (n - 1))
            var groups: [SpawnGroup] = []
            for i in 0..<groupCount {
                // The newest villain leads every wave until the next one joins.
                let kind = i == 0 ? available[available.count - 1] : available[Int(rng.next() % UInt64(available.count))]
                // Fast and supporting villains weigh more, so they come in smaller groups.
                let weight = kind.baseHealth * max(1, kind.speed / 1.15) * (kind.abilities.isEmpty ? 1 : 2)
                let count = max(2, Int(budget / Double(groupCount) / weight))
                groups.append(g(kind, count, every: max(0.35, 1.0 - Double(n) * 0.04), after: Double(i) * 3))
            }
            if n == plan.count { groups.append(g(plan.boss, 1, every: 1, after: 4)) }
            return WaveDefinition(groups: groups)
        }
    }

    /// Ten boss waves for the Boss Rush event.
    static let bossRush: [WaveDefinition] = [
        WaveDefinition(groups: [g(.drone, 6, every: 0.8), g(.titan, 1, every: 1, after: 4)]),
        WaveDefinition(groups: [g(.wisp, 6, every: 0.8), g(.dreadnought, 1, every: 1, after: 3)]),
        WaveDefinition(groups: [g(.titan, 2, every: 6)]),
        WaveDefinition(groups: [g(.ironclad, 6, every: 1), g(.dreadnought, 1, every: 1, after: 4), g(.titan, 1, every: 1, after: 10)]),
        WaveDefinition(groups: [g(.overlord, 1, every: 1)]),
        WaveDefinition(groups: [g(.dreadnought, 2, every: 8)]),
        WaveDefinition(groups: [g(.hexer, 3, every: 2), g(.titan, 3, every: 5, after: 3)]),
        WaveDefinition(groups: [g(.overlord, 1, every: 1), g(.dreadnought, 1, every: 1, after: 8)]),
        WaveDefinition(groups: [g(.titan, 2, every: 4), g(.dreadnought, 2, every: 6, after: 6)]),
        WaveDefinition(groups: [g(.overlord, 2, every: 10), g(.titan, 2, every: 5, after: 4), g(.dreadnought, 1, every: 1, after: 12)]),
    ]

    /// Enemy health grows smoothly from 1x on wave 1 to about 9.5x on wave 20,
    /// then ramps up exponentially in Endless mode.
    static func healthMultiplier(wave: Int) -> Double {
        let n = Double(max(0, wave - 1))
        let endless = pow(1.07, Double(max(0, wave - standard.count)))
        return (1 + 0.18 * n + 0.014 * n * n) * endless
    }

    static func bountyMultiplier(wave: Int) -> Double {
        1 + 0.03 * Double(max(0, wave - 1))
    }

    /// Gold awarded for clearing a wave.
    static func clearBonus(wave: Int) -> Int { 15 + wave * 4 }

    /// Procedural waves for Endless mode (wave 21 onward). Every fifth wave brings
    /// a Titan and every tenth the Overlord; the health curve keeps climbing.
    static func endlessWave(number: Int) -> WaveDefinition {
        var rng = SplitMix64(seed: UInt64(number) &* 0x9E37_79B9)
        let pool: [EnemyKind] = [.drone, .runner, .brute, .medic, .wisp, .splitter, .berserker, .phantom, .hexer,
                                 .ironclad, .pyrefiend, .frostborn, .voidling, .blastguard, .husk, .mirage, .gargoyle, .warper]
        let extra = max(0, number - standard.count)
        var groups: [SpawnGroup] = []
        for i in 0..<4 {
            let kind = pool[Int(rng.next() % UInt64(pool.count))]
            let count = 8 + extra + Int(rng.next() % 8)
            let interval = max(0.2, 0.9 - Double(extra) * 0.02)
            groups.append(g(kind, count, every: interval, after: Double(i) * 3))
        }
        if number % 5 == 0 { groups.append(g(number % 10 == 5 ? .dreadnought : .titan, 1 + extra / 10, every: 4, after: 4)) }
        if number % 10 == 0 { groups.append(g(.overlord, 1, every: 1, after: 2)) }
        return WaveDefinition(groups: groups)
    }

    /// Enemy kinds that appear for the first time in the wave at `index`.
    static func newKinds(in waves: [WaveDefinition], at index: Int) -> [EnemyKind] {
        let seen = waves.prefix(index).reduce(into: Set<EnemyKind>()) { $0.formUnion($1.kinds) }
        return waves[index].groups.map(\.kind).filter { !seen.contains($0) }.uniqued()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
