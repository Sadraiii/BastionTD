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

/// The look of a battlefield: ground and path colors and the decoration sprites.
enum Terrain: String {
    case grassland, desert, snowfield, volcanic, swamp
}

/// A battlefield layout: grid size, the enemy route and unbuildable decoration.
///
/// The route is a list of axis-aligned waypoints. The first waypoint may sit just
/// outside the grid so enemies walk in from the edge; the last one holds the crystal
/// the player defends. Optional branches are extra routes with the same start and end
/// that split off and rejoin; villains take turns between the routes.
struct MapDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let difficulty: Difficulty
    let terrain: Terrain
    let columns: Int
    let rows: Int
    let waypoints: [GridPoint]
    /// The main route followed by any branches.
    let routes: [[GridPoint]]
    let obstacles: Set<GridPoint>
    let startingGold: Int
    let startingLives: Int
    let pathCells: Set<GridPoint>

    init(
        id: String,
        name: String,
        tagline: String,
        difficulty: Difficulty,
        terrain: Terrain = .grassland,
        columns: Int = 14,
        rows: Int = 8,
        waypoints: [GridPoint],
        branches: [[GridPoint]] = [],
        obstacles: Set<GridPoint>,
        startingGold: Int,
        startingLives: Int
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.difficulty = difficulty
        self.terrain = terrain
        self.columns = columns
        self.rows = rows
        self.waypoints = waypoints
        self.routes = [waypoints] + branches
        self.obstacles = obstacles
        self.startingGold = startingGold
        self.startingLives = startingLives
        self.pathCells = routes.reduce(into: Set()) { $0.formUnion(Self.cells(along: $1, columns: columns, rows: rows)) }
    }

    var coreCell: GridPoint { waypoints[waypoints.count - 1] }

    func contains(_ cell: GridPoint) -> Bool {
        (0..<columns).contains(cell.col) && (0..<rows).contains(cell.row)
    }

    func isBuildable(_ cell: GridPoint) -> Bool {
        contains(cell) && !pathCells.contains(cell) && !obstacles.contains(cell)
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
        tagline: "A looping trace with plenty of room to build.",
        difficulty: .easy,
        waypoints: points([(-1, 1), (2, 1), (2, 6), (5, 6), (5, 1), (8, 1), (8, 6), (11, 6), (11, 2), (13, 2)]),
        obstacles: Set(points([(0, 7), (4, 0), (13, 5), (10, 4)])),
        startingGold: 250,
        startingLives: 25
    )

    static let switchback = MapDefinition(
        id: "switchback",
        name: "Switchback",
        tagline: "Long corridors. Make every tower count twice.",
        difficulty: .normal,
        waypoints: points([(-1, 1), (11, 1), (11, 4), (2, 4), (2, 6), (13, 6)]),
        obstacles: Set(points([(13, 0), (0, 7), (7, 7), (0, 3)])),
        startingGold: 220,
        startingLives: 20
    )

    static let overload = MapDefinition(
        id: "overload",
        name: "Overload",
        tagline: "A short, jagged route straight to the crystal.",
        difficulty: .hard,
        waypoints: points([(-1, 4), (3, 4), (3, 1), (7, 1), (7, 6), (10, 6), (10, 3), (13, 3)]),
        obstacles: Set(points([(0, 0), (12, 7), (5, 7), (13, 0)])),
        startingGold: 200,
        startingLives: 20
    )

    static let dunes = MapDefinition(
        id: "dunes",
        name: "Dunes",
        tagline: "Wide desert switchbacks under a burning sun.",
        difficulty: .normal,
        terrain: .desert,
        columns: 18,
        rows: 10,
        waypoints: points([(-1, 2), (3, 2), (3, 7), (7, 7), (7, 1), (11, 1), (11, 7), (15, 7), (15, 3), (17, 3)]),
        obstacles: Set(points([(0, 0), (5, 4), (13, 4), (16, 9), (1, 9), (9, 9), (9, 0)])),
        startingGold: 300,
        startingLives: 25
    )

    static let bayou = MapDefinition(
        id: "bayou",
        name: "Bayou",
        tagline: "The boardwalk forks around an island, then joins again.",
        difficulty: .hard,
        terrain: .swamp,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 6), (3, 6), (3, 2), (11, 2), (11, 6), (16, 6), (16, 2), (19, 2)]),
        branches: [points([(-1, 6), (3, 6), (3, 10), (11, 10), (11, 6), (16, 6), (16, 2), (19, 2)])],
        obstacles: Set(points([(0, 0), (7, 6), (14, 9), (18, 6), (0, 11), (19, 11), (13, 0)])),
        startingGold: 300,
        startingLives: 20
    )

    static let glacier = MapDefinition(
        id: "glacier",
        name: "Glacier",
        tagline: "An icy trail that doubles back across the field.",
        difficulty: .hard,
        terrain: .snowfield,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 9), (2, 9), (2, 2), (6, 2), (6, 10), (10, 10), (10, 2), (14, 2), (14, 10), (18, 10), (18, 5), (19, 5)]),
        obstacles: Set(points([(0, 0), (4, 11), (12, 0), (16, 4), (8, 6), (19, 11), (0, 5)])),
        startingGold: 300,
        startingLives: 20
    )

    static let caldera = MapDefinition(
        id: "caldera",
        name: "Caldera",
        tagline: "A spiral of cooling lava closing in on the crystal.",
        difficulty: .hard,
        terrain: .volcanic,
        columns: 20,
        rows: 12,
        waypoints: points([(-1, 1), (18, 1), (18, 10), (1, 10), (1, 4), (15, 4), (15, 7), (5, 7)]),
        obstacles: Set(points([(0, 11), (19, 0), (10, 2), (8, 5), (12, 9), (3, 8), (19, 11)])),
        startingGold: 220,
        startingLives: 15
    )

    static let all: [MapDefinition] = [circuit, switchback, overload, dunes, bayou, glacier, caldera]

    /// The map after this one in the campaign list, if any.
    var next: MapDefinition? {
        guard let index = Self.all.firstIndex(of: self), index + 1 < Self.all.count else { return nil }
        return Self.all[index + 1]
    }
}
