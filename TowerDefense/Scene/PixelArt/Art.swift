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

    static func turret(_ kind: TowerKind, level: Int) -> SKTexture {
        texture("turret.\(kind.rawValue).\(level)") { turretCanvas(kind, level: level) }
    }

    /// Base and turret composited, for the build panel and menus.
    static func towerIcon(_ kind: TowerKind, tiers: [Int] = [0, 0]) -> UIImage {
        image("towerIcon.\(kind.rawValue).\(tiers[0]).\(tiers[1])") {
            var canvas = towerBaseCanvas(kind, tiers: tiers)
            canvas.stamp(turretCanvas(kind, level: TowerKind.visualLevel(tiers: tiers)), x: 0, y: 0)
            return canvas
        }
    }

    static func towerBaseCanvas(_ kind: TowerKind, tiers: [Int]) -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        // Stone pedestal with a darker front face for a 3/4 view.
        for y in 2...13 {
            for x in 1...14 where !((y == 2 || y == 13) && (x == 1 || x == 14)) {
                c.set(x, y, Pal.steel)
            }
        }
        for x in 2...13 { c.set(x, 2, Pal.silver) }
        for y in 3...11 { c.set(1, y, Pal.silver) }
        for y in 3...12 { c.set(14, y, Pal.slate) }
        for x in 1...14 { c.set(x, 13, Pal.slate) }
        for x in 2...13 { c.set(x, 14, Pal.navy) }
        c.fillCircle(cx: 8, cy: 8, r: 4.6, Pal.slate)
        c.fillCircle(cx: 8, cy: 8, r: 3.6, Pal.navy)
        let accent = Pal.tower(kind)
        for (x, y) in [(3, 4), (12, 4), (3, 11), (12, 11)] { c.set(x, y, accent) }
        // Tier pips on the front face: path 1 from the left, path 2 from the right.
        for i in 0..<tiers[0] { c.set(2 + i * 2, 14, Pal.amber) }
        for i in 0..<tiers[1] { c.set(13 - i * 2, 14, Pal.cyan) }
        c.outline()
        return c
    }

    static func turretCanvas(_ kind: TowerKind, level: Int) -> PixelCanvas {
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
        }
        // Rail barrels reach the top edge at level 3, so keep the outline inside the canvas.
        c.outline()
        return c
    }

    // MARK: Enemies

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

    static func obstacle(variant: Int) -> SKTexture {
        let isTree = variant % 2 == 0
        return texture(isTree ? "tree" : "rock") {
            let sprite = PixelCanvas(map: isTree ? SpriteMaps.tree : SpriteMaps.rock)
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

    /// One-off rail beam texture between two world art-pixel points.
    static func beam(from start: CGPoint, to end: CGPoint) -> (SKTexture, CGPoint) {
        let margin = 3
        let minX = Int(min(start.x, end.x)) - margin, maxX = Int(max(start.x, end.x)) + margin
        let minY = Int(min(start.y, end.y)) - margin, maxY = Int(max(start.y, end.y)) + margin
        var c = PixelCanvas(width: maxX - minX + 1, height: maxY - minY + 1)
        c.line(Int(start.x) - minX, maxY - Int(start.y), Int(end.x) - minX, maxY - Int(end.y), Pal.white)
        c.outline(Pal.pink)
        c.outline(Pal.hotRed.alpha(200))
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
            for cell in map.obstacles.sorted(by: { $0.row < $1.row }) {
                let isTree = PixelNoise.value(cell.col, cell.row, seed: 3) % 2 == 0
                var sprite = PixelCanvas(map: isTree ? SpriteMaps.tree : SpriteMaps.rock).padded(1)
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
        func isPath(_ x: Int, _ y: Int) -> Bool {
            let cx = min(max(x, 0), w - 1), cy = min(max(y, 0), h - 1)
            return map.pathCells.contains(GridPoint(cx / tilePixels, cy / tilePixels))
        }
        for y in 0..<h {
            for x in 0..<w {
                let n = PixelNoise.value(x, y, seed: 7)
                let onPath = isPath(x, y)
                let edge = isPath(x - 1, y) != onPath || isPath(x + 1, y) != onPath
                    || isPath(x, y - 1) != onPath || isPath(x, y + 1) != onPath
                var color: PixelColor
                if onPath {
                    color = Pal.clay
                    if n < 60 { color = Pal.tan } else if n < 110 { color = Pal.copper } else if n < 150 { color = Pal.bark }
                    if edge { color = Pal.bark }
                } else {
                    let cell = GridPoint(x / tilePixels, y / tilePixels)
                    color = (cell.col + cell.row) % 2 == 0 ? Pal.grassA : Pal.grassB
                    if n < 40 { color = Pal.lime } else if n < 85 { color = Pal.forest }
                    if n >= 997 { color = Pal.yellow } else if n >= 995 { color = Pal.pink } else if n >= 993 { color = Pal.white }
                    if edge { color = Pal.forest }
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
                } else if roll < 600 {
                    c.set(x, y, Pal.lime)
                    c.set(x - 1, y + 1, Pal.lime); c.set(x + 1, y + 1, Pal.lime)
                    c.set(x, y + 1, Pal.forest)
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
