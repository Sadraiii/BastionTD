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

    /// Twenty waves. New villains are introduced one at a time and then mixed in.
    static let standard: [WaveDefinition] = [
        WaveDefinition(groups: [g(.drone, 8, every: 1.1)]),
        WaveDefinition(groups: [g(.drone, 12, every: 0.9)]),
        WaveDefinition(groups: [g(.drone, 8, every: 1.0), g(.runner, 6, every: 0.7, after: 4)]),
        WaveDefinition(groups: [g(.runner, 12, every: 0.5), g(.drone, 6, every: 1.0, after: 3)]),
        WaveDefinition(groups: [g(.drone, 8, every: 0.9), g(.brute, 3, every: 2.5, after: 2)]),
        WaveDefinition(groups: [g(.wisp, 8, every: 1.0), g(.drone, 8, every: 0.9, after: 2)]),
        WaveDefinition(groups: [g(.drone, 10, every: 0.8), g(.medic, 4, every: 2.0, after: 1.5), g(.berserker, 3, every: 2.2, after: 6)]),
        WaveDefinition(groups: [g(.splitter, 6, every: 1.6), g(.runner, 10, every: 0.45, after: 3)]),
        WaveDefinition(groups: [g(.brute, 6, every: 1.8), g(.medic, 4, every: 2.4, after: 1), g(.drone, 10, every: 0.7, after: 4)]),
        WaveDefinition(groups: [g(.drone, 10, every: 0.8), g(.titan, 1, every: 1, after: 5), g(.runner, 8, every: 0.5, after: 10)]),
        WaveDefinition(groups: [g(.phantom, 8, every: 1.0), g(.runner, 12, every: 0.4, after: 3), g(.wisp, 6, every: 0.9, after: 6)]),
        WaveDefinition(groups: [g(.brute, 8, every: 1.4), g(.medic, 6, every: 1.8, after: 1), g(.hexer, 2, every: 3, after: 4)]),
        WaveDefinition(groups: [g(.splitter, 10, every: 1.1), g(.wisp, 10, every: 0.8, after: 2), g(.phantom, 4, every: 1.2, after: 6)]),
        WaveDefinition(groups: [g(.drone, 20, every: 0.45), g(.brute, 8, every: 1.5, after: 3), g(.berserker, 4, every: 1.6, after: 6)]),
        WaveDefinition(groups: [g(.wisp, 14, every: 0.6), g(.medic, 6, every: 1.6), g(.hexer, 3, every: 2.5, after: 3), g(.brute, 6, every: 1.8, after: 4)]),
        WaveDefinition(groups: [g(.runner, 28, every: 0.25), g(.splitter, 8, every: 1.2, after: 3), g(.phantom, 6, every: 0.9, after: 6)]),
        WaveDefinition(groups: [g(.brute, 10, every: 1.2), g(.medic, 8, every: 1.4, after: 1), g(.berserker, 6, every: 1.3, after: 4), g(.wisp, 12, every: 0.6, after: 6)]),
        WaveDefinition(groups: [g(.splitter, 14, every: 0.9), g(.runner, 18, every: 0.3, after: 4), g(.phantom, 10, every: 0.7, after: 7), g(.hexer, 4, every: 2, after: 8)]),
        WaveDefinition(groups: [g(.drone, 24, every: 0.35), g(.brute, 12, every: 1.1, after: 3), g(.medic, 10, every: 1.2, after: 4), g(.wisp, 16, every: 0.5, after: 8), g(.berserker, 6, every: 1.2, after: 10)]),
        WaveDefinition(groups: [g(.overlord, 1, every: 1, after: 2), g(.brute, 8, every: 1.2, after: 4), g(.hexer, 3, every: 2.5, after: 5), g(.phantom, 8, every: 0.8, after: 8), g(.wisp, 10, every: 0.6, after: 10)]),
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
        let pool: [EnemyKind] = [.drone, .runner, .brute, .medic, .wisp, .splitter, .berserker, .phantom, .hexer]
        let extra = number - standard.count
        var groups: [SpawnGroup] = []
        for i in 0..<4 {
            let kind = pool[Int(rng.next() % UInt64(pool.count))]
            let count = 8 + extra + Int(rng.next() % 8)
            let interval = max(0.2, 0.9 - Double(extra) * 0.02)
            groups.append(g(kind, count, every: interval, after: Double(i) * 3))
        }
        if number % 5 == 0 { groups.append(g(.titan, 1 + extra / 10, every: 4, after: 4)) }
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
