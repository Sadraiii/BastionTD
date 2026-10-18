import SpriteKit
import UIKit

/// Builds and caches every pixel-art texture and image used by the game.
///
/// Textures use nearest-neighbor filtering so art pixels stay crisp when scaled.
/// One art pixel is 1/16 of a tile.
@MainActor
enum Art {
    nonisolated static let tilePixels = 16

    private static var textureCache: [String: SKTexture] = [:]
    private static var frameCache: [String: [SKTexture]] = [:]
    private static var imageCache: [String: UIImage] = [:]

    // MARK: Caching helpers

    static func makeTexture(_ canvas: PixelCanvas) -> SKTexture {
        let texture = canvas.makeCGImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }

    private static func texture(_ key: String, _ make: () -> PixelCanvas) -> SKTexture {
        if let cached = textureCache[key] { return cached }
        let texture = makeTexture(make())
        textureCache[key] = texture
        return texture
    }

    private static func frames(_ key: String, _ make: () -> [PixelCanvas]) -> [SKTexture] {
        if let cached = frameCache[key] { return cached }
        let textures = make().map(makeTexture)
        frameCache[key] = textures
        return textures
    }

    private static func image(_ key: String, _ make: () -> PixelCanvas) -> UIImage {
        if let cached = imageCache[key] { return cached }
        let image = make().makeUIImage()
        imageCache[key] = image
        return image
    }

    // MARK: Towers

    static func towerBase(_ kind: TowerKind, tiers: [Int]) -> SKTexture {
        texture("base.\(kind.rawValue).\(tiers[0]).\(tiers[1])") { towerBaseCanvas(kind, tiers: tiers) }
    }

    static func turret(_ kind: TowerKind, tiers: [Int]) -> SKTexture {
        texture("turret.\(kind.rawValue).\(tiers[0]).\(tiers[1])") { turretCanvas(kind, tiers: tiers) }
    }

    /// Base and turret composited, for the build panel and menus.
    static func towerIcon(_ kind: TowerKind, tiers: [Int] = [0, 0]) -> UIImage {
        image("towerIcon.\(kind.rawValue).\(tiers[0]).\(tiers[1])") {
            var canvas = towerBaseCanvas(kind, tiers: tiers)
            canvas.stamp(turretCanvas(kind, tiers: tiers), x: 0, y: 0)
            guard tiers.max() == 0 else { return canvas }
            // An unupgraded hero fits in 16x16, so its icon keeps the old size.
            var small = PixelCanvas(width: 16, height: 16)
            small.stamp(canvas, x: -2, y: -2)
            return small
        }
    }

    /// Each hero stands on its own platform, drawn in a slight 3/4 view: a top
    /// surface plus a darker band below it that gives the platform some height.
    /// Returns 20x20 so upgraded heroes can grow past their 16x16 tile.
    static func towerBaseCanvas(_ kind: TowerKind, tiers: [Int]) -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        let accent = Pal.tower(kind)

        func platform(_ top: [(x: Double, y: Double)], top topColor: PixelColor, side: PixelColor) {
            c.fillPolygon(top.map { ($0.x, $0.y + 2) }, side)
            c.fillPolygon(top, topColor)
        }
        func disc(top topColor: PixelColor, side: PixelColor, rim: PixelColor? = nil) {
            c.fillEllipse(cx: 8, cy: 9.5, rx: 6.9, ry: 4.6, side)
            c.fillEllipse(cx: 8, cy: 7.5, rx: 6.9, ry: 4.6, rim ?? topColor)
            if rim != nil { c.fillEllipse(cx: 8, cy: 7.5, rx: 5.8, ry: 3.7, topColor) }
        }
        let hexagon: [(x: Double, y: Double)] = [(4.5, 3), (11.5, 3), (15, 7.5), (11.5, 12), (4.5, 12), (1, 7.5)]
        let octagon: [(x: Double, y: Double)] = [(5, 3), (11, 3), (14.5, 5.5), (14.5, 9.5), (11, 12), (5, 12), (1.5, 9.5), (1.5, 5.5)]

        switch kind {
        case .pulse:
            disc(top: Pal.steel, side: Pal.slate, rim: Pal.silver)
            c.ring(cx: 8, cy: 7.5, r: 3.6, Pal.ocean)
            for (x, y) in [(3, 6), (4, 7), (3, 8), (12, 6), (11, 7), (12, 8)] { c.set(x, y, Pal.yellow) }

        case .frost:
            c.fillEllipse(cx: 8, cy: 10.5, rx: 7, ry: 3.6, Pal.mist)
            c.fillEllipse(cx: 8, cy: 10, rx: 6, ry: 2.8, Pal.white)
            for (cx, h, w) in [(3.5, 6.0, 2.0), (12.5, 5.0, 2.0), (8.0, 8.0, 2.6), (5.5, 4.0, 1.5), (10.5, 4.5, 1.5)] {
                c.fillPolygon([(cx, 12 - h - 3), (cx + w, 12 - 3), (cx, 13), (cx - w, 12 - 3)], Pal.cyan)
                c.set(Int(cx), Int(12 - h - 2), Pal.white)
            }

        case .mortar:
            for (x, y, r) in [(5.0, 10.0, 3.6), (11.0, 10.0, 3.8), (8.0, 7.5, 3.8), (3.8, 7.0, 2.4), (12.4, 7.0, 2.6)] {
                c.fillCircle(cx: x, cy: y, r: r, Pal.bark)
            }
            for (x, y, r) in [(5.0, 9.0, 3.0), (11.0, 9.0, 3.2), (8.0, 6.5, 3.2), (3.8, 6.2, 1.8), (12.4, 6.2, 2.0)] {
                c.fillCircle(cx: x, cy: y, r: r, Pal.clay)
            }
            for (x, y) in [(4, 5), (7, 4), (10, 7), (13, 5), (5, 8)] { c.set(x, y, Pal.tan) }

        case .tesla:
            platform(hexagon, top: Pal.navy, side: Pal.plum)
            for (x, y) in [(3, 7), (4, 5), (12, 5), (13, 7), (4, 10), (12, 10)] { c.set(x, y, accent) }

        case .rail:
            platform(hexagon, top: Pal.slate, side: Pal.navy)
            c.fillPolygon([(5, 4.5), (11, 4.5), (13.5, 7.5), (11, 10.5), (5, 10.5), (2.5, 7.5)], Pal.navy)
            for x in [3, 13] { c.set(x, 7, Pal.hotRed); c.set(x, 8, Pal.hotRed) }

        case .inferno:
            c.line(4, 11, 3, 15, Pal.ink)
            c.line(12, 11, 13, 15, Pal.ink)
            c.line(8, 12, 8, 15, Pal.ink)
            c.fillEllipse(cx: 8, cy: 9, rx: 6.5, ry: 4, Pal.bark)
            c.fillEllipse(cx: 8, cy: 7.5, rx: 6.5, ry: 3.6, Pal.ink)
            for (x, y) in [(4, 7), (6, 6), (9, 8), (11, 6), (12, 8), (7, 9), (5, 8)] {
                c.set(x, y, PixelNoise.value(x, y) % 2 == 0 ? Pal.orange : Pal.red)
            }

        case .weaver:
            c.ring(cx: 8, cy: 8, r: 6.8, Pal.mist.alpha(200)) { x, y in (x + y) % 2 == 0 }
            c.ring(cx: 8, cy: 8, r: 4.2, Pal.mist.alpha(200))
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                c.line(8, 8, Int(8 + cos(angle) * 7), Int(8 + sin(angle) * 6), Pal.mist.alpha(170))
            }

        case .aegis:
            platform(octagon, top: Pal.steel, side: Pal.slate)
            c.fillPolygon([(6, 4.5), (10, 4.5), (12.5, 6), (12.5, 9), (10, 10.5), (6, 10.5), (3.5, 9), (3.5, 6)], Pal.silver)
            for (x, y) in [(2, 7), (14, 7), (8, 3), (8, 12)] { c.set(x, y, Pal.amber) }

        case .cyclone:
            for (x, y, r) in [(4.5, 10.0, 3.0), (11.5, 10.0, 3.2), (8.0, 10.5, 3.6)] { c.fillCircle(cx: x, cy: y, r: r, Pal.silver) }
            for (x, y, r) in [(4.5, 8.5, 3.0), (11.5, 8.5, 3.2), (8.0, 7.0, 4.0), (6.0, 6.0, 2.6), (10.5, 6.0, 2.6)] {
                c.fillCircle(cx: x, cy: y, r: r, Pal.white)
            }

        case .echo:
            disc(top: Pal.navy, side: Pal.ink, rim: Pal.forest)
            c.ring(cx: 8, cy: 7.5, r: 3.6, Pal.green) { x, y in (x + y) % 2 == 0 }
            c.ring(cx: 8, cy: 7.5, r: 2.2, Pal.green) { x, y in (x + y) % 2 == 1 }

        case .mind:
            disc(top: Pal.purple, side: Pal.plum, rim: Pal.magenta)
            c.ring(cx: 8, cy: 7.5, r: 4.4, Pal.pink) { x, y in (x * 3 + y) % 4 != 0 }

