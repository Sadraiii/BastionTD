import Foundation
import Observation

enum GameSpeed: Int, CaseIterable {
    case normal = 1, fast = 2, faster = 3

    var next: GameSpeed { GameSpeed(rawValue: rawValue % 3 + 1) ?? .normal }
    var label: String { "\(rawValue)X" }
}

enum GameOutcome: Equatable {
    case victory(stars: Int)
    case defeat
}

/// One upgrade path as shown in the hero panel.
struct PathSnapshot: Equatable {
    let index: Int
    let name: String
    let tier: Int
    let nextName: String?
    let nextDetail: String?
    let status: UpgradeStatus
}

struct PowerSnapshot: Equatable {
    let name: String
    let detail: String
    let isReady: Bool
    /// 0 just used ... 1 ready, in steps of 5%.
    let charge: Double
    let secondsLeft: Int
}

/// What the hero panel shows for the selected tower.
struct TowerSnapshot: Equatable {
    let id: Int
    let kind: TowerKind
    let tiers: [Int]
    let stats: TowerStats
    let paths: [PathSnapshot]
    let power: PowerSnapshot?
    let sellValue: Int
    let targeting: TargetingMode
    let kills: Int
    let isDisabled: Bool
    let combos: [String]
    /// Extra damage from growing, in percent.
    let growth: Int
}

struct SkillSnapshot: Equatable {
    let index: Int
    let name: String
    let detail: String
    /// Researched level; 0 means locked.
    let level: Int
    let isReady: Bool
    let charge: Double
    let secondsLeft: Int
}

/// What the commander panel shows.
struct CommanderSnapshot: Equatable {
    let kind: CommanderKind
    let skin: CommanderSkin
    let level: Int
    /// Progress to the next level in steps of 5%; 1 at the top level.
    let xp: Double
    let skills: [SkillSnapshot]
    /// The two evolutions to pick from; empty when none is waiting.
    let choices: [CommanderForm]
    /// The latest evolution picked.
    let formName: String?
}

/// A hero power in the quick-cast bar.
struct PowerBarItem: Equatable, Identifiable {
    let id: Int
    let kind: TowerKind
    let level: Int
    let name: String
    let isReady: Bool
    let charge: Double
}

/// The toughest boss on the field, for the health bar.
struct BossBar: Equatable {
    let name: String
    /// Health left in steps of 2%.
    let health: Double
}

/// How many of one villain the next wave brings.
struct ScoutEntry: Equatable {
    let kind: EnemyKind
    var count: Int
}

struct WaveBanner: Equatable, Identifiable {
    let id: Int
    let title: String
    let subtitle: String?
    let isBoss: Bool
}

/// Rewards granted when a run ends.
struct RunRewards: Equatable {
    var researchPoints = 0
    var medals: [Medal] = []
}

/// A match in progress, stored as the player's commands and the step each happened on.
/// The engine is deterministic, so replaying them rebuilds the exact same battlefield.
struct SavedMatch: Codable {
    /// Raised whenever a change would make older saves replay differently, so those aren't offered for resume.
    static let currentRules = 4

    enum Command: Codable {
        case build(TowerKind, GridPoint)
        case upgrade(towerID: Int, path: Int)
        case sell(towerID: Int)
        case targeting(TargetingMode, towerID: Int)
        case power(towerID: Int)
        case startWave
        case continueEndless
        case moveCommander(GridPoint)
        case skill(Int)
        case evolve(Int)
    }

    struct Entry: Codable {
        let step: Int
        let command: Command
    }

    let mapID: String
    let setup: MatchSetup
    let research: ResearchState
    var entries: [Entry] = []
    var steps = 0
    /// Nil in saves made before rules numbers existed.
    var rules: Int? = SavedMatch.currentRules

    var map: MapDefinition? { (MapDefinition.all + [.arena]).first { $0.id == mapID } }
}

/// Connects the engine, the SpriteKit scene and the SwiftUI interface.
///
/// The scene calls `tick` every frame; the session advances the engine with a fixed
/// timestep and republishes the few values SwiftUI shows (only when they change).
/// UI controls call the command methods below.
@MainActor
@Observable
final class GameSession {
    let id = UUID()
    let map: MapDefinition
    let setup: MatchSetup
    let totalWaves: Int
    @ObservationIgnored let engine: GameEngine
    @ObservationIgnored let scene: GameScene

