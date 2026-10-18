// Headless balance check for Bastion TD.
//
// Compiles the game's Models and Engine for macOS and plays every map with a
// simple greedy AI, once with a fresh account (no research) and once fully
// researched. Run with Tools/run_balance_sim.sh.

import CoreGraphics
import Foundation

struct GreedyPlayer {
    let buildOrder: [TowerKind]
    let maxTowers: Int

    init(research: ResearchState, maxTowers: Int) {
        let wishList: [TowerKind] = [.pulse, .rail, .frost, .mortar, .inferno, .tesla, .aegis, .cyclone, .rail, .echo,
                                     .mind, .star, .weaver, .chrono, .mortar, .tesla, .pulse, .rail]
        buildOrder = wishList.filter(research.isHeroUnlocked)
        self.maxTowers = maxTowers
    }
    var built = 0

    /// Favorite path per hero: the one this AI pushes to tier 4.
    func mainPath(_ tower: Tower) -> Int { tower.id % 2 }

    var spentOnTowers = 0
    var spentOnUpgrades = 0

    mutating func act(_ engine: GameEngine) {
        for tower in engine.towers where tower.isPowerReady && engine.powerHasTargets(towerID: tower.id) {
            engine.activatePower(towerID: tower.id)
        }
        while true {
            let kind = buildOrder[built % buildOrder.count]
            let wantTower = engine.towers.count < 4 || (spentOnUpgrades >= spentOnTowers && engine.towers.count < maxTowers)
            if wantTower {
                guard engine.gold >= kind.cost, let cell = bestCell(for: kind, engine),
                      engine.build(kind, at: cell) != nil else { return }
                built += 1
                spentOnTowers += kind.cost
                continue
            }
            // Cheapest next upgrade: main path first, other path up to tier 2.
            var best: (tower: Tower, path: Int, cost: Int, affordable: Bool)?
            for tower in engine.towers {
                for path in [mainPath(tower), 1 - mainPath(tower)] {
                    let candidate: (Int, Bool)? = switch engine.upgradeStatus(towerID: tower.id, path: path) {
                    case let .available(cost): (cost, true)
                    case let .unaffordable(cost): (cost, false)
                    default: nil
                    }
                    if let (cost, affordable) = candidate {
                        if cost < (best?.cost ?? .max) { best = (tower, path, cost, affordable) }
                        break
                    }
                }
            }
            if let best {
                guard best.affordable, engine.upgrade(towerID: best.tower.id, path: best.path) else { return }
                spentOnUpgrades += best.cost
            } else {
                guard engine.towers.count < maxTowers + 6, engine.gold >= kind.cost,
                      let cell = bestCell(for: kind, engine), engine.build(kind, at: cell) != nil else { return }
                built += 1
                spentOnTowers += kind.cost
            }
        }
    }

    func bestCell(for kind: TowerKind, _ engine: GameEngine) -> GridPoint? {
        let samples = engine.paths.flatMap { $0.samples(spacing: 0.25) }
        let range = CGFloat(kind.baseStats.range)
        var best: GridPoint?
        var bestScore = -1
        for row in 0..<engine.map.rows {
            for col in 0..<engine.map.columns {
                let cell = GridPoint(col, row)
                guard engine.placementCheck(kind, at: cell) == .ok else { continue }
                let score = samples.filter { $0.distance(to: cell.center) <= range }.count
                if score > bestScore {
                    bestScore = score
                    best = cell
                }
            }
        }
        return best
    }
}

func simulate(_ map: MapDefinition, research: ResearchState, label: String, maxTowers: Int, endless: Bool = false) {
    let engine = GameEngine(map: map, waves: map.waves, research: research)
    var player = GreedyPlayer(research: research, maxTowers: maxTowers)
    let dt = 1.0 / 60.0
    var clock = 0.0
    var log: [String] = []
    player.act(engine)
    engine.startNextWave()
    var lastWave = 0
    var livesAtWaveStart = engine.lives
    var frame = 0
    while clock < 7200 {
        engine.step(dt)
        clock += dt
        frame += 1
        for event in engine.drainEvents() {
            if case let .waveCleared(number, _) = event, livesAtWaveStart != engine.lives {
                log.append("w\(number):-\(livesAtWaveStart - engine.lives)")
            }
        }
        if engine.phase == .victory {
            if endless { engine.continueEndless() } else { break }
        }
        if engine.phase == .defeat { break }
        if engine.waveNumber != lastWave {
            lastWave = engine.waveNumber
            livesAtWaveStart = engine.lives
        }
        if frame % 30 == 0 { player.act(engine) }
    }
    let result = engine.phase == .victory ? "VICTORY" : "DEFEAT at wave \(engine.waveNumber)"
    let towers = engine.towers.map { "\($0.kind.shortName)\($0.tiers[0])\($0.tiers[1])" }.joined(separator: " ")
    print("[\(map.name)/\(map.difficulty.title) \(label)] \(result)  lives \(engine.lives)/\(map.startingLives)  gold earned \(engine.stats.goldEarned)  powers \(engine.stats.powersUsed)")
    print("  leaks: \(log.isEmpty ? "none" : log.joined(separator: " "))")
    print("  towers: \(towers)")
}

for map in MapDefinition.all {
    simulate(map, research: ResearchState(), label: "fresh", maxTowers: 10)
    simulate(map, research: .complete, label: "researched", maxTowers: 14)
}
simulate(.circuit, research: .complete, label: "endless", maxTowers: 14, endless: true)
