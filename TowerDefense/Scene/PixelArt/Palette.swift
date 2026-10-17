import UIKit

/// The game's color palette (based on the Endesga 32 pixel-art palette).
/// Single characters map to colors for the hand-drawn sprite maps.
enum Pal {
    static let ink = PixelColor(0x181425)
    static let navy = PixelColor(0x262B44)
    static let slate = PixelColor(0x3A4466)
    static let steel = PixelColor(0x5A6988)
    static let silver = PixelColor(0x8B9BB4)
    static let mist = PixelColor(0xC0CBDC)
    static let white = PixelColor(0xFFFFFF)
    static let red = PixelColor(0xE43B44)
    static let crimson = PixelColor(0xA22633)
    static let hotRed = PixelColor(0xFF0044)
    static let orange = PixelColor(0xF77622)
    static let rust = PixelColor(0xBE4A2F)
    static let amber = PixelColor(0xFEAE34)
    static let yellow = PixelColor(0xFEE761)
    static let lime = PixelColor(0x63C74D)
    static let green = PixelColor(0x3E8948)
    static let forest = PixelColor(0x265C42)
    static let deepTeal = PixelColor(0x193C3E)
    static let blue = PixelColor(0x0099DB)
    static let ocean = PixelColor(0x124E89)
    static let cyan = PixelColor(0x2CE8F5)
    static let bark = PixelColor(0x733E39)
    static let clay = PixelColor(0xB86F50)
    static let tan = PixelColor(0xE4A672)
    static let sand = PixelColor(0xEAD4AA)
    static let plum = PixelColor(0x3E2731)
    static let magenta = PixelColor(0xB55088)
    static let purple = PixelColor(0x68386C)
    static let pink = PixelColor(0xF6757A)
    static let copper = PixelColor(0xD77643)

    // Grass tones for the battlefield checkerboard.
    static let grassA = PixelColor(0x3E8948)
    static let grassB = PixelColor(0x398143)

    /// Ground and path colors for a terrain.
    struct TerrainColors {
        /// Checkerboard tones, one per tile.
        let groundA: PixelColor
        let groundB: PixelColor
        /// Speckles and tufts; `dark` also edges the ground along the path.
        let light: PixelColor
        let dark: PixelColor
        /// Rare single pixels such as flowers or embers.
        let sparkles: [PixelColor]
        let path: PixelColor
        let pathLight: PixelColor
        let pathMid: PixelColor
        /// Speckles and the path border.
        let pathDark: PixelColor
    }

    static func terrain(_ terrain: Terrain) -> TerrainColors {
        switch terrain {
        case .grassland:
            TerrainColors(groundA: grassA, groundB: grassB, light: lime, dark: forest, sparkles: [yellow, pink, white],
                          path: clay, pathLight: tan, pathMid: copper, pathDark: bark)
        case .desert:
            TerrainColors(groundA: tan, groundB: PixelColor(0xDC9E6A), light: sand, dark: PixelColor(0xC28569),
                          sparkles: [white, sand, orange],
                          path: clay, pathLight: PixelColor(0xC28569), pathMid: PixelColor(0xA5603F), pathDark: bark)
        case .snowfield:
            TerrainColors(groundA: PixelColor(0xE4EBF5), groundB: PixelColor(0xDAE2EE), light: white, dark: mist,
                          sparkles: [cyan, white, silver],
                          path: silver, pathLight: mist, pathMid: PixelColor(0x7B8BA6), pathDark: steel)
        case .volcanic:
            TerrainColors(groundA: plum, groundB: PixelColor(0x38222C), light: PixelColor(0x4E3440), dark: navy,
                          sparkles: [amber, orange, red],
                          path: navy, pathLight: slate, pathMid: PixelColor(0x2F3552), pathDark: orange)
        case .swamp:
            TerrainColors(groundA: PixelColor(0x2F5A3A), groundB: PixelColor(0x2B5436), light: green, dark: deepTeal,
                          sparkles: [lime, magenta, cyan],
                          path: PixelColor(0x8A5A44), pathLight: clay, pathMid: bark, pathDark: plum)
        }
    }

    static let chars: [Character: PixelColor] = [
        "K": ink, "N": navy, "n": slate, "S": steel, "s": silver, "w": mist, "W": white,
        "R": red, "r": crimson, "X": hotRed, "O": orange, "o": rust, "Y": amber, "y": yellow,
        "G": lime, "g": green, "h": forest, "H": deepTeal, "B": blue, "b": ocean, "C": cyan,
        "D": bark, "d": clay, "e": tan, "E": sand, "u": plum, "P": magenta, "p": purple,
        "f": pink, "L": copper,
    ]

    static func damage(_ type: DamageType) -> PixelColor {
        switch type {
        case .kinetic: silver
        case .explosive: orange
        case .cold: cyan
        case .energy: magenta
        case .fire: red
        case .toxic: lime
        case .psychic: pink
        case .sonic: yellow
        }
    }

    static func tower(_ kind: TowerKind) -> PixelColor {
        switch kind {
        case .pulse: blue
        case .frost: cyan
        case .mortar: orange
        case .tesla: magenta
        case .rail: hotRed
        case .inferno: red
        case .weaver: purple
        case .aegis: amber
        case .cyclone: mist
        case .echo: lime
        case .mind: pink
        case .chrono: sand
        case .star: yellow
        }
    }

    /// A lighter companion tone used for highlights and projectiles.
    static func towerLight(_ kind: TowerKind) -> PixelColor {
        switch kind {
        case .pulse: cyan
        case .frost: white
        case .mortar: amber
        case .tesla: pink
        case .rail: pink
        case .inferno: amber
        case .weaver: white
        case .aegis: yellow
        case .cyclone: white
        case .echo: white
        case .mind: white
        case .chrono: yellow
        case .star: white
        }
    }

    static func enemy(_ kind: EnemyKind) -> PixelColor {
        switch kind {
        case .drone: red
        case .runner: amber
        case .brute: crimson
        case .medic: lime
        case .wisp: magenta
        case .splitter: blue
        case .shardling: cyan
        case .berserker: orange
        case .phantom: mist
        case .hexer: magenta
        case .ironclad: silver
        case .pyrefiend: orange
        case .frostborn: cyan
        case .voidling: purple
        case .blastguard: clay
        case .husk: lime
        case .mirage: mist
        case .gargoyle: steel
        case .warper: cyan
        case .titan: hotRed
        case .dreadnought: silver
        case .overlord: lime
        }
    }
}