    private(set) var gold = 0
    private(set) var lives = 0
    private(set) var waveNumber = 0
    private(set) var isEndless = false
    private(set) var phase: GameEngine.Phase = .preparing
    private(set) var intermissionSeconds = 0
    private(set) var earlyBonus = 0
    private(set) var waveProgress: Double = 0
    private(set) var enemiesRemaining = 0
    private(set) var towerCount = 0
    private(set) var selectedTower: TowerSnapshot?
    private(set) var powers: [PowerBarItem] = []
    private(set) var commander: CommanderSnapshot?
    private(set) var isCommanderSelected = false
    private(set) var buildKind: TowerKind?
    private(set) var pendingCell: GridPoint?
    private(set) var pendingResult: PlacementResult?
    private(set) var outcome: GameOutcome?
    private(set) var banner: WaveBanner?
    /// Short-lived message such as "No enemies in range".
    private(set) var toast: String?
    /// Increments whenever lives are lost so views can flash.
    private(set) var damagePulse = 0
    private(set) var bossBar: BossBar?
    /// The villains of the next wave while it can be called; empty during a wave.
    private(set) var nextWave: [ScoutEntry] = []
    private(set) var stats = GameStats()
    private(set) var rewards = RunRewards()
    private(set) var coachEnabled: Bool
    var isPaused = false
    var speed: GameSpeed = .normal

    @ObservationIgnored private var accumulator: Double = 0
    @ObservationIgnored private var selectedTowerID: Int?
    @ObservationIgnored private var bannerTimer: Double = 0
    @ObservationIgnored private var toastTimer: Double = 0
    @ObservationIgnored private var bannerCounter = 0
    @ObservationIgnored private var awardedPoints = 0
    @ObservationIgnored private var victoryStars = 0
    @ObservationIgnored private var highestTier = 0
    @ObservationIgnored private var isDemo = false
    @ObservationIgnored private var demoClock: Double = 0
    @ObservationIgnored private var save: SavedMatch
    @ObservationIgnored private var bankedCommanderXP = 0
    @ObservationIgnored private var scoutedWave = -1
    @ObservationIgnored private var gateShut = false

    private static let fixedStep = 1.0 / 60.0

