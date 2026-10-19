import Foundation

enum Difficulty: String, CaseIterable, Codable {
    case easy, normal, hard

    var title: String { rawValue.capitalized }

    /// Multiplies every enemy's health on maps of this difficulty.
    var healthMultiplier: Double {
        switch self {
        case .easy: 0.85
        case .normal: 1.0
        case .hard: 1.1
        }
    }
}

/// Campaign chapters. Each world groups its levels and brings its own villains.
enum World: Int, CaseIterable, Identifiable {
    case grassland, desert, swamp, snowfield, volcano, caves, highlands

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .grassland: "Grassland"
        case .desert: "Desert"
        case .swamp: "Swamp"
        case .snowfield: "Snowfield"
        case .volcano: "Volcano"
        case .caves: "Crystal Caves"
        case .highlands: "Highlands"
        }
    }
}

/// The look of a battlefield: ground and path colors and the decoration sprites.
enum Terrain: String {
    case grassland, desert, snowfield, volcanic, swamp, beach, caves, highlands
}

/// A battlefield layout: grid size, the enemy route and unbuildable decoration.
///
/// The route is a list of axis-aligned waypoints. The first waypoint may sit just
/// outside the grid so enemies walk in from the edge; the last one holds the crystal
/// the player defends. Optional branches are extra routes to the same crystal that split
/// off and rejoin, or come in from another edge; villains take turns between the routes.
struct MapDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let difficulty: Difficulty
    let terrain: Terrain
    let world: World
    let columns: Int
    let rows: Int
    let waypoints: [GridPoint]
    /// The main route followed by any branches.
    let routes: [[GridPoint]]
    let obstacles: Set<GridPoint>
    /// Water tiles: only naval heroes can be placed there.
    let water: Set<GridPoint>
    /// Road tiles where villains walk slower (mud) or faster (ice).
    let mud: Set<GridPoint>
    let ice: Set<GridPoint>
    /// Road tiles that hide villains from heroes that can't see cloaked ones.
    let mist: Set<GridPoint>
    /// Raised tiles that give the hero built there more range.
    let highGround: Set<GridPoint>
    let startingGold: Int
    let startingLives: Int
    /// Generated waves for the level; nil plays the classic 20-wave campaign.
    let wavePlan: WavePlan?
    let pathCells: Set<GridPoint>

    init(
        id: String,
        name: String,
        tagline: String,
        difficulty: Difficulty,
        terrain: Terrain = .grassland,
        world: World = .grassland,
        columns: Int = 14,
        rows: Int = 8,
        waypoints: [GridPoint],
        branches: [[GridPoint]] = [],
        obstacles: Set<GridPoint>,
        water: Set<GridPoint> = [],
        mud: Set<GridPoint> = [],
        ice: Set<GridPoint> = [],
        mist: Set<GridPoint> = [],
        highGround: Set<GridPoint> = [],
        startingGold: Int,
        startingLives: Int,
        wavePlan: WavePlan? = nil
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.difficulty = difficulty
        self.terrain = terrain
        self.world = world
        self.columns = columns
        self.rows = rows
        self.waypoints = waypoints
        self.routes = [waypoints] + branches
        self.obstacles = obstacles
        self.water = water
        self.mud = mud
        self.ice = ice
        self.mist = mist
        self.highGround = highGround
        self.startingGold = startingGold
        self.startingLives = startingLives
        self.wavePlan = wavePlan
        self.pathCells = routes.reduce(into: Set()) { $0.formUnion(Self.cells(along: $1, columns: columns, rows: rows)) }
    }

    var coreCell: GridPoint { waypoints[waypoints.count - 1] }

    var waves: [WaveDefinition] {
        guard let wavePlan else { return WaveLibrary.standard }
        let seed = id.unicodeScalars.reduce(UInt64(17)) { $0 &* 31 &+ UInt64($1.value) }
        return WaveLibrary.level(wavePlan, seed: seed)
    }

    /// Like "2-3": world number and level number within the world.
    var levelLabel: String {
        let level = (Self.all.filter { $0.world == world }.firstIndex(of: self) ?? 0) + 1
        return "\(world.rawValue + 1)-\(level)"
    }

    func contains(_ cell: GridPoint) -> Bool {
        (0..<columns).contains(cell.col) && (0..<rows).contains(cell.row)
    }

    func isBuildable(_ cell: GridPoint) -> Bool {
        contains(cell) && !pathCells.contains(cell) && !obstacles.contains(cell) && !water.contains(cell)
    }

    static func == (lhs: MapDefinition, rhs: MapDefinition) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private static func cells(along waypoints: [GridPoint], columns: Int, rows: Int) -> Set<GridPoint> {
        var result = Set<GridPoint>()
        for (from, to) in zip(waypoints, waypoints.dropFirst()) {
            precondition(from.col == to.col || from.row == to.row, "Path segments must be axis-aligned")
            let step = GridPoint((to.col - from.col).signum(), (to.row - from.row).signum())
            var cell = from
            while true {
                if (0..<columns).contains(cell.col) && (0..<rows).contains(cell.row) {
                    result.insert(cell)
                }
                if cell == to { break }
                cell = GridPoint(cell.col + step.col, cell.row + step.row)
            }
        }
        return result
    }
}