        case .chrono:
            disc(top: Pal.sand, side: Pal.bark, rim: Pal.tan)
            for (x, y) in [(8, 4), (12, 7), (8, 11), (3, 7), (11, 5), (11, 10), (4, 10), (4, 5)] { c.set(x, y, Pal.bark) }

        case .star:
            var points: [(x: Double, y: Double)] = []
            for i in 0..<12 {
                let angle = Double(i) * .pi / 6 - .pi / 2
                let r = i % 2 == 0 ? 7.4 : 4.6
                points.append((8 + cos(angle) * r, 7.5 + sin(angle) * r * 0.72))
            }
            platform(points, top: Pal.navy, side: Pal.ink)
            c.fillEllipse(cx: 8, cy: 7.5, rx: 3.6, ry: 2.6, Pal.ocean)
            for (x, y) in [(8, 2), (14, 5), (14, 10), (8, 12), (1, 10), (1, 5)] { c.set(x, y, Pal.yellow) }

        case .sniper:
            platform(octagon, top: Pal.slate, side: Pal.navy)
            c.ring(cx: 8, cy: 7.5, r: 3.4, Pal.red) { x, y in (x + y) % 2 == 0 }

        case .tamer:
            disc(top: Pal.forest, side: Pal.deepTeal, rim: Pal.bark)
            for (x, y) in [(4, 6), (5, 5), (11, 6), (10, 5)] { c.set(x, y, Pal.tan) }

        case .alchemist:
            platform(hexagon, top: Pal.plum, side: Pal.ink)
            for (x, y) in [(3, 7), (13, 7), (8, 4), (8, 11)] { c.set(x, y, Pal.lime) }

        case .tide:
            c.fillEllipse(cx: 8, cy: 8.5, rx: 7.2, ry: 4.8, Pal.blue)
            c.ring(cx: 8, cy: 8, r: 6, Pal.cyan) { x, y in (x + y * 2) % 5 != 0 }