    init(map: MapDefinition, setup: MatchSetup = MatchSetup(), resuming saved: SavedMatch? = nil) {
        self.map = map
        self.setup = setup
        // Daily challenges give everyone the full research tree.
        let research = saved?.research ?? (setup.day == nil ? PlayerProgress.research : .complete)
        let engine = GameEngine(map: map, waves: setup.bossRush ? WaveLibrary.bossRush : map.waves,
                                research: research, setup: setup, seed: setup.seed)
        self.engine = engine
        self.totalWaves = engine.totalWaves
        self.scene = GameScene(map: map, paths: engine.paths)
        self.coachEnabled = !PlayerProgress.coachCompleted
        self.save = SavedMatch(mapID: map.id, setup: setup, research: research)
        scene.session = self
        if let saved { replay(saved) }
        if let pool = setup.heroPool {
            let rules = (TowerKind.allCases.filter(pool.contains).map(\.name) + Modifier.allCases.filter(setup.modifiers.contains).map(\.title))
            showBanner(title: "DAILY CHALLENGE", subtitle: rules.joined(separator: ", ").uppercased(), isBoss: false)
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-richStart") { engine.debugGrantGold(5000) }
        if ProcessInfo.processInfo.arguments.contains("-demo") { setUpDemo() }
        #endif
        sync()
    }

    // MARK: Saving and resuming

    private func record(_ command: SavedMatch.Command) {
        save.entries.append(SavedMatch.Entry(step: save.steps, command: command))
        PlayerProgress.savedMatch = save
    }

    /// Rebuilds a saved match by rerunning its commands on the steps they happened on.
    private func replay(_ saved: SavedMatch) {
        for entry in saved.entries {
            advance(to: entry.step)
            switch entry.command {
            case let .build(kind, cell): engine.build(kind, at: cell)
            case let .upgrade(id, path): engine.upgrade(towerID: id, path: path)
            case let .sell(id): engine.sell(towerID: id)
            case let .targeting(mode, id): engine.setTargeting(mode, towerID: id)
            case let .power(id): engine.activatePower(towerID: id)
            case .startWave: engine.startNextWave()
            case .continueEndless: engine.continueEndless()
            case let .moveCommander(cell): engine.moveCommander(to: cell)
            case let .skill(index): engine.useSkill(index)
            case let .evolve(option): engine.evolveCommander(option)
            }
            save.entries.append(entry)
        }
        advance(to: saved.steps)
        scene.restoreTowers()
        isPaused = true
    }

    /// Steps the engine without rendering.
    private func advance(to step: Int) {
        drainReplayEvents()
        while save.steps < step {
            engine.step(Self.fixedStep)
            save.steps += 1
            drainReplayEvents()
        }
    }

    /// Keeps only what the session needs from replayed events; the rest were shown last time.
    private func drainReplayEvents() {
        for event in engine.drainEvents() {
            switch event {
            case let .towerUpgraded(_, _, tier):
                highestTier = max(highestTier, tier)
            case .victory:
                victoryStars = Self.stars(lives: engine.lives, starting: engine.startingLives)
                awardedPoints = researchPoints(wavesCleared: engine.wavesCleared, victory: true)
            default:
                break
            }
        }
    }

    // MARK: Frame update

    /// Advances the simulation by real elapsed time and returns the events to render.
    func tick(realDelta: Double) -> [GameEvent] {
        if bannerTimer > 0 {
            bannerTimer -= realDelta
            if bannerTimer <= 0 { banner = nil }
        }
        if toastTimer > 0 {
            toastTimer -= realDelta
            if toastTimer <= 0 { toast = nil }
        }
        if !isPaused && outcome == nil {
            accumulator += realDelta * Double(speed.rawValue)
            var steps = 0
            while accumulator >= Self.fixedStep && steps < 12 {
                engine.step(Self.fixedStep)
                save.steps += 1
                accumulator -= Self.fixedStep
                steps += 1
            }
            if steps == 12 { accumulator = 0 }
        }
        #if DEBUG
        if isDemo { runDemo(realDelta) }
        #endif
        let events = engine.drainEvents()
        if !events.isEmpty { handle(events) }
        sync()
        return events
    }

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case let .waveStarted(number, isBoss, newKinds):
                let subtitle: String?
                if isBoss {
                    let boss = engine.waveDefinition(number: number).groups.map(\.kind).first(where: \.isBoss) ?? .titan
                    subtitle = "BOSS: \(boss.name) - \(boss.ability)"
                } else if let kind = newKinds.first {
                    let tags = kind.traitTags.isEmpty ? "" : " [\(kind.traitTags.joined(separator: ", "))]"
                    subtitle = "NEW VILLAIN: \(kind.name)\(tags) - \(kind.ability)"
                } else {
                    subtitle = nil
                }
                let title = number == totalWaves && !isEndless ? "FINAL WAVE" : "WAVE \(number)"
                showBanner(title: title, subtitle: subtitle, isBoss: isBoss)
                if number >= 2 { finishCoach() }
            case let .enemyLeaked(_, _, livesLost) where livesLost > 0:
                damagePulse += 1
            case .goldStolen:
                showToast("GOLD STOLEN")
            case let .towerSold(towerID, _, _):
                if towerID == selectedTowerID { selectedTowerID = nil }
            case let .towerUpgraded(_, _, tier):
                highestTier = max(highestTier, tier)
            case let .powerActivated(_, _, name), let .commanderSkill(_, name, _, _):
                showToast(name.uppercased() + "!")
            case let .comboFormed(name, _, _):
                if PlayerProgress.discoverCombo(name) { showToast("NEW COMBO: \(name.uppercased())") }
            case .commanderLevelUp:
                if engine.commander?.pendingStage != nil { showToast("CHOOSE AN EVOLUTION") }
            case .victory:
                victoryStars = Self.stars(lives: engine.lives, starting: engine.startingLives)
                if !setup.isEvent { PlayerProgress.recordVictory(on: map, stars: victoryStars) }
                PlayerProgress.savedMatch = nil
                outcome = .victory(stars: victoryStars)
                finishRun(victory: true)
            case .defeat:
                PlayerProgress.savedMatch = nil
                outcome = .defeat
                finishRun(victory: victoryStars > 0)
            default:
                break
            }
        }
    }

    static func stars(lives: Int, starting: Int) -> Int {
        let ratio = Double(lives) / Double(max(1, starting))
        return ratio >= 0.9 ? 3 : ratio >= 0.5 ? 2 : 1
    }

    private func showBanner(title: String, subtitle: String?, isBoss: Bool) {
        bannerCounter += 1
        banner = WaveBanner(id: bannerCounter, title: title, subtitle: subtitle, isBoss: isBoss)
        bannerTimer = subtitle == nil ? 1.8 : 3.4
    }

    private func showToast(_ text: String) {
        toast = text
        toastTimer = 1.4
    }

    /// Grants Research Points and medals. Called on victory and again if Endless ends.
    private func finishRun(victory: Bool) {
        cancelBuild()
        selectedTowerID = nil
        isPaused = false
        stats = engine.stats

        let cleared = engine.wavesCleared
        let total = researchPoints(wavesCleared: cleared, victory: victory)
        let earned = max(0, total - awardedPoints)
        awardedPoints = total

        let run = RunSummary(
            map: map, victory: victory, wavesCleared: cleared, livesLost: engine.stats.livesLost,
            stats: engine.stats, towerCount: engine.towers.count, highestTier: highestTier
        )
        // Daily challenges don't count toward map progress or medals; events don't count toward map progress.
        var medals: [Medal] = []
        if let day = setup.day {
            PlayerProgress.recordDaily(day, wavesCleared: cleared)
        } else if setup.bossRush {
            PlayerProgress.recordBossRush(wavesCleared: cleared)
            medals = PlayerProgress.awardMedals(for: run)
        } else {
            medals = PlayerProgress.awardMedals(for: run)
            PlayerProgress.recordEndless(on: map, wave: cleared)
        }
        PlayerProgress.researchPoints += earned
        if let commander = engine.commander {
            PlayerProgress.addCommanderXP(commander.kind, commander.earnedXP - bankedCommanderXP)
            bankedCommanderXP = commander.earnedXP
        }
        rewards = RunRewards(
            researchPoints: rewards.researchPoints + earned + medals.reduce(0) { $0 + $1.reward },
            medals: rewards.medals + medals
        )
    }

    /// Research Points for the run so far, with the challenge bonus.
    private func researchPoints(wavesCleared: Int, victory: Bool) -> Int {
        let points = ResearchRewards.points(for: map, wavesCleared: wavesCleared, victory: victory, stars: victoryStars)
        return points * (100 + setup.bonusPercent) / 100
    }

    /// Copies engine state into observable properties, touching only what changed.
    private func sync() {
        if gold != engine.gold { gold = engine.gold }
        if lives != engine.lives { lives = engine.lives }
        if waveNumber != engine.waveNumber { waveNumber = engine.waveNumber }
        if isEndless != engine.isEndless { isEndless = engine.isEndless }
        if phase != engine.phase { phase = engine.phase }
        let seconds = Int(engine.intermissionRemaining.rounded(.up))
        if intermissionSeconds != seconds { intermissionSeconds = seconds }
        if earlyBonus != engine.earlyCallBonus { earlyBonus = engine.earlyCallBonus }
        let progress = (engine.waveProgress * 50).rounded() / 50
        if waveProgress != progress { waveProgress = progress }
        if enemiesRemaining != engine.enemiesRemaining { enemiesRemaining = engine.enemiesRemaining }
        if towerCount != engine.towers.count { towerCount = engine.towers.count }

        let boss = engine.enemies.filter { $0.kind.isBoss && $0.isTargetable }.max { $0.health < $1.health }
        let bossSnapshot = boss.map { BossBar(name: $0.kind.name, health: ($0.healthFraction * 50).rounded() / 50) }
        if bossBar != bossSnapshot { bossBar = bossSnapshot }

        let upcoming = engine.canStartWave ? engine.waveNumber + 1 : 0
        if upcoming != scoutedWave {
            scoutedWave = upcoming
            var entries: [ScoutEntry] = []
            if upcoming > 0 {
                for group in engine.waveDefinition(number: upcoming).groups {
                    let count = engine.spawnCount(of: group)
                    if let i = entries.firstIndex(where: { $0.kind == group.kind }) {
                        entries[i].count += count
                    } else {
                        entries.append(ScoutEntry(kind: group.kind, count: count))
                    }
                }
            }
            nextWave = entries
        }

        let snapshot = selectedTowerID.flatMap(makeSnapshot)
        if snapshot == nil { selectedTowerID = nil }
        if selectedTower != snapshot { selectedTower = snapshot }

        let bar = engine.towers.compactMap { tower -> PowerBarItem? in
            guard let power = tower.power else { return nil }
            return PowerBarItem(
                id: tower.id, kind: tower.kind, level: tower.visualLevel, name: power.name,
                isReady: tower.isPowerReady, charge: Self.charge(of: tower)
            )
        }
        if powers != bar { powers = bar }

        let commanderSnapshot = engine.commander.map(Self.snapshot)
        if commander != commanderSnapshot { commander = commanderSnapshot }

        if gateShut != engine.isGateShut {
            gateShut = engine.isGateShut
            showToast(gateShut ? "GATE SHUT" : "GATE OPEN")
        }

        if let kind = buildKind, let cell = pendingCell {
            let result = engine.placementCheck(kind, at: cell)
            if pendingResult != result { pendingResult = result }
        }
    }

    private static func charge(of tower: Tower) -> Double {
        guard let power = tower.power else { return 0 }
        let raw = 1 - tower.powerCooldown / power.cooldown
        return (raw * 20).rounded(.down) / 20
    }

    private static func snapshot(of commander: Commander) -> CommanderSnapshot {
        let skills = commander.kind.skills.enumerated().map { index, skill in
            let left = commander.skillCooldowns[index]
            return SkillSnapshot(
                index: index, name: skill.name, detail: skill.detail, level: commander.skillLevels[index],
                isReady: commander.skillLevels[index] > 0 && left <= 0,
                charge: ((1 - left / (skill.cooldown * commander.recharge)) * 20).rounded(.down) / 20, secondsLeft: Int(left.rounded(.up))
            )
        }
        let xp = commander.level >= CommanderKind.maxLevel
            ? 1 : (Double(commander.xp) / Double(CommanderKind.xpToNext(level: commander.level)) * 20).rounded(.down) / 20
        return CommanderSnapshot(
            kind: commander.kind, skin: commander.skin, level: commander.level, xp: xp, skills: skills,
            choices: commander.pendingStage.map { commander.kind.forms[$0] } ?? [], formName: commander.forms.last?.name
        )
    }

    private func makeSnapshot(_ id: Int) -> TowerSnapshot? {
        guard let tower = engine.tower(id: id) else { return nil }
        let paths = tower.kind.paths.enumerated().map { index, path in
            let next = tower.nextTier(onPath: index)
            return PathSnapshot(
                index: index, name: path.name, tier: tower.tiers[index],
                nextName: next?.name, nextDetail: next?.detail,
                status: engine.upgradeStatus(towerID: id, path: index)
            )
        }
        let power = tower.power.map { definition in
            PowerSnapshot(
                name: definition.name, detail: definition.detail, isReady: tower.isPowerReady,
                charge: Self.charge(of: tower), secondsLeft: Int(tower.powerCooldown.rounded(.up))
            )
        }
        return TowerSnapshot(
            id: tower.id, kind: tower.kind, tiers: tower.tiers, stats: tower.stats, paths: paths,
            power: power, sellValue: tower.sellValue, targeting: tower.targeting,
            kills: tower.kills, isDisabled: tower.isDisabled, combos: tower.combos.map { HeroCatalog.combos[$0].name },
            growth: Int((tower.growthBonus * 100).rounded())
        )
    }

    // MARK: Building

    var canStartWave: Bool { outcome == nil && engine.canStartWave }

    func isHeroUnlocked(_ kind: TowerKind) -> Bool { engine.research.isHeroUnlocked(kind) && engine.allows(kind) }

    func chooseBuild(_ kind: TowerKind) {
        guard outcome == nil else { return }
        guard engine.allows(kind) else {
            showToast("NOT ALLOWED IN THIS CHALLENGE")
            SoundEngine.shared.play(.error)
            return
        }
        guard isHeroUnlocked(kind) else {
            showToast("RECRUIT \(kind.name.uppercased()) IN THE LAB")
            SoundEngine.shared.play(.error)
            return
        }
        if buildKind == kind {
            cancelBuild()
            return
        }
        selectedTowerID = nil
        isCommanderSelected = false
        buildKind = kind
        pendingCell = nil
        pendingResult = nil
        SoundEngine.shared.play(.tap)
        sync()
    }

    func cancelBuild() {
        buildKind = nil
        pendingCell = nil
        pendingResult = nil
    }

    /// Shows the ghost tower on `cell` (or hides it when the touch is off the board).
    func previewPlacement(at cell: GridPoint?) {
        guard let kind = buildKind else { return }
        pendingCell = cell
        pendingResult = cell.map { engine.placementCheck(kind, at: $0) }
        if let result = pendingResult, result != .ok {
            SoundEngine.shared.play(.error)
        } else if cell != nil {
            SoundEngine.shared.play(.tap)
        }
    }

    func confirmBuild() {
        guard let kind = buildKind, let cell = pendingCell else { return }
        let result = engine.placementCheck(kind, at: cell)
        guard result == .ok, engine.build(kind, at: cell) != nil else {
            pendingResult = result
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
            return
        }
        record(.build(kind, cell))
        cancelBuild()
        sync()
    }

    // MARK: Selection and upgrades

    func tapCell(_ cell: GridPoint?) {
        guard outcome == nil else { return }
        if let cell, cell == engine.commander?.cell {
            if isCommanderSelected { deselectCommander() } else { selectCommander() }
            return
        }
        if isCommanderSelected, let cell, engine.tower(at: cell) == nil {
            if engine.moveCommander(to: cell) {
                record(.moveCommander(cell))
                SoundEngine.shared.play(.tap)
            } else {
                deselectCommander()
            }
            return
        }
        isCommanderSelected = false
        guard let cell, let tower = engine.tower(at: cell) else {
            if selectedTowerID != nil { deselectTower() }
            return
        }
        if selectedTowerID == tower.id {
            deselectTower()
        } else {
            selectedTowerID = tower.id
            SoundEngine.shared.play(.tap)
            if waveNumber >= 1 { finishCoach() }
            sync()
        }
    }

    func deselectTower() {
        selectedTowerID = nil
        sync()
    }

    // MARK: Commander

    func selectCommander() {
        guard outcome == nil, engine.commander != nil else { return }
        cancelBuild()
        selectedTowerID = nil
        isCommanderSelected = true
        SoundEngine.shared.play(.tap)
        sync()
    }

    func deselectCommander() {
        isCommanderSelected = false
        sync()
    }

    func useSkill(_ index: Int) {
        guard outcome == nil, !isPaused, let commander = engine.commander else { return }
        if engine.useSkill(index) {
            record(.skill(index))
            Haptics.impact(.heavy)
        } else {
            if index == CommanderKind.researchableSkills && commander.skillLevels[index] == 0 {
                showToast("REACH LEVEL \(CommanderKind.maxLevel) FIRST")
            } else if commander.skillLevels[index] == 0 {
                showToast("UNLOCK IT IN THE RESEARCH LAB")
            } else if commander.skillCooldowns[index] <= 0 {
                showToast("NO ENEMIES IN RANGE")
            }
            SoundEngine.shared.play(.error)
        }
        sync()
    }

    func evolveCommander(_ option: Int) {
        guard outcome == nil, engine.evolveCommander(option) else { return }
        record(.evolve(option))
        sync()
    }

    func upgradeSelected(path: Int) {
        guard let id = selectedTowerID else { return }
        if engine.upgrade(towerID: id, path: path) {
            record(.upgrade(towerID: id, path: path))
        } else {
            switch engine.upgradeStatus(towerID: id, path: path) {
            case .needsResearch: showToast("UNLOCK IT IN THE RESEARCH LAB")
            case .blocked: showToast("ONLY ONE PATH CAN GO PAST TIER 2")
            case .unaffordable: showToast("NOT ENOUGH GOLD")
            default: break
            }
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
        }
        sync()
    }

    func sellSelected() {
        guard let id = selectedTowerID else { return }
        guard !setup.modifiers.contains(.hardMode) else {
            showToast("NO SELLING IN HARD MODE")
            SoundEngine.shared.play(.error)
            return
        }
        if engine.sell(towerID: id) != nil { record(.sell(towerID: id)) }
        selectedTowerID = nil
        sync()
    }

    func setTargeting(_ mode: TargetingMode) {
        guard let id = selectedTowerID else { return }
        engine.setTargeting(mode, towerID: id)
        record(.targeting(mode, towerID: id))
        SoundEngine.shared.play(.tap)
        sync()
    }

    func activatePower(towerID: Int) {
        guard outcome == nil, !isPaused else { return }
        guard !setup.modifiers.contains(.noPowers) else {
            showToast("POWERS ARE OFF")
            SoundEngine.shared.play(.error)
            return
        }
        if engine.activatePower(towerID: towerID) {
            record(.power(towerID: towerID))
            Haptics.impact(.heavy)
        } else {
            if let tower = engine.tower(id: towerID), tower.isPowerReady {
                showToast("NO ENEMIES IN RANGE")
            }
            SoundEngine.shared.play(.error)
        }
        sync()
    }

    // MARK: Flow

    func startWave() {
        guard canStartWave else { return }
        if engine.startNextWave() { record(.startWave) }
        sync()
    }

    func continueEndless() {
        guard case .victory = outcome else { return }
        engine.continueEndless()
        record(.continueEndless)
        outcome = nil
        showBanner(title: "ENDLESS MODE", subtitle: "HOW LONG CAN THE BASTION HOLD?", isBoss: false)
        sync()
    }

    func togglePause() {
        guard outcome == nil else { return }
        isPaused.toggle()
        SoundEngine.shared.play(.tap)
    }

    /// Pauses and saves when the app leaves the foreground, since iOS may close it from there.
    func pauseForInterruption() {
        guard outcome == nil else { return }
        isPaused = true
        PlayerProgress.savedMatch = save
    }

    func cycleSpeed() {
        speed = speed.next
        SoundEngine.shared.play(.tap)
    }

    // MARK: First-game coaching

    /// Contextual hint for first-time players, or nil once they have the hang of it.
    var coachMessage: String? {
        guard coachEnabled, outcome == nil else { return nil }
        if buildKind != nil, pendingCell != nil, let result = pendingResult {
            return result == .ok
                ? "Tap the ghost hero again (or BUILD) to place it."
                : "\(result.message). Try a highlighted tile."
        }
        if buildKind != nil { return "Tap a highlighted tile to preview the hero and its range." }
        if towerCount == 0 { return "Villains march along the dirt path to your crystal. Pick a hero below." }
        if phase == .preparing { return "Nice! Recruit more heroes, or press START WAVE when ready." }
        if waveNumber == 1 && selectedTower == nil { return "Tip: tap a hero to upgrade its two power paths." }
        return nil
    }

    func finishCoach() {
        guard coachEnabled else { return }
        coachEnabled = false
        PlayerProgress.coachCompleted = true
    }

    // MARK: Debug demo

    #if DEBUG
    /// `-demo` (Debug only): places one of every hero, upgrades them, keeps calling
    /// waves and fires powers when ready, so simulator screenshots show everything.
    private func setUpDemo() {
        isDemo = true
        engine.debugGrantGold(60_000)
        let samples = engine.path.samples(spacing: 0.25)
        let cells = (0..<map.rows).flatMap { row in (0..<map.columns).map { GridPoint($0, row) } }
            .filter(map.isBuildable)
            .sorted { a, b in
                samples.filter { $0.distance(to: a.center) <= 2 }.count > samples.filter { $0.distance(to: b.center) <= 2 }.count
            }
        for (index, kind) in TowerKind.allCases.enumerated() where index < cells.count {
            guard let tower = engine.build(kind, at: cells[index]) else { continue }
            let main = index % 2
            for _ in 0..<3 { engine.upgrade(towerID: tower.id, path: main) }
            engine.upgrade(towerID: tower.id, path: 1 - main)
        }
    }

    private func runDemo(_ dt: Double) {
        demoClock += dt
        guard demoClock > 1 else { return }
        demoClock = 0
        if engine.canStartWave { engine.startNextWave() }
        for tower in engine.towers where tower.isPowerReady && engine.powerHasTargets(towerID: tower.id) {
            engine.activatePower(towerID: tower.id)
        }
    }
    #endif
}