// MARK: - Built-in maps

extension MapDefinition {
    private static func points(_ list: [(Int, Int)]) -> [GridPoint] { list.map { GridPoint($0.0, $0.1) } }

    static let circuit = MapDefinition(
        id: "circuit",
        name: "Circuit",
        tagline: "An easy loop with lots of room to build.",
        difficulty: .easy,
        waypoints: points([(-1, 1), (2, 1), (2, 6), (5, 6), (5, 1), (8, 1), (8, 6), (11, 6), (11, 2), (13, 2)]),
        obstacles: Set(points([(0, 7), (4, 0), (13, 5), (10, 4)])),
        startingGold: 250,
        startingLives: 25
    )

    static let switchback = MapDefinition(
        id: "switchback",
        name: "Switchback",
        tagline: "Long straight lanes. Put heroes between them.",
        difficulty: .normal,
        waypoints: points([(-1, 1), (11, 1), (11, 4), (2, 4), (2, 6), (13, 6)]),
        obstacles: Set(points([(13, 0), (0, 7), (7, 7), (0, 3)])),
        startingGold: 220,
        startingLives: 20
    )

    static let overload = MapDefinition(
        id: "overload",
        name: "Overload",
        tagline: "A short path. Not much time to stop them.",
        difficulty: .hard,
        waypoints: points([(-1, 4), (3, 4), (3, 1), (7, 1), (7, 6), (10, 6), (10, 3), (13, 3)]),
        obstacles: Set(points([(0, 0), (12, 7), (5, 7), (13, 0)])),
        startingGold: 200,
        startingLives: 20
    )