        case .midas:
            disc(top: Pal.rust, side: Pal.bark, rim: Pal.amber)
            for (x, y) in [(3, 7), (13, 7), (8, 4), (8, 11)] { c.set(x, y, Pal.yellow) }
        }

        // The web is drawn straight onto the grass; an outline would make it look solid.
        if kind != .weaver { c.outline() }

        var big = PixelCanvas(width: 20, height: 20)
        let top = tiers.max() ?? 0
        // Heroes near the top of a path stand on a wider footing in their own colors, with pillars once maxed.
        let stone: (top: PixelColor, side: PixelColor) = switch kind {
        case .pulse, .aegis: (Pal.steel, Pal.slate)
        case .frost, .cyclone: (Pal.mist, Pal.silver)
        case .mortar, .chrono: (Pal.clay, Pal.bark)
        case .tesla, .star: (Pal.slate, Pal.navy)
        case .rail, .sniper: (Pal.slate, Pal.ink)
        case .inferno: (Pal.bark, Pal.ink)
        case .weaver, .alchemist: (Pal.purple, Pal.plum)
        case .echo, .tamer: (Pal.forest, Pal.deepTeal)
        case .mind: (Pal.magenta, Pal.purple)
        case .midas: (Pal.copper, Pal.rust)
        case .tide: (Pal.ocean, Pal.navy)
        }
        let trim = Pal.tower(kind) == stone.top ? Pal.towerLight(kind) : Pal.tower(kind)
        if top >= 3 {
            big.fillEllipse(cx: 10, cy: 12.5, rx: 9.5, ry: 6, stone.side)
            big.fillEllipse(cx: 10, cy: 11, rx: 9.5, ry: 6, stone.top)
            for (x, y) in [(1, 11), (18, 11), (4, 16), (15, 16), (4, 6), (15, 6)] { big.set(x, y, trim) }
        }
        if top >= 4 {
            for x in [1, 17] {
                big.fillRect(x, 3, 2, 8, stone.side)
                big.set(x, 4, stone.top)
                big.fillRect(x, 1, 2, 2, trim)
            }
        }
        big.outline()
        big.stamp(c, x: 2, y: 2)
        // Tier pips along the front: path 1 in amber, then path 2 in cyan.
        let pips = tiers[0] + tiers[1]
        var x = 10 - (pips * 3 + 1) / 2
        for i in 0..<pips {
            big.fillRect(x, 16, 4, 3, Pal.ink)
            big.fillRect(x + 1, 17, 2, 1, i < tiers[0] ? Pal.amber : Pal.cyan)
            x += 3
        }
        return big
    }

    /// The turret on a 20x20 canvas: one of three looks by overall level, plus gear from each upgrade path.
    static func turretCanvas(_ kind: TowerKind, tiers: [Int]) -> PixelCanvas {
        let level = TowerKind.visualLevel(tiers: tiers)
        var c = PixelCanvas(width: 16, height: 16)
        switch kind {
        case .pulse:
            let barrels: [Int] = level == 1 ? [7] : level == 2 ? [5, 9] : [4, 7, 10]
            for bx in barrels {
                let top = (level == 1 || (level == 3 && bx == 7)) ? 1 : 2
                for y in top...6 {
                    c.set(bx, y, Pal.silver)
                    c.set(bx + 1, y, Pal.steel)
                }
                c.set(bx, top, Pal.cyan)
                c.set(bx + 1, top, Pal.cyan)
            }
            c.fillCircle(cx: 8, cy: 8.5, r: 3.8, Pal.ocean)
            c.fillCircle(cx: 8, cy: 8.5, r: 2.8, Pal.blue)
            c.set(6, 7, Pal.cyan)
            c.set(7, 6, Pal.cyan)
            c.fillRect(7, 8, 2, 2, level == 3 ? Pal.white : Pal.cyan)

        case .frost:
            let arm = level == 3 ? Pal.white : Pal.mist
            for i in 1...6 {
                c.set(7, i, arm); c.set(8, i, arm)
                c.set(7, 15 - i, arm); c.set(8, 15 - i, arm)
                c.set(i, 7, arm); c.set(i, 8, arm)
                c.set(15 - i, 7, arm); c.set(15 - i, 8, arm)
            }
            if level >= 2 {
                for i in 2...4 {
                    c.set(i + 1, i + 1, Pal.cyan); c.set(14 - i, i + 1, Pal.cyan)
                    c.set(i + 1, 14 - i, Pal.cyan); c.set(14 - i, 14 - i, Pal.cyan)
                }
            }
            if level == 3 {
                for (x, y) in [(6, 2), (9, 2), (6, 13), (9, 13), (2, 6), (2, 9), (13, 6), (13, 9)] {
                    c.set(x, y, Pal.cyan)
                }
            }
            for y in 0..<16 {
                for x in 0..<16 {
                    let d = abs(Double(x) + 0.5 - 8) + abs(Double(y) + 0.5 - 8)
                    if d <= 4 { c.set(x, y, Pal.blue) }
                    if d <= 3 { c.set(x, y, Pal.cyan) }
                    if d <= 1.5 { c.set(x, y, Pal.white) }
                }
            }

        case .mortar:
            c.fillCircle(cx: 8, cy: 9, r: 4.6, Pal.rust)
            c.fillCircle(cx: 8, cy: 9, r: 3.6, Pal.orange)
            c.set(5, 8, Pal.amber); c.set(6, 7, Pal.amber)
            if level == 3 {
                c.ring(cx: 8, cy: 9, r: 4.2, thickness: 0.9, Pal.yellow) { x, y in (x + y) % 2 == 0 }
            }
            for y in 2...8 {
                c.set(6, y, Pal.silver)
                c.set(7, y, Pal.steel); c.set(8, y, Pal.steel)
                c.set(9, y, Pal.slate)
            }
            if level >= 2 { for x in 6...9 { c.set(x, 6, Pal.amber) } }
            if level == 3 {
                for x in 5...10 { c.set(x, 2, Pal.amber) }
            }
            c.set(7, 3, Pal.ink); c.set(8, 3, Pal.ink)

        case .tesla:
            let prongs: [(Int, Int)] = level == 3
                ? [(7, 1), (8, 1), (7, 14), (8, 14), (1, 7), (1, 8), (14, 7), (14, 8), (3, 3), (12, 3), (3, 12), (12, 12)]
                : [(7, 1), (8, 1), (7, 14), (8, 14), (1, 7), (1, 8), (14, 7), (14, 8)]
            for (x, y) in prongs { c.set(x, y, Pal.amber) }
            c.fillCircle(cx: 8, cy: 8, r: 5.6, Pal.purple)
            c.fillCircle(cx: 8, cy: 8, r: 4.4, Pal.magenta)
            c.fillCircle(cx: 8, cy: 8, r: 2.6, level >= 2 ? Pal.pink : Pal.purple)
            c.fillRect(7, 7, 2, 2, Pal.white)
            if level >= 2 {
                for (x, y) in [(8, 3), (12, 8), (7, 12), (3, 7)] { c.set(x, y, Pal.yellow) }
            }

        case .rail:
            let top = level == 3 ? 0 : 1
            for y in top...9 {
                c.set(5, y, Pal.silver); c.set(6, y, Pal.steel)
                c.set(9, y, Pal.steel); c.set(10, y, Pal.silver)
            }
            let core = level == 1 ? Pal.magenta : Pal.pink
            for y in (top + 2)...9 {
                c.set(7, y, core); c.set(8, y, core)
            }
            if level == 3 { for y in 3...8 { c.set(7, y, Pal.white) } }
            for y in 0..<16 {
                for x in 0..<16 {
                    let d = abs(Double(x) + 0.5 - 8) + abs(Double(y) + 0.5 - 10.5)
                    if d <= 4 { c.set(x, y, Pal.navy) }
                    if d <= 2.5 { c.set(x, y, Pal.hotRed) }
                }
            }
            if level >= 2 { c.set(7, 10, Pal.pink); c.set(8, 10, Pal.pink) }
            if level == 3 {
                for (x, y) in [(3, 11), (4, 10), (12, 11), (11, 10)] { c.set(x, y, Pal.steel) }
            }

        case .inferno:
            c.fillCircle(cx: 8, cy: 9.5, r: 4.2, Pal.crimson)
            c.fillCircle(cx: 8, cy: 9.5, r: 3.2, Pal.red)
            c.set(6, 8, Pal.pink)
            if level >= 2 {
                c.fillCircle(cx: 3.5, cy: 11, r: 1.8, Pal.rust)
                c.fillCircle(cx: 12.5, cy: 11, r: 1.8, Pal.rust)
            }
            for y in 3...7 { c.set(7, y, Pal.silver); c.set(8, y, Pal.steel) }
            for x in 6...9 { c.set(x, 2, Pal.copper) }
            c.set(7, 1, level == 3 ? Pal.white : Pal.yellow); c.set(8, 1, Pal.yellow)
            if level == 3 {
                for (x, y) in [(5, 1), (10, 1), (6, 0), (9, 0)] { c.set(x, y, Pal.amber) }
            }

        case .weaver:
            let legs: [(Int, Int, Int, Int)] = [(5, 7, 2, 4), (5, 9, 1, 8), (5, 11, 1, 12), (6, 12, 3, 14)]
            for (x0, y0, x1, y1) in legs {
                c.line(x0, y0, x1, y1, Pal.ink)
                c.line(15 - x0, y0, 15 - x1, y1, Pal.ink)
            }
            c.fillEllipse(cx: 8, cy: 10, rx: 3.2, ry: 3.6, Pal.purple)
            c.fillCircle(cx: 8, cy: 5.5, r: 2.2, Pal.plum)
            c.set(7, 9, Pal.red); c.set(8, 9, Pal.red); c.set(7, 11, Pal.red); c.set(8, 11, Pal.red)
            c.set(7, 10, Pal.hotRed); c.set(8, 10, Pal.hotRed)
            c.set(7, 5, Pal.white); c.set(8, 5, Pal.white)
            if level >= 2 { for y in 0...3 { c.set(8, y, Pal.mist) } }
            if level == 3 { c.set(6, 8, Pal.amber); c.set(9, 8, Pal.amber); c.set(6, 12, Pal.amber); c.set(9, 12, Pal.amber) }

        case .aegis:
            c.fillCircle(cx: 8, cy: 8, r: 6.2, Pal.amber)
            c.fillCircle(cx: 8, cy: 8, r: 5, level >= 2 ? Pal.yellow : Pal.copper)
            c.fillCircle(cx: 8, cy: 8, r: 4, Pal.ocean)
            c.fillCircle(cx: 8, cy: 8, r: 2.6, Pal.blue)
            for (x, y) in [(5, 6), (6, 7), (7, 8), (8, 8), (9, 7), (10, 6)] { c.set(x, y, Pal.white) }
            c.set(7, 10, Pal.white); c.set(8, 10, Pal.white)
            if level == 3 {
                for (x, y) in [(0, 7), (0, 8), (1, 6), (15, 7), (15, 8), (14, 6)] { c.set(x, y, Pal.white) }
            }

        case .cyclone:
            let arms = level == 3 ? 4 : 3
            for arm in 0..<arms {
                let base = Double(arm) * 2 * .pi / Double(arms)
                for step in 0..<14 {
                    let t = Double(step) / 13
                    let angle = base + t * 2.6
                    let r = 1.5 + t * 5.5
                    c.set(Int(8 + cos(angle) * r), Int(8 + sin(angle) * r), step > 9 ? Pal.white : Pal.mist)
                }
            }
            c.fillCircle(cx: 8, cy: 8, r: 2.2, level >= 2 ? Pal.cyan : Pal.silver)
            c.set(7, 7, Pal.white)

        case .echo:
            c.fillCircle(cx: 8, cy: 10.5, r: 3.6, Pal.forest)
            c.fillCircle(cx: 8, cy: 10.5, r: 2.6, Pal.green)
            for y in 2...7 {
                let half = 1 + (7 - y) / 2
                for x in (8 - half - 1)...(7 + half + 1) { c.set(x, y, Pal.lime) }
                c.set(7, y, Pal.forest); c.set(8, y, Pal.forest)
            }
            if level >= 2 { c.ring(cx: 8, cy: 4, r: 4.8, Pal.white) { x, y in y < 2 } }
            if level == 3 { c.ring(cx: 8, cy: 4, r: 6.5, Pal.yellow) { x, y in y < 1 } }

        case .mind:
            if level >= 2 { c.ring(cx: 8, cy: 8, r: 6.8, Pal.pink) { x, y in (x + y) % 2 == 0 } }
            c.fillCircle(cx: 8, cy: 8, r: 5.2, Pal.magenta)
            c.fillCircle(cx: 8, cy: 8, r: 4.2, Pal.pink)
            for (x, y) in [(5, 6), (6, 5), (10, 5), (11, 7), (5, 10), (10, 11)] { c.set(x, y, Pal.magenta) }
            c.fillRect(6, 7, 4, 2, Pal.white)
            c.set(7, 7, Pal.ink); c.set(8, 8, Pal.ink)
            if level == 3 {
                for (x, y) in [(1, 2), (14, 2), (1, 13), (14, 13)] { c.set(x, y, Pal.cyan) }
            }

        case .chrono:
            if level >= 2 {
                for (x, y) in [(1, 7), (1, 8), (14, 7), (14, 8), (7, 14), (8, 14)] { c.set(x, y, Pal.steel) }
            }
            c.fillCircle(cx: 8, cy: 8, r: 6.2, level == 3 ? Pal.yellow : Pal.amber)
            c.fillCircle(cx: 8, cy: 8, r: 5, Pal.sand)
            for (x, y) in [(7, 3), (8, 3), (12, 7), (12, 8), (7, 12), (8, 12), (3, 7), (3, 8)] { c.set(x, y, Pal.bark) }
            for y in 4...8 { c.set(8, y, Pal.ink) }
            for x in 8...10 { c.set(x, 8, Pal.ink) }
            c.set(8, 8, Pal.red)

        case .star:
            let top = level == 3 ? 0 : 1
            for y in top...7 { c.set(7, y, Pal.sand); c.set(8, y, Pal.white) }
            if level >= 2 { for y in (top + 2)...7 { c.set(6, y, Pal.amber); c.set(9, y, Pal.amber) } }
            for y in 0..<16 {
                for x in 0..<16 {
                    let dx = abs(Double(x) + 0.5 - 8), dy = abs(Double(y) + 0.5 - 10)
                    if dx * dy < 2.2 && dx + dy < 5 { c.set(x, y, Pal.yellow) }
                    if dx + dy < 2.2 { c.set(x, y, Pal.white) }
                }
            }
            if level == 3 { c.ring(cx: 8, cy: 10, r: 4.5, Pal.amber) { x, y in (x + y) % 3 == 0 } }

        case .sniper:
            // A long rifle with a scope.
            for y in (level == 3 ? 0 : 1)...8 { c.set(8, y, Pal.silver) }
            c.fillRect(7, 6, 3, 3, Pal.steel)
            c.fillRect(9, 4, 2, 2, level >= 2 ? Pal.red : Pal.ink)
            c.fillCircle(cx: 8, cy: 10.5, r: 2.8, Pal.slate)
            c.fillCircle(cx: 8, cy: 10.5, r: 1.6, Pal.tan)

        case .tamer:
            // A wolf's head with pointed ears.
            c.fillPolygon([(4, 4), (6, 7), (3, 8)], Pal.steel)
            c.fillPolygon([(12, 4), (10, 7), (13, 8)], Pal.steel)
            c.fillCircle(cx: 8, cy: 9, r: 4, Pal.steel)
            c.fillEllipse(cx: 8, cy: 11.5, rx: 2, ry: 1.6, Pal.silver)
            c.set(6, 8, level >= 2 ? Pal.yellow : Pal.ink)
            c.set(10, 8, level >= 2 ? Pal.yellow : Pal.ink)
            c.set(8, 12, Pal.ink)
            if level == 3 { c.set(5, 5, Pal.red); c.set(11, 5, Pal.red) }

        case .alchemist:
            // A round flask of bubbling acid.
            c.fillRect(7, 2, 2, 4, Pal.mist)
            c.fillCircle(cx: 8, cy: 9.5, r: 4.2, Pal.mist)
            c.fillCircle(cx: 8, cy: 10, r: 3.4, Pal.lime)
            c.set(7, 9, Pal.white)
            c.set(9, 11, Pal.green)
            c.set(8, level == 3 ? 1 : 3, Pal.lime)
            if level >= 2 { c.set(6, 11, Pal.yellow); c.set(10, 9, Pal.yellow) }

        case .tide:
            // A small submarine seen from above, with a periscope.
            c.fillEllipse(cx: 8, cy: 8.5, rx: 3.2, ry: 6, Pal.steel)
            c.fillEllipse(cx: 8, cy: 8.5, rx: 2.2, ry: 4.8, Pal.silver)
            c.fillRect(7, 6, 2, 3, Pal.slate)
            c.set(8, 2, level >= 2 ? Pal.yellow : Pal.mist)
            c.set(7, 13, Pal.cyan); c.set(8, 14, Pal.cyan)
            if level == 3 { c.set(5, 8, Pal.red); c.set(10, 8, Pal.red) }

        case .midas:
            // A stack of coins that grows with each level.
            for i in 0...level {
                let y = 11.5 - Double(i) * 2
                c.fillEllipse(cx: 8, cy: y + 0.8, rx: 4.2, ry: 1.8, Pal.rust)
                c.fillEllipse(cx: 8, cy: y, rx: 4.2, ry: 1.6, Pal.amber)
                c.fillEllipse(cx: 8, cy: y - 0.3, rx: 2.6, ry: 0.8, Pal.yellow)
            }
            c.set(10, 9 - level * 2, Pal.white)
            c.set(11, 8 - level * 2, Pal.white)
        }
        var big = c.padded(2)
        drawTurretUpgrades(kind, a: tiers[0], b: tiers[1], on: &big)
        big.outline()
        return big
    }

    /// Gear each upgrade path adds to a hero's turret, drawn on a 20x20 canvas
    /// (the 16x16 turret sits at 2, 2). `a` and `b` are the tiers bought on each path.
    static func drawTurretUpgrades(_ kind: TowerKind, a: Int, b: Int, on c: inout PixelCanvas) {
        switch kind {
        case .pulse:
            // Velocity: swept fins that grow into wings. Impact: armor plating and knuckle spikes.
            if a >= 1 { c.fillRect(4, 10, 2, 3, Pal.ocean); c.fillRect(14, 10, 2, 3, Pal.ocean) }
            if a >= 2 { c.fillRect(3, 12, 2, 3, Pal.blue); c.fillRect(15, 12, 2, 3, Pal.blue) }
            if a >= 3 { for x in [8, 11] { c.set(x, 16, Pal.cyan); c.set(x, 17, Pal.white) } }
            if a >= 4 {
                c.fillPolygon([(4, 8), (1, 18), (5, 15)], Pal.cyan)
                c.fillPolygon([(16, 8), (19, 18), (15, 15)], Pal.cyan)
                c.set(2, 16, Pal.white); c.set(17, 16, Pal.white)
            }
            if b >= 1 { c.fillRect(6, 13, 8, 2, Pal.steel) }
            if b >= 2 { c.set(7, 14, Pal.amber); c.set(12, 14, Pal.amber) }
            if b >= 3 { c.fillRect(4, 7, 2, 5, Pal.silver); c.fillRect(14, 7, 2, 5, Pal.silver) }
            if b >= 4 { for x in [5, 14] { c.set(x, 6, Pal.white); c.set(x, 5, Pal.white) } }

        case .frost:
            // Permafrost: the arms grow icicle tips. Hailstorm: hail stones orbit the core.
            if a >= 1 { for (x, y) in [(9, 2), (10, 2), (9, 17), (10, 17), (2, 9), (2, 10), (17, 9), (17, 10)] { c.set(x, y, Pal.white) } }
            if a >= 3 { for (x, y) in [(9, 1), (10, 1), (9, 18), (10, 18), (1, 9), (1, 10), (18, 9), (18, 10)] { c.set(x, y, Pal.cyan) } }
            if a >= 4 { c.ring(cx: 10, cy: 10, r: 8.5, Pal.white) { x, y in (x + y) % 4 == 0 } }
            for (i, (x, y)) in [(4, 4), (15, 15), (15, 4), (4, 15)].enumerated() where i < b {
                c.fillRect(x, y, 2, 2, Pal.mist)
                c.set(x, y, Pal.white)
            }

        case .mortar:
            // Seismic: a heavier, wider barrel. Fury: ammo drums on the sides.
            if a >= 1 { for y in 6...11 { c.set(7, y, Pal.slate); c.set(12, y, Pal.slate) } }
            if a >= 2 { for x in 7...12 { c.set(x, 4, Pal.steel) } }
            if a >= 3 { for x in 6...13 { c.set(x, 3, Pal.amber) } }
            if a >= 4 { c.ring(cx: 10, cy: 11, r: 6.3, Pal.orange) { x, y in y > 11 && (x + y) % 2 == 0 } }
            if b >= 1 { c.fillCircle(cx: 4.5, cy: 12, r: 2, Pal.bark); c.set(4, 11, Pal.tan) }
            if b >= 2 { c.fillCircle(cx: 15.5, cy: 12, r: 2, Pal.bark); c.set(15, 11, Pal.tan) }
            if b >= 3 { c.fillCircle(cx: 4.5, cy: 15.5, r: 1.6, Pal.bark); c.fillCircle(cx: 15.5, cy: 15.5, r: 1.6, Pal.bark) }
            if b >= 4 { c.set(4, 15, Pal.tan); c.set(15, 15, Pal.tan) }

        case .tesla:
            // Tempest: storm clouds gather around the coil. Skyhammer: a tall lightning rod.
            if a >= 1 { c.fillCircle(cx: 3.5, cy: 5, r: 2, Pal.silver) }
            if a >= 2 { c.fillCircle(cx: 16.5, cy: 15, r: 2, Pal.silver) }
            if a >= 3 { c.fillCircle(cx: 16, cy: 4.5, r: 2.2, Pal.mist); c.fillCircle(cx: 4, cy: 15.5, r: 2.2, Pal.mist) }
            if a >= 4 { for (x, y) in [(3, 7), (2, 8), (17, 3), (16, 2), (17, 17), (5, 18)] { c.set(x, y, Pal.yellow) } }
            if b >= 1 { c.set(10, 3, Pal.steel); c.set(10, 4, Pal.steel) }
            if b >= 2 { for y in 1...4 { c.set(10, y, Pal.silver) }; c.set(10, 1, Pal.yellow) }
            if b >= 3 { c.set(9, 1, Pal.yellow); c.set(11, 1, Pal.yellow); c.set(10, 0, Pal.white) }
            if b >= 4 { c.ring(cx: 10, cy: 10, r: 7.8, Pal.yellow) { x, y in (x * 2 + y) % 5 == 0 } }

        case .rail:
            // Repulsor: a glowing lens at the muzzle. Arsenal: missile pods on the flanks.
            if a >= 1 { c.set(9, 2, Pal.pink); c.set(10, 2, Pal.pink) }
            if a >= 2 { c.fillRect(8, 1, 4, 1, Pal.cyan) }
            if a >= 3 { c.fillRect(7, 0, 6, 1, Pal.white); for y in 4...10 { c.set(9, y, Pal.white); c.set(10, y, Pal.white) } }
            if a >= 4 { c.set(6, 1, Pal.cyan); c.set(13, 1, Pal.cyan) }
            for i in 0..<b {
                let y = 5 + i * 2
                c.fillRect(3, y, 3, 2, Pal.steel); c.set(3, y, Pal.red)
                c.fillRect(14, y, 3, 2, Pal.steel); c.set(16, y, Pal.red)
            }

        case .inferno:
            // Wildfire: a wider flame nozzle. Phoenix: fiery wings.
            if a >= 1 { c.set(8, 4, Pal.orange); c.set(11, 4, Pal.orange) }
            if a >= 2 { c.fillRect(7, 3, 6, 1, Pal.copper) }
            if a >= 3 { c.set(8, 2, Pal.amber); c.set(11, 2, Pal.amber); c.set(7, 1, Pal.red); c.set(12, 1, Pal.red) }
            if a >= 4 { c.set(9, 0, Pal.yellow); c.set(10, 0, Pal.white) }
            if b >= 1 { c.fillPolygon([(6, 10), (2, 8), (5, 13)], Pal.orange); c.fillPolygon([(14, 10), (18, 8), (15, 13)], Pal.orange) }
            if b >= 2 { c.fillPolygon([(6, 11), (1, 12), (6, 14)], Pal.red); c.fillPolygon([(14, 11), (19, 12), (14, 14)], Pal.red) }
            if b >= 3 { c.set(3, 9, Pal.yellow); c.set(16, 9, Pal.yellow) }
            if b >= 4 { c.fillPolygon([(8, 15), (10, 19), (12, 15)], Pal.amber); c.set(10, 17, Pal.yellow) }

        case .weaver:
            // Webmaster: a silk line and a cocoon in tow. Venom: dripping fangs and green markings.
            if a >= 1 { for y in 15...17 { c.set(10, y, Pal.mist) } }
            if a >= 2 { c.fillEllipse(cx: 10, cy: 18, rx: 1.5, ry: 1.5, Pal.mist) }
            if a >= 3 { c.line(9, 14, 4, 19, Pal.mist); c.line(10, 14, 15, 19, Pal.mist) }
            if a >= 4 { c.fillEllipse(cx: 10, cy: 17.5, rx: 2.2, ry: 2, Pal.white); c.set(10, 17, Pal.mist) }
            if b >= 1 { c.set(9, 5, Pal.lime); c.set(10, 5, Pal.lime) }
            if b >= 2 { c.set(9, 4, Pal.green); c.set(10, 4, Pal.green) }
            if b >= 3 { for (x, y) in [(9, 11), (10, 11), (9, 13), (10, 13), (9, 12), (10, 12)] { c.set(x, y, Pal.lime) } }
            if b >= 4 { for (x, y) in [(5, 9), (14, 9), (4, 13), (15, 13)] { c.set(x, y, Pal.lime) } }
        case .aegis:
            // Ricochet: spikes ring the shield. Commander: a red crest, then a laurel.
            let spikes = [(10, 0), (17, 5), (17, 13), (2, 13), (2, 5), (10, 18)]
            for (i, (x, y)) in spikes.enumerated() where i < a + (a >= 3 ? 2 : 0) {
                c.fillRect(x - (x == 10 ? 1 : 0), y, 2, 2, Pal.silver)
                c.set(x, y, Pal.white)
            }
            if b >= 1 { c.fillRect(9, 2, 2, 2, Pal.red) }
            if b >= 2 { c.fillRect(8, 1, 4, 1, Pal.red); c.set(10, 0, Pal.yellow) }
            if b >= 3 { for (x, y) in [(4, 14), (5, 15), (15, 14), (14, 15)] { c.set(x, y, Pal.lime) } }
            if b >= 4 { for (x, y) in [(3, 11), (3, 12), (16, 11), (16, 12), (6, 16), (13, 16)] { c.set(x, y, Pal.lime) } }
        case .cyclone:
            // Gale: outer gusts. Squall: hail riding the wind.
            if a >= 1 { c.ring(cx: 10, cy: 10, r: 8, Pal.mist) { x, y in (x + y * 3) % 7 == 0 } }
            if a >= 3 { c.ring(cx: 10, cy: 10, r: 8.8, Pal.white) { x, y in (x * 3 + y) % 9 == 0 } }
            for (i, (x, y)) in [(4, 3), (16, 16), (16, 3), (3, 16)].enumerated() where i < b {
                c.set(x, y, Pal.cyan); c.set(x + 1, y, Pal.white)
            }

        case .echo:
            // Resonance: crystal tips on the horn. Echolocation: a wider dish and sound arcs.
            if a >= 1 { c.fillRect(4, 4, 2, 2, Pal.cyan); c.fillRect(14, 4, 2, 2, Pal.cyan) }
            if a >= 2 { c.set(4, 3, Pal.white); c.set(15, 3, Pal.white) }
            if a >= 3 { c.fillRect(9, 1, 2, 2, Pal.cyan); c.set(9, 1, Pal.white) }
            if a >= 4 { for (x, y) in [(2, 8), (17, 8), (3, 1), (16, 1)] { c.set(x, y, Pal.cyan) } }
            if b >= 1 { c.fillRect(5, 14, 10, 2, Pal.forest) }
            if b >= 2 { c.set(4, 13, Pal.green); c.set(15, 13, Pal.green); c.set(4, 14, Pal.green); c.set(15, 14, Pal.green) }
            if b >= 3 { c.ring(cx: 10, cy: 7, r: 7.5, Pal.lime) { x, y in y < 3 && (x + y) % 2 == 0 } }
            if b >= 4 { c.ring(cx: 10, cy: 8, r: 9.5, Pal.white) { x, y in y < 2 && (x + y) % 2 == 0 } }
        case .mind:
            // Telepathy: antennae with glowing tips. Telekinesis: rocks float around it.
            if a >= 1 { c.line(7, 5, 6, 3, Pal.magenta); c.line(12, 5, 13, 3, Pal.magenta) }
            if a >= 2 { c.fillRect(5, 1, 2, 2, Pal.cyan); c.fillRect(13, 1, 2, 2, Pal.cyan) }
            if a >= 3 { c.set(10, 4, Pal.cyan); c.set(10, 3, Pal.white) }
            if a >= 4 { c.ring(cx: 10, cy: 10, r: 8.6, Pal.cyan) { x, y in (x + y) % 3 == 0 } }
            for (i, (x, y)) in [(2, 11), (17, 10), (10, 18), (3, 3)].enumerated() where i < b {
                c.fillCircle(cx: Double(x), cy: Double(y), r: 1.6, Pal.steel)
                c.set(x - 1, y - 1, Pal.silver)
            }
        case .chrono:
            // Stasis: gear teeth around the face. Rewind: a blue backward hand and arrows.
            if a >= 1 { for (x, y) in [(10, 3), (9, 3), (17, 10), (17, 9), (10, 17), (9, 17), (2, 10), (2, 9)] { c.set(x, y, Pal.steel) } }
            if a >= 2 { for (x, y) in [(4, 4), (15, 4), (4, 15), (15, 15)] { c.set(x, y, Pal.steel) } }
            if a >= 3 { c.ring(cx: 10, cy: 10, r: 8.5, Pal.silver) { x, y in (x + y) % 3 == 0 } }
            if a >= 4 { c.fillRect(9, 0, 2, 2, Pal.yellow) }
            if b >= 1 { for x in 6...9 { c.set(x, 10, Pal.blue) } }
            if b >= 2 { c.set(6, 9, Pal.blue); c.set(6, 11, Pal.blue) }
            if b >= 3 { c.ring(cx: 10, cy: 10, r: 8, Pal.cyan) { x, y in x < 7 && y > 5 } }
            if b >= 4 { c.ring(cx: 10, cy: 10, r: 8, Pal.cyan) { x, y in x > 13 && y < 14 } }
        case .star:
            // Solar: a longer, brighter beam and sun rays. Gravity: dark rings and orbiting stones.
            if a >= 1 { c.set(9, 2, Pal.yellow); c.set(10, 2, Pal.white) }
            if a >= 2 { c.set(8, 4, Pal.amber); c.set(11, 4, Pal.amber) }
            if a >= 3 { c.set(9, 1, Pal.amber); c.set(10, 1, Pal.yellow); c.set(10, 0, Pal.white) }
            if a >= 4 { for (x, y) in [(4, 12), (16, 12), (5, 17), (15, 17), (6, 7), (14, 7)] { c.set(x, y, Pal.yellow) } }
            if b >= 1 { c.ring(cx: 10, cy: 12, r: 6, Pal.purple) { x, y in (x + y) % 2 == 0 } }
            if b >= 2 { c.ring(cx: 10, cy: 12, r: 7, Pal.plum) { x, y in (x + y) % 2 == 1 } }
            if b >= 3 { c.fillRect(3, 9, 2, 2, Pal.ink); c.fillRect(15, 15, 2, 2, Pal.ink) }
            if b >= 4 { c.fillRect(16, 6, 2, 2, Pal.purple); c.fillRect(2, 16, 2, 2, Pal.purple) }
        case .midas:
            // Treasury: gems on the coins and a sack of gold. Golden Touch: a crown, then a scepter.
            if a >= 1 { c.set(7, 15, Pal.red) }
            if a >= 2 { c.set(13, 13, Pal.cyan) }
            if a >= 3 { c.fillCircle(cx: 16, cy: 15, r: 2.4, Pal.tan); c.set(16, 12, Pal.bark); c.set(15, 15, Pal.yellow) }
            if a >= 4 { c.fillCircle(cx: 4, cy: 15, r: 2.4, Pal.tan); c.set(4, 12, Pal.bark); c.set(4, 15, Pal.yellow) }
            if b >= 1 {
                let top = 12 - max(a, b) * 2
                c.fillRect(8, top - 2, 5, 2, Pal.yellow)
                c.set(8, top - 3, Pal.yellow); c.set(10, top - 3, Pal.yellow); c.set(12, top - 3, Pal.yellow)
                if b >= 2 { c.set(10, top - 2, Pal.red) }
            }
            if b >= 3 { c.line(15, 6, 15, 14, Pal.yellow); c.set(15, 5, Pal.cyan) }
        case .tide:
            // Torpedoes: torpedoes slung along the hull. Sonar: a dish and sound rings ahead.
            for i in 0..<a {
                let x = i % 2 == 0 ? 5 : 14
                let y = i < 2 ? 6 : 11
                c.fillRect(x, y, 1, 4, Pal.silver)
                c.set(x, y, Pal.red)
            }
            if b >= 1 { c.fillRect(9, 3, 2, 1, Pal.steel) }
            if b >= 2 { c.ring(cx: 10, cy: 5, r: 3.5, Pal.cyan) { x, y in y < 3 } }
            if b >= 3 { c.ring(cx: 10, cy: 5, r: 5.5, Pal.cyan) { x, y in y < 2 && x % 2 == 0 } }
            if b >= 4 { c.ring(cx: 10, cy: 10.5, r: 8.5, Pal.blue) { x, y in (x + y * 2) % 5 == 0 } }
        case .sniper:
            // Marksman: a longer barrel, a muzzle brake and a bipod. Spotter: a bigger scope and a laser.
            if a >= 1 { c.set(9, 4, Pal.steel); c.set(11, 4, Pal.steel) }
            if a >= 2 { c.set(10, 2, Pal.silver); c.fillRect(9, 2, 3, 1, Pal.steel) }
            if a >= 3 { c.line(8, 9, 5, 12, Pal.slate); c.line(12, 9, 15, 12, Pal.slate) }
            if a >= 4 { c.fillRect(9, 0, 3, 2, Pal.steel); c.set(10, 0, Pal.ink) }
            if b >= 1 { c.set(13, 6, Pal.red) }
            if b >= 2 { c.fillRect(11, 5, 3, 3, Pal.slate); c.set(12, 6, Pal.red) }
            if b >= 3 { for y in 1...4 { c.set(12, y, Pal.red) } }
            if b >= 4 { c.fillRect(11, 8, 4, 2, Pal.steel); c.set(14, 8, Pal.amber) }
        case .tamer:
            // Pack: a spiked collar, then pups at its side. Wild: fangs, a scar and a shaggy mane.
            if a >= 1 { c.fillRect(7, 14, 6, 1, Pal.bark) }
            if a >= 2 { c.set(7, 15, Pal.silver); c.set(10, 15, Pal.silver); c.set(12, 15, Pal.silver) }
            if a >= 3 {
                c.fillCircle(cx: 16, cy: 15, r: 2.2, Pal.steel)
                c.set(15, 12, Pal.steel); c.set(17, 12, Pal.steel); c.set(15, 15, Pal.ink); c.set(17, 15, Pal.ink)
            }
            if a >= 4 {
                c.fillCircle(cx: 4, cy: 15, r: 2.2, Pal.silver)
                c.set(3, 12, Pal.silver); c.set(5, 12, Pal.silver); c.set(3, 15, Pal.ink); c.set(5, 15, Pal.ink)
            }
            if b >= 1 { c.set(9, 15, Pal.white); c.set(11, 15, Pal.white) }
            if b >= 2 { c.line(6, 8, 8, 10, Pal.red) }
            if b >= 3 { for (x, y) in [(5, 9), (4, 11), (15, 9), (16, 11), (6, 13), (14, 13)] { c.set(x, y, Pal.tan) } }
            if b >= 4 { c.set(8, 10, Pal.red); c.set(12, 10, Pal.red); c.set(5, 7, Pal.tan); c.set(15, 7, Pal.tan) }
        case .alchemist:
            // Acids: bubbles fizz out and acid drips. Brews: a cork, a potion belt and side vials.
            if a >= 1 { c.set(12, 3, Pal.lime) }
            if a >= 2 { c.set(8, 2, Pal.lime); c.set(13, 1, Pal.green) }
            if a >= 3 { c.set(11, 0, Pal.lime); c.set(7, 0, Pal.green); c.set(6, 15, Pal.lime); c.set(14, 16, Pal.lime) }
            if a >= 4 { c.fillCircle(cx: 10, cy: 13, r: 2.2, Pal.yellow); c.set(9, 12, Pal.white) }
            if b >= 1 { c.fillRect(9, 3, 2, 1, Pal.bark) }
            if b >= 2 { c.fillRect(5, 11, 10, 1, Pal.bark); c.set(6, 11, Pal.red); c.set(13, 11, Pal.blue) }
            if b >= 3 {
                c.fillRect(3, 11, 2, 3, Pal.blue); c.set(3, 10, Pal.mist)
                c.fillRect(15, 11, 2, 3, Pal.red); c.set(16, 10, Pal.mist)
            }
            if b >= 4 { c.fillRect(9, 1, 2, 2, Pal.red); c.set(9, 1, Pal.pink) }
        }
    }

    // MARK: Enemies

    // MARK: Commanders

    static func commanderCanvas(_ kind: CommanderKind, frame: Int, skin: CommanderSkin) -> PixelCanvas {
        let maps = SpriteMaps.commanderFrames(kind)
        var canvas = PixelCanvas(map: maps[frame % maps.count]).padded(1)
        if let ramp = Pal.ramp(skin) {
            // Keep the light and shade of each pixel, but in the skin's colours.
            canvas = canvas.recolored { color in
                let light = (Int(color.r) * 3 + Int(color.g) * 6 + Int(color.b)) / 10
                return ramp[min(ramp.count - 1, light * ramp.count / 200)].alpha(color.a)
            }
        }
        canvas.outline()
        return canvas
    }

    static func commanderFrames(_ kind: CommanderKind, skin: CommanderSkin) -> [SKTexture] {
        frames("commander.\(kind.rawValue).\(skin.rawValue)") {
            (0..<SpriteMaps.commanderFrames(kind).count).map { commanderCanvas(kind, frame: $0, skin: skin) }
        }
    }

    static func commanderIcon(_ kind: CommanderKind, skin: CommanderSkin) -> UIImage {
        image("commanderIcon.\(kind.rawValue).\(skin.rawValue)") { commanderCanvas(kind, frame: 0, skin: skin) }
    }

    static func enemyCanvas(_ kind: EnemyKind, frame: Int) -> PixelCanvas {
        let maps = SpriteMaps.enemyFrames(kind)
        var canvas = PixelCanvas(map: maps[frame % maps.count]).padded(1)
        canvas.outline()
        return canvas
    }

    static func enemyFrames(_ kind: EnemyKind) -> [SKTexture] {
        frames("enemy.\(kind.rawValue)") {
            (0..<SpriteMaps.enemyFrames(kind).count).map { enemyCanvas(kind, frame: $0) }
        }
    }

    static func enemyIcon(_ kind: EnemyKind, frame: Int = 0) -> UIImage {
        image("enemyIcon.\(kind.rawValue).\(frame)") { enemyCanvas(kind, frame: frame) }
    }

    static var coreImage: UIImage {
        image("coreImage") {
            var crystal = PixelCanvas(map: SpriteMaps.coreCrystal).padded(1)
            crystal.outline()
            var pedestal = PixelCanvas(map: SpriteMaps.corePedestal).padded(1)
            pedestal.outline()
            var c = PixelCanvas(width: pedestal.width, height: crystal.height + pedestal.height - 3)
            c.stamp(pedestal, x: 0, y: crystal.height - 3)
            c.stamp(crystal, x: (pedestal.width - crystal.width) / 2, y: 0)
            return c
        }
    }

    static func shadow(width: Int) -> SKTexture {
        texture("shadow.\(width)") {
            var c = PixelCanvas(width: width, height: 3)
            c.fillEllipse(cx: Double(width) / 2, cy: 1.5, rx: Double(width) / 2, ry: 1.5, Pal.ink.alpha(110))
            return c
        }
    }

    // MARK: Core, portal and decoration

    static var coreCrystal: SKTexture {
        texture("coreCrystal") {
            var c = PixelCanvas(map: SpriteMaps.coreCrystal).padded(1)
            c.outline()
            return c
        }
    }

    static var corePedestal: SKTexture {
        texture("corePedestal") {
            var c = PixelCanvas(map: SpriteMaps.corePedestal).padded(1)
            c.outline()
            return c
        }
    }

    static var portalFrames: [SKTexture] {
        frames("portal") {
            (0..<4).map { k in
                var c = PixelCanvas(width: 16, height: 16)
                c.fillCircle(cx: 8, cy: 8, r: 6.6, Pal.purple)
                c.fillCircle(cx: 8, cy: 8, r: 5.2, Pal.plum)
                c.fillCircle(cx: 8, cy: 8, r: 3.2, Pal.ink)
                for i in 0..<3 {
                    let angle = Double(k) * .pi / 6 + Double(i) * 2 * .pi / 3
                    c.set(Int(8 + cos(angle) * 5.2), Int(8 + sin(angle) * 5.2), Pal.pink)
                    c.set(Int(8 + cos(angle + 0.6) * 3.8), Int(8 + sin(angle + 0.6) * 3.8), Pal.magenta)
                }
                c.outline()
                return c
            }
        }
    }

    static func obstacle(variant: Int, terrain: Terrain) -> SKTexture {
        let props = SpriteMaps.props(terrain)
        return texture("obstacle.\(terrain.rawValue).\(variant % props.count)") {
            let sprite = PixelCanvas(map: props[variant % props.count])
            var c = PixelCanvas(width: sprite.width + 2, height: sprite.height + 3)
            c.fillEllipse(cx: Double(c.width) / 2, cy: Double(c.height) - 2.5, rx: Double(sprite.width) / 2, ry: 2, Pal.ink.alpha(90))
            var body = sprite.padded(1)
            body.outline()
            c.stamp(body, x: 0, y: 0)
            return c
        }
    }

    static var chevron: SKTexture { texture("chevron") { PixelCanvas(map: SpriteMaps.chevron) } }

    static var bracket: SKTexture { texture("bracket") { PixelCanvas(map: SpriteMaps.bracket) } }

    static var healPlus: SKTexture {
        texture("healPlus") {
            var c = PixelCanvas(map: SpriteMaps.healPlus).padded(1)
            c.outline()
            return c
        }
    }

    /// A single white pixel, used for particles and solid bars.
    static var pixel: SKTexture { texture("pixel") { PixelCanvas(width: 1, height: 1, fill: Pal.white) } }

    // MARK: Projectiles and effects

    static var bolt: SKTexture {
        texture("bolt") { PixelCanvas(map: [".C.", "CWC", ".C."]) }
    }

    /// Projectile sprite for a bolt-style hero.
    static func bolt(for kind: TowerKind) -> SKTexture {
        switch kind {
        case .weaver:
            texture("bolt.weaver") { PixelCanvas(map: [".w.", "wWw", ".w."]) }
        case .aegis:
            texture("bolt.aegis") {
                var c = PixelCanvas(map: [".YYY.", "YBBBY", "YBWBY", "YBBBY", ".YYY."])
                c = c.padded(1)
                c.outline()
                return c
            }
        case .cyclone:
            texture("bolt.cyclone") { PixelCanvas(map: ["w...w", ".wWw.", "..W.."]) }
        default:
            bolt
        }
    }

    static var shell: SKTexture {
        texture("shell") {
            var c = PixelCanvas(map: [".oo.", "oYOo", "oOOo", ".oo."]).padded(1)
            c.outline()
            return c
        }
    }

    static var missile: SKTexture {
        texture("missile") {
            var c = PixelCanvas(map: [".R.", "wWw", "wsw", "wsw", "O.O"]).padded(1)
            c.outline()
            return c
        }
    }

    /// Lightning badge shown above heroes whose power is ready.
    static var powerReady: SKTexture {
        texture("powerReady") {
            var c = PixelCanvas(map: SpriteMaps.icon(.bolt)).padded(1)
            c.outline()
            return c
        }
    }

    /// Magic bubble drawn around shielded villains.
    static func shieldBubble(width: Int) -> SKTexture {
        let size = width + (width % 2) + 4
        return texture("shield.\(size)") {
            var c = PixelCanvas(width: size, height: size)
            let center = Double(size) / 2
            c.ring(cx: center, cy: center, r: center - 1, Pal.pink.alpha(220)) { x, y in (x + y) % 3 != 0 }
            c.fillCircle(cx: center, cy: center, r: center - 2, Pal.magenta.alpha(50))
            return c
        }
    }

    /// Expanding ring used by hero powers and villain pulses.
    static func ringFrames(radius: Int, color: PixelColor, accent: PixelColor) -> [SKTexture] {
        frames("ring.\(radius).\(color.r).\(color.g).\(color.b)") {
            let size = radius * 2 + 2
            let center = Double(size) / 2
            return (1...5).map { k in
                var c = PixelCanvas(width: size, height: size)
                let r = Double(radius) * Double(k) / 5
                c.ring(cx: center, cy: center, r: r, thickness: 2, k < 4 ? color : accent) { x, y in
                    k < 4 || PixelNoise.value(x, y, seed: k) < 600
                }
                c.ring(cx: center, cy: center, r: max(1, r - 3), accent.alpha(120)) { x, y in (x + y) % 2 == 0 }
                return c
            }
        }
    }

    static var muzzleFlash: SKTexture {
        texture("muzzle") { PixelCanvas(map: ["..y..", ".yWy.", "yWWWy", ".yWy.", "..y.."]) }
    }

    /// Dashed ring with a dithered fill showing a tower's reach.
    static func rangeRing(range: Double, color: PixelColor) -> SKTexture {
        let r = Int((range * Double(tilePixels)).rounded())
        return texture("range.\(r).\(color.r).\(color.g).\(color.b)") {
            let size = r * 2 + 2
            let center = Double(size) / 2
            var c = PixelCanvas(width: size, height: size)
            for y in 0..<size {
                for x in 0..<size where (x + y) % 2 == 0 {
                    let dx = Double(x) + 0.5 - center, dy = Double(y) + 0.5 - center
                    if dx * dx + dy * dy <= Double(r - 1) * Double(r - 1) { c.set(x, y, color.alpha(55)) }
                }
            }
            c.ring(cx: center, cy: center, r: Double(r), thickness: 1.2, color) { x, y in
                let angle = atan2(Double(y) - center, Double(x) - center) + .pi
                return Int(angle / (2 * .pi) * Double(r) * 1.4) % 3 != 2
            }
            return c
        }
    }

    static func explosionFrames(radius: Int) -> [SKTexture] {
        frames("explosion.\(radius)") {
            let r = Double(radius)
            let size = radius * 2 + 2
            let center = Double(size) / 2
            func canvas() -> PixelCanvas { PixelCanvas(width: size, height: size) }
            var f0 = canvas()
            f0.fillCircle(cx: center, cy: center, r: r * 0.35, Pal.white)
            f0.ring(cx: center, cy: center, r: r * 0.45, Pal.yellow)
            var f1 = canvas()
            f1.fillCircle(cx: center, cy: center, r: r * 0.7, Pal.yellow)
            f1.fillCircle(cx: center, cy: center, r: r * 0.38, Pal.white)
            f1.ring(cx: center, cy: center, r: r * 0.78, thickness: 1.5, Pal.orange) { x, y in PixelNoise.value(x, y) < 600 }
            var f2 = canvas()
            f2.fillCircle(cx: center, cy: center, r: r * 0.92, Pal.orange)
            f2.fillCircle(cx: center, cy: center, r: r * 0.55, Pal.yellow)
            f2.ring(cx: center, cy: center, r: r * 0.92, thickness: 2, Pal.rust) { x, y in PixelNoise.value(x, y, seed: 2) < 500 }
            var f3 = canvas()
            f3.ring(cx: center, cy: center, r: r, thickness: 3, Pal.rust) { x, y in PixelNoise.value(x, y, seed: 3) < 650 }
            f3.fillCircle(cx: center, cy: center, r: r * 0.7, .clear)
            for y in 0..<size {
                for x in 0..<size where PixelNoise.value(x, y, seed: 4) < 260 {
                    let dx = Double(x) + 0.5 - center, dy = Double(y) + 0.5 - center
                    if dx * dx + dy * dy < r * r * 0.6 { f3.set(x, y, Pal.steel) }
                }
            }
            var f4 = canvas()
            for y in 0..<size {
                for x in 0..<size where PixelNoise.value(x, y, seed: 5) < 110 {
                    let dx = Double(x) + 0.5 - center, dy = Double(y) + 0.5 - center
                    if dx * dx + dy * dy < r * r { f4.set(x, y, Pal.slate) }
                }
            }
            return [f0, f1, f2, f3, f4]
        }
    }

    static func frostFrames(radius: Int) -> [SKTexture] {
        frames("frost.\(radius)") {
            let size = radius * 2 + 2
            let center = Double(size) / 2
            return (1...4).map { k in
                var c = PixelCanvas(width: size, height: size)
                let rr = Double(radius) * Double(k) / 4
                c.ring(cx: center, cy: center, r: rr, thickness: 1.6, k < 4 ? Pal.cyan : Pal.mist) { x, y in
                    k < 3 || PixelNoise.value(x, y, seed: k) < 700
                }
                for y in 0..<size {
                    for x in 0..<size where PixelNoise.value(x, y, seed: 10 + k) < 18 {
                        let dx = Double(x) + 0.5 - center, dy = Double(y) + 0.5 - center
                        if dx * dx + dy * dy < rr * rr { c.set(x, y, Pal.white) }
                    }
                }
                return c
            }
        }
    }

    static func poofFrames(color: PixelColor) -> [SKTexture] {
        frames("poof.\(color.r).\(color.g).\(color.b)") {
            let size = 16
            let center = Double(size) / 2
            func point(_ angle: Double, _ r: Double) -> (Int, Int) {
                (Int(center + cos(angle) * r), Int(center + sin(angle) * r))
            }
            var f0 = PixelCanvas(width: size, height: size)
            f0.fillCircle(cx: center, cy: center, r: 3, Pal.white)
            var f1 = PixelCanvas(width: size, height: size)
            f1.ring(cx: center, cy: center, r: 4.5, thickness: 1.6, Pal.white)
            var f2 = PixelCanvas(width: size, height: size)
            f2.ring(cx: center, cy: center, r: 5.5, Pal.mist) { x, y in (x + y) % 2 == 0 }
            var f3 = PixelCanvas(width: size, height: size)
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4 + .pi / 8
                let (x1, y1) = point(angle, 5.5)
                f1.set(x1, y1, color)
                let (x2, y2) = point(angle, 7)
                f2.set(x2, y2, color)
                if i % 2 == 0 {
                    let (x3, y3) = point(angle, 8)
                    f3.set(x3, y3, color)
                }
            }
            return [f0, f1, f2, f3]
        }
    }

    static var dustFrames: [SKTexture] {
        frames("dust") {
            (0..<3).map { k in
                var c = PixelCanvas(width: 24, height: 10)
                let spread = 4 + Double(k) * 3
                for side in [-1.0, 1.0] {
                    c.fillCircle(cx: 12 + side * spread, cy: 6, r: 2.6 - Double(k) * 0.6, k == 2 ? Pal.steel : Pal.silver)
                    c.fillCircle(cx: 12 + side * (spread - 2.5), cy: 7, r: 2 - Double(k) * 0.5, Pal.mist)
                }
                return c
            }
        }
    }

    static var sparkleFrames: [SKTexture] {
        frames("sparkle") {
            let positions = [(4, 10), (11, 7), (7, 3), (13, 12), (2, 5)]
            return (0..<4).map { k in
                var c = PixelCanvas(width: 16, height: 16)
                for (i, p) in positions.enumerated() where (i + k) % 2 == 0 {
                    let y = p.1 - k
                    c.set(p.0, y, Pal.white)
                    c.set(p.0 - 1, y, Pal.yellow); c.set(p.0 + 1, y, Pal.yellow)
                    c.set(p.0, y - 1, Pal.yellow); c.set(p.0, y + 1, Pal.yellow)
                }
                return c
            }
        }
    }

    /// Pixel-font label as a texture (cached; used for short popups like "+12").
    static func text(_ string: String, color: PixelColor) -> SKTexture {
        if textureCache.count > 600 { textureCache = textureCache.filter { !$0.key.hasPrefix("text.") } }
        return texture("text.\(string).\(color.r).\(color.g).\(color.b)") { PixelFont.render(string, color: color) }
    }

    /// One-off lightning texture through `points` (world art-pixel coordinates, y up).
    /// Returns the texture and the world position of its bottom-left corner.
    static func lightning(through points: [CGPoint]) -> (SKTexture, CGPoint) {
        let margin = 4
        let minX = Int(points.map(\.x).min() ?? 0) - margin
        let maxX = Int(points.map(\.x).max() ?? 0) + margin
        let minY = Int(points.map(\.y).min() ?? 0) - margin
        let maxY = Int(points.map(\.y).max() ?? 0) + margin
        var c = PixelCanvas(width: maxX - minX + 1, height: maxY - minY + 1)
        func local(_ p: CGPoint) -> (Int, Int) { (Int(p.x) - minX, maxY - Int(p.y)) }
        for (a, b) in zip(points, points.dropFirst()) {
            let (x0, y0) = local(a), (x1, y1) = local(b)
            let length = hypot(Double(x1 - x0), Double(y1 - y0))
            let steps = max(1, Int(length / 5))
            var previous = (x0, y0)
            for s in 1...steps {
                let t = Double(s) / Double(steps)
                var x = Double(x0) + Double(x1 - x0) * t
                var y = Double(y0) + Double(y1 - y0) * t
                if s < steps {
                    x += Double.random(in: -2...2)
                    y += Double.random(in: -2...2)
                }
                let next = (Int(x.rounded()), Int(y.rounded()))
                c.line(previous.0, previous.1, next.0, next.1, Pal.white)
                previous = next
            }
        }
        c.outline(Pal.pink)
        c.outline(Pal.magenta.alpha(170))
        return (makeTexture(c), CGPoint(x: minX, y: minY))
    }

    /// One-off beam texture between two world art-pixel points.
    static func beam(from start: CGPoint, to end: CGPoint, glow: PixelColor = Pal.pink, edge: PixelColor = Pal.hotRed) -> (SKTexture, CGPoint) {
        let margin = 3
        let minX = Int(min(start.x, end.x)) - margin, maxX = Int(max(start.x, end.x)) + margin
        let minY = Int(min(start.y, end.y)) - margin, maxY = Int(max(start.y, end.y)) + margin
        var c = PixelCanvas(width: maxX - minX + 1, height: maxY - minY + 1)
        c.line(Int(start.x) - minX, maxY - Int(start.y), Int(end.x) - minX, maxY - Int(end.y), Pal.white)
        c.outline(glow)
        c.outline(edge.alpha(200))
        return (makeTexture(c), CGPoint(x: minX, y: minY))
    }

    // MARK: Board

    /// The battlefield ground (grass and path) in logical orientation, 16 art pixels per tile.
    static func board(for map: MapDefinition) -> SKTexture {
        texture("board.\(map.id)") { boardCanvas(for: map) }
    }

    static func boardImage(for map: MapDefinition) -> UIImage {
        image("boardImage.\(map.id)") { boardCanvas(for: map) }
    }

    /// Board plus obstacles, crystal and portal, for the map picker.
    static func mapPreview(for map: MapDefinition) -> UIImage {
        image("mapPreview.\(map.id)") {
            var c = boardCanvas(for: map)
            func stampCentered(_ sprite: PixelCanvas, at cell: GridPoint, bottomOffset: Int) {
                c.stamp(sprite, x: cell.col * tilePixels + (tilePixels - sprite.width) / 2,
                        y: cell.row * tilePixels + tilePixels - sprite.height + bottomOffset)
            }
            let props = SpriteMaps.props(map.terrain)
            for cell in map.obstacles.sorted(by: { $0.row < $1.row }) {
                let variant = PixelNoise.value(cell.col, cell.row, seed: 3)
                var sprite = PixelCanvas(map: props[variant % props.count]).padded(1)
                sprite.outline()
                stampCentered(sprite, at: cell, bottomOffset: 0)
            }
            var portal = PixelCanvas(width: 16, height: 16)
            portal.fillCircle(cx: 8, cy: 8, r: 6.6, Pal.purple)
            portal.fillCircle(cx: 8, cy: 8, r: 5.2, Pal.plum)
            portal.fillCircle(cx: 8, cy: 8, r: 3.2, Pal.ink)
            portal.outline()
            let entry = map.waypoints[0]
            c.stamp(portal, x: max(0, entry.col + 1) * tilePixels, y: entry.row * tilePixels)
            var crystal = PixelCanvas(map: SpriteMaps.coreCrystal).padded(1)
            crystal.outline()
            stampCentered(crystal, at: map.coreCell, bottomOffset: -2)
            return c
        }
    }

    static func boardCanvas(for map: MapDefinition) -> PixelCanvas {
        let w = map.columns * tilePixels, h = map.rows * tilePixels
        var c = PixelCanvas(width: w, height: h)
        let colors = Pal.terrain(map.terrain)
        func isPath(_ x: Int, _ y: Int) -> Bool {
            let cx = min(max(x, 0), w - 1), cy = min(max(y, 0), h - 1)
            return map.pathCells.contains(GridPoint(cx / tilePixels, cy / tilePixels))
        }
        func isWater(_ x: Int, _ y: Int) -> Bool {
            let cx = min(max(x, 0), w - 1), cy = min(max(y, 0), h - 1)
            return map.water.contains(GridPoint(cx / tilePixels, cy / tilePixels))
        }
        for y in 0..<h {
            for x in 0..<w {
                let n = PixelNoise.value(x, y, seed: 7)
                let onPath = isPath(x, y)
                let edge = isPath(x - 1, y) != onPath || isPath(x + 1, y) != onPath
                    || isPath(x, y - 1) != onPath || isPath(x, y + 1) != onPath
                var color: PixelColor
                if onPath {
                    color = colors.path
                    if n < 60 { color = colors.pathLight } else if n < 110 { color = colors.pathMid } else if n < 150 { color = colors.pathDark }
                    if edge { color = colors.pathDark }
                } else if isWater(x, y) {
                    color = n < 120 ? Pal.blue : n >= 985 ? Pal.cyan : Pal.ocean
                    if !isWater(x - 1, y) || !isWater(x + 1, y) || !isWater(x, y - 1) || !isWater(x, y + 1) { color = Pal.deepTeal }
                } else {
                    let cell = GridPoint(x / tilePixels, y / tilePixels)
                    color = (cell.col + cell.row) % 2 == 0 ? colors.groundA : colors.groundB
                    if n < 40 { color = colors.light } else if n < 85 { color = colors.dark }
                    if n >= 997 {
                        color = colors.sparkles[0]
                    } else if n >= 995 {
                        color = colors.sparkles[1]
                    } else if n >= 993 {
                        color = colors.sparkles[2]
                    }
                    if edge { color = colors.dark }
                }
                c.set(x, y, color)
            }
        }
        // Grass tufts and pebbles, one decision per tile.
        for row in 0..<map.rows {
            for col in 0..<map.columns {
                let cell = GridPoint(col, row)
                let roll = PixelNoise.value(col, row, seed: 21)
                let x = col * tilePixels + 3 + roll % 10
                let y = row * tilePixels + 4 + (roll / 10) % 9
                if map.pathCells.contains(cell) {
                    if roll < 450 {
                        c.set(x, y, Pal.silver); c.set(x + 1, y, Pal.mist)
                        c.set(x, y + 1, Pal.steel); c.set(x + 1, y + 1, Pal.steel)
                    }
                } else if roll < 600 && !map.water.contains(cell) {
                    c.set(x, y, colors.light)
                    c.set(x - 1, y + 1, colors.light); c.set(x + 1, y + 1, colors.light)
                    c.set(x, y + 1, colors.dark)
                }
            }
        }
        return c
    }

    // MARK: UI

    static func icon(_ icon: SpriteMaps.Icon, outlined: Bool = true) -> UIImage {
        image("icon.\(icon.rawValue).\(outlined)") {
            var c = PixelCanvas(map: SpriteMaps.icon(icon))
            if outlined {
                c = c.padded(1)
                c.outline()
            }
            return c
        }
    }

    /// An empty star for unearned ratings.
    static var starEmpty: UIImage {
        image("icon.starEmpty") {
            var c = PixelCanvas(map: SpriteMaps.icon(.star)).recolored { _ in Pal.slate }.padded(1)
            c.outline()
            return c
        }
    }
}