    static let dunes = MapDefinition(
        id: "dunes",
        name: "Dunes",
        tagline: "A desert path with tight turns.",
        difficulty: .normal,
        terrain: .desert,
        world: .desert,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 2), (3, 2), (3, 7), (7, 7), (7, 1), (11, 1), (11, 7), (15, 7), (15, 3), (17, 3)]),
        obstacles: Set(points([(0, 0), (5, 4), (13, 4), (16, 9), (1, 9), (9, 9), (9, 0)])),
        startingGold: 300,
        startingLives: 25,
        wavePlan: WavePlan(count: 16, villains: [.drone, .runner, .sandworm, .ironclad, .berserker, .blastguard], boss: .titan, healthScale: 1.05)
    )

    static let bayou = MapDefinition(
        id: "bayou",
        name: "Bayou",
        tagline: "The path splits in two, then joins again.",
        difficulty: .hard,
        terrain: .swamp,
        world: .swamp,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 6), (3, 6), (3, 2), (11, 2), (11, 6), (16, 6), (16, 2), (19, 2)]),
        branches: [points([(-1, 6), (3, 6), (3, 10), (11, 10), (11, 6), (16, 6), (16, 2), (19, 2)])],
        obstacles: Set(points([(0, 0), (7, 6), (14, 9), (18, 6), (0, 11), (19, 11), (13, 0)])),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 16, villains: [.drone, .splitter, .husk, .medic, .bogWitch, .phantom], boss: .dreadnought, healthScale: 1.2)
    )

    static let glacier = MapDefinition(
        id: "glacier",
        name: "Glacier",
        tagline: "A long snowy path that zigzags across.",
        difficulty: .hard,
        terrain: .snowfield,
        world: .snowfield,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 9), (2, 9), (2, 2), (6, 2), (6, 10), (10, 10), (10, 2), (14, 2), (14, 10), (18, 10), (18, 5), (19, 5)]),
        obstacles: Set(points([(0, 0), (4, 11), (12, 0), (16, 4), (8, 6), (19, 11), (0, 5)])),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 18, villains: [.runner, .drone, .wisp, .frostborn, .yeti, .brute, .mirage], boss: .titan, healthScale: 1.3, midBoss: .titan)
    )

    static let caldera = MapDefinition(
        id: "caldera",
        name: "Caldera",
        tagline: "The path spirals in to the crystal.",
        difficulty: .hard,
        terrain: .volcanic,
        world: .volcano,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 1), (18, 1), (18, 10), (1, 10), (1, 4), (15, 4), (15, 7), (5, 7)]),
        obstacles: Set(points([(0, 11), (19, 0), (10, 2), (8, 5), (12, 9), (3, 8), (19, 11)])),
        startingGold: 220,
        startingLives: 15,
        wavePlan: WavePlan(count: 18, villains: [.drone, .pyrefiend, .berserker, .magmaGolem, .voidling, .gargoyle], boss: .overlord, healthScale: 1.45, midBoss: .titan)
    )

    static let harbor = MapDefinition(
        id: "harbor",
        name: "Harbor",
        tagline: "The path circles a lake. Riptide can fight from the water.",
        difficulty: .hard,
        world: .swamp,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 1), (16, 1), (16, 8), (2, 8), (2, 4)]),
        obstacles: Set(points([(0, 9), (17, 0), (17, 9), (9, 0)])),
        water: Set((5...12).flatMap { col in (3...6).map { GridPoint(col, $0) } }),
        startingGold: 320,
        startingLives: 25,
        wavePlan: WavePlan(count: 16, villains: [.drone, .runner, .crab, .splitter, .bogWitch, .wisp], boss: .dreadnought, healthScale: 1.2)
    )

    static let meadow = MapDefinition(
        id: "meadow",
        name: "Meadow",
        tagline: "A gentle loop through the fields.",
        difficulty: .normal,
        terrain: .grassland,
        world: .grassland,
        columns: 16,
        rows: 9,
        waypoints: points([(-1, 2), (5, 2), (5, 6), (10, 6), (10, 2), (15, 2)]),
        obstacles: Set(points([(0, 8), (8, 0), (14, 8), (12, 5)])),
        startingGold: 250,
        startingLives: 20,
        wavePlan: WavePlan(count: 12, villains: [.drone, .runner, .brute, .wisp, .medic, .berserker], boss: .titan, healthScale: 1.0)
    )

    static let oasis = MapDefinition(
        id: "oasis",
        name: "Oasis",
        tagline: "The path circles a desert pond.",
        difficulty: .normal,
        terrain: .desert,
        world: .desert,
        columns: 16,
        rows: 9,
        waypoints: points([(-1, 1), (13, 1), (13, 7), (3, 7), (3, 4)]),
        obstacles: Set(points([(15, 0), (0, 8), (15, 8), (10, 4)])),
        water: Set((6...9).flatMap { col in (3...5).map { GridPoint(col, $0) } }),
        startingGold: 260,
        startingLives: 20,
        wavePlan: WavePlan(count: 12, villains: [.drone, .runner, .sandworm, .ironclad, .berserker, .blastguard], boss: .titan, healthScale: 1.1)
    )

    static let canyon = MapDefinition(
        id: "canyon",
        name: "Canyon",
        tagline: "Steep switchbacks through red rock.",
        difficulty: .hard,
        terrain: .desert,
        world: .desert,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 7), (2, 7), (2, 2), (6, 2), (6, 7), (10, 7), (10, 2), (14, 2), (14, 7), (17, 7)]),
        obstacles: Set(points([(0, 0), (4, 5), (8, 0), (12, 5), (16, 0), (0, 9), (17, 9)])),
        startingGold: 260,
        startingLives: 20,
        wavePlan: WavePlan(count: 14, villains: [.drone, .runner, .sandworm, .ironclad, .berserker, .blastguard], boss: .titan, healthScale: 1.15)
    )

    static let lagoon = MapDefinition(
        id: "lagoon",
        name: "Lagoon",
        tagline: "Crabs crawl up from the sea.",
        difficulty: .hard,
        terrain: .beach,
        world: .desert,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 1), (6, 1), (6, 5), (12, 5), (12, 1), (17, 1)]),
        obstacles: Set(points([(0, 4), (9, 2), (15, 4), (17, 6)])),
        water: Set((2...15).flatMap { col in (7...9).map { GridPoint(col, $0) } }),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 14, villains: [.runner, .crab, .sandworm, .wisp, .ironclad, .pickpocket], boss: .dreadnought, healthScale: 1.2)
    )

    static let mire = MapDefinition(
        id: "mire",
        name: "Mire",
        tagline: "Deep bog. Watch for witches.",
        difficulty: .hard,
        terrain: .swamp,
        world: .swamp,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 8), (4, 8), (4, 1), (9, 1), (9, 8), (14, 8), (14, 3), (17, 3)]),
        obstacles: Set(points([(1, 1), (7, 5), (12, 5), (16, 8), (0, 0)])),
        startingGold: 280,
        startingLives: 20,
        wavePlan: WavePlan(count: 13, villains: [.drone, .splitter, .husk, .medic, .bogWitch, .phantom, .hexer, .gravecaller], boss: .dreadnought, healthScale: 1.25)
    )

    static let shore = MapDefinition(
        id: "shore",
        name: "Shore",
        tagline: "A long beach between two lagoons.",
        difficulty: .hard,
        terrain: .beach,
        world: .swamp,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 5), (6, 5), (6, 1), (12, 1), (12, 10), (17, 10), (17, 4), (19, 4)]),
        obstacles: Set(points([(4, 9), (9, 6), (19, 0), (19, 11), (9, 11)])),
        water: Set((14...15).flatMap { col in (2...7).map { GridPoint(col, $0) } }),
        startingGold: 320,
        startingLives: 20,
        wavePlan: WavePlan(count: 15, villains: [.drone, .runner, .crab, .splitter, .wisp, .bogWitch, .phantom], boss: .dreadnought, healthScale: 1.3)
    )

    static let tundra = MapDefinition(
        id: "tundra",
        name: "Tundra",
        tagline: "Wide frozen plains.",
        difficulty: .hard,
        terrain: .snowfield,
        world: .snowfield,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 2), (14, 2), (14, 5), (3, 5), (3, 8), (17, 8)]),
        obstacles: Set(points([(16, 0), (0, 7), (8, 0), (9, 7)])),
        startingGold: 280,
        startingLives: 20,
        wavePlan: WavePlan(count: 13, villains: [.runner, .drone, .wisp, .frostborn, .yeti, .brute, .mirage], boss: .titan, healthScale: 1.35, midBoss: .titan)
    )

    static let icefall = MapDefinition(
        id: "icefall",
        name: "Icefall",
        tagline: "A frozen spiral down the mountain.",
        difficulty: .hard,
        terrain: .snowfield,
        world: .snowfield,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 10), (17, 10), (17, 1), (2, 1), (2, 7), (13, 7), (13, 4), (6, 4)]),
        obstacles: Set(points([(0, 0), (19, 0), (19, 11), (9, 5)])),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 15, villains: [.runner, .drone, .wisp, .frostborn, .yeti, .brute, .mirage], boss: .dreadnought, healthScale: 1.4, midBoss: .titan)
    )

    static let avalanche = MapDefinition(
        id: "avalanche",
        name: "Avalanche",
        tagline: "Short and steep. The yetis are coming.",
        difficulty: .hard,
        terrain: .snowfield,
        world: .snowfield,
        columns: 16,
        rows: 9,
        waypoints: points([(-1, 4), (3, 4), (3, 1), (7, 1), (7, 7), (11, 7), (11, 1), (15, 1)]),
        obstacles: Set(points([(0, 0), (5, 4), (9, 4), (13, 6), (0, 8)])),
        startingGold: 280,
        startingLives: 15,
        wavePlan: WavePlan(count: 14, villains: [.runner, .drone, .wisp, .frostborn, .yeti, .brute, .mirage], boss: .overlord, healthScale: 1.45, midBoss: .titan)
    )

    static let ashlands = MapDefinition(
        id: "ashlands",
        name: "Ashlands",
        tagline: "Grey ash and glowing cracks.",
        difficulty: .hard,
        terrain: .volcanic,
        world: .volcano,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 1), (4, 1), (4, 8), (8, 8), (8, 3), (13, 3), (13, 8), (17, 8)]),
        obstacles: Set(points([(0, 9), (6, 5), (10, 6), (15, 4), (16, 0)])),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 14, villains: [.drone, .pyrefiend, .berserker, .blastguard, .magmaGolem, .voidling, .gargoyle, .sapper], boss: .titan, healthScale: 1.5, midBoss: .titan)
    )

    static let magmaFalls = MapDefinition(
        id: "magmafalls",
        name: "Magma Falls",
        tagline: "Two lava rivers that meet at the crystal.",
        difficulty: .hard,
        terrain: .volcanic,
        world: .volcano,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 5), (4, 5), (4, 1), (15, 1), (15, 5), (19, 5)]),
        branches: [points([(-1, 5), (4, 5), (4, 10), (15, 10), (15, 5), (19, 5)])],
        obstacles: Set(points([(9, 5), (0, 0), (0, 11), (19, 0), (19, 11), (17, 8)])),
        startingGold: 400,
        startingLives: 25,
        wavePlan: WavePlan(count: 15, villains: [.drone, .pyrefiend, .berserker, .blastguard, .magmaGolem, .voidling, .gargoyle], boss: .dreadnought, healthScale: 1.35, midBoss: .titan)
    )

    static let infernoPeak = MapDefinition(
        id: "infernopeak",
        name: "Inferno Peak",
        tagline: "The final climb up the volcano.",
        difficulty: .hard,
        terrain: .volcanic,
        world: .volcano,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 10), (18, 10), (18, 1), (1, 1), (1, 7), (15, 7), (15, 4), (5, 4)]),
        obstacles: Set(points([(0, 0), (19, 0), (19, 11), (9, 5), (3, 4)])),
        startingGold: 320,
        startingLives: 15,
        wavePlan: WavePlan(count: 15, villains: [.drone, .pyrefiend, .berserker, .blastguard, .magmaGolem, .voidling, .gargoyle], boss: .overlord, healthScale: 1.6, midBoss: .titan)
    )

    static let grotto = MapDefinition(
        id: "grotto",
        name: "Grotto",
        tagline: "A dark cave full of bats.",
        difficulty: .hard,
        terrain: .caves,
        world: .caves,
        columns: 16,
        rows: 9,
        waypoints: points([(-1, 6), (3, 6), (3, 2), (8, 2), (8, 6), (12, 6), (12, 2), (15, 2)]),
        obstacles: Set(points([(0, 0), (5, 4), (10, 8), (14, 8), (10, 0)])),
        startingGold: 300,
        startingLives: 20,
        wavePlan: WavePlan(count: 13, villains: [.drone, .caveBat, .voidling, .crab, .warper, .gargoyle, .phantom, .hexer], boss: .titan, healthScale: 1.65, midBoss: .titan)
    )

    static let echoHall = MapDefinition(
        id: "echohall",
        name: "Echo Hall",
        tagline: "The tunnel splits around a crystal pillar.",
        difficulty: .hard,
        terrain: .caves,
        world: .caves,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 2), (8, 2), (8, 5), (17, 5)]),
        branches: [points([(-1, 2), (3, 2), (3, 8), (13, 8), (13, 5), (17, 5)])],
        obstacles: Set(points([(0, 0), (6, 5), (11, 7), (16, 9), (17, 0)])),
        startingGold: 380,
        startingLives: 25,
        wavePlan: WavePlan(count: 14, villains: [.drone, .caveBat, .voidling, .crab, .warper, .gargoyle, .phantom, .hexer], boss: .dreadnought, healthScale: 1.5, midBoss: .titan)
    )

    static let crystalMine = MapDefinition(
        id: "crystalmine",
        name: "Crystal Mine",
        tagline: "Deep shafts lined with crystals.",
        difficulty: .hard,
        terrain: .caves,
        world: .caves,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 1), (6, 1), (6, 10), (10, 10), (10, 1), (14, 1), (14, 10), (19, 10)]),
        obstacles: Set(points([(2, 5), (8, 5), (12, 6), (17, 4), (0, 11), (19, 0), (3, 9)])),
        startingGold: 340,
        startingLives: 20,
        wavePlan: WavePlan(count: 15, villains: [.drone, .caveBat, .voidling, .crab, .warper, .gargoyle, .phantom, .hexer, .chameleon], boss: .overlord, healthScale: 1.75, midBoss: .titan)
    )

    static let deepCore = MapDefinition(
        id: "deepcore",
        name: "Deep Core",
        tagline: "The heart of the caves. The last stand.",
        difficulty: .hard,
        terrain: .caves,
        world: .caves,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 5), (3, 5), (3, 1), (16, 1), (16, 10), (6, 10), (6, 4), (12, 4), (12, 7), (9, 7)]),
        obstacles: Set(points([(0, 0), (0, 11), (19, 0), (19, 11), (9, 9)])),
        startingGold: 340,
        startingLives: 15,
        wavePlan: WavePlan(count: 15, villains: [.drone, .caveBat, .voidling, .crab, .warper, .gargoyle, .phantom, .hexer], boss: .overlord, healthScale: 1.85, midBoss: .titan)
    )

    static let twinGates = MapDefinition(
        id: "twingates",
        name: "Twin Gates",
        tagline: "Villains come through two gates. Heroes on raised tiles reach further.",
        difficulty: .hard,
        terrain: .highlands,
        world: .highlands,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 7), (4, 7), (4, 2), (8, 2), (8, 6), (13, 6), (13, 4), (16, 4)]),
        branches: [points([(15, -1), (15, 2), (11, 2), (11, 6), (13, 6), (13, 4), (16, 4)])],
        obstacles: Set(points([(3, 3), (9, 4), (12, 3), (14, 5), (6, 9), (0, 0), (17, 9)])),
        highGround: Set(points([(2, 4), (10, 0), (16, 8)])),
        startingGold: 340,
        startingLives: 20,
        wavePlan: WavePlan(count: 15, villains: [.drone, .runner, .sapper, .wisp, .brute, .pickpocket, .phantom], boss: .titan, healthScale: 1.7, midBoss: .titan)
    )

    static let mistmoor = MapDefinition(
        id: "mistmoor",
        name: "Mistmoor",
        tagline: "Mist hides villains and mud slows them down.",
        difficulty: .hard,
        terrain: .highlands,
        world: .highlands,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 1), (14, 1), (14, 4), (3, 4), (3, 8), (16, 8), (16, 5)]),
        obstacles: Set(points([(2, 2), (9, 2), (12, 6), (6, 6), (17, 0), (0, 9), (17, 9)])),
        mud: Set(points([(13, 1), (14, 1), (14, 2), (14, 3), (14, 4), (13, 4), (3, 5), (3, 6), (3, 7), (3, 8), (4, 8)])),
        mist: Set(points([(6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (8, 8), (9, 8), (10, 8), (11, 8)])),
        highGround: Set(points([(8, 6), (1, 6)])),
        startingGold: 320,
        startingLives: 20,
        wavePlan: WavePlan(count: 15, villains: [.drone, .phantom, .sapper, .pickpocket, .medic, .chameleon, .mirage], boss: .dreadnought, healthScale: 1.75, midBoss: .titan)
    )

    /// The Boss Rush event map. It isn't part of the campaign.
    static let arena = MapDefinition(
        id: "arena",
        name: "Arena",
        tagline: "Ten waves of bosses.",
        difficulty: .hard,
        terrain: .volcanic,
        columns: 16,
        rows: 9,
        waypoints: points([(-1, 4), (4, 4), (4, 1), (11, 1), (11, 7), (15, 7)]),
        obstacles: Set(points([(0, 0), (7, 4), (14, 2), (2, 8), (8, 8)])),
        startingGold: 600,
        startingLives: 10
    )

    /// Every campaign level, world by world. Each one unlocks the next, except the Highlands, which open with stars.
    static let all: [MapDefinition] = [
        circuit, switchback, overload, meadow,
        dunes, oasis, canyon, lagoon,
        bayou, harbor, mire, shore,
        glacier, tundra, icefall, avalanche,
        caldera, ashlands, magmaFalls, infernoPeak,
        grotto, echoHall, crystalMine, deepCore,
        twinGates, mistmoor,
    ]

    /// The map after this one in the campaign list, if any.
    var next: MapDefinition? {
        guard let index = Self.all.firstIndex(of: self), index + 1 < Self.all.count else { return nil }
        return Self.all[index + 1]
    }
}
