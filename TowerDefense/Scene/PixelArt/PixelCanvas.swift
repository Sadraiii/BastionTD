import CoreGraphics
import UIKit

/// An RGBA color for pixel art.
struct PixelColor: Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    init(_ hex: UInt32, alpha: UInt8 = 255) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = alpha
    }

    static let clear = PixelColor(0, alpha: 0)

    var isClear: Bool { a == 0 }

    func alpha(_ value: UInt8) -> PixelColor {
        var copy = self
        copy.a = value
        return copy
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

/// A tiny software bitmap for building pixel-art sprites in code.
///
/// Coordinates are in art pixels with (0, 0) at the top-left. Out-of-bounds
/// writes are ignored so drawing helpers never need to clip.
struct PixelCanvas {
    let width: Int
    let height: Int
    private(set) var pixels: [PixelColor]

    init(width: Int, height: Int, fill: PixelColor = .clear) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = Array(repeating: fill, count: self.width * self.height)
    }

    /// Builds a canvas from a character map. Each character is looked up in
    /// `palette`; unknown characters (like ".") are transparent. Short rows are padded.
    init(map: [String], palette: [Character: PixelColor] = Pal.chars) {
        let w = map.map(\.count).max() ?? 1
        self.init(width: w, height: map.count)
        for (y, row) in map.enumerated() {
            for (x, char) in row.enumerated() {
                if let color = palette[char] { set(x, y, color) }
            }
        }
    }

    func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    subscript(x: Int, y: Int) -> PixelColor {
        contains(x, y) ? pixels[y * width + x] : .clear
    }

    mutating func set(_ x: Int, _ y: Int, _ color: PixelColor) {
        guard contains(x, y) else { return }
        pixels[y * width + x] = color
    }

    mutating func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: PixelColor) {
        for yy in y..<(y + h) {
            for xx in x..<(x + w) { set(xx, yy, color) }
        }
    }

    /// Fills a circle whose center may sit between pixels (use .5 offsets for even sizes).
    mutating func fillCircle(cx: Double, cy: Double, r: Double, _ color: PixelColor) {
        let minX = Int((cx - r).rounded(.down)), maxX = Int((cx + r).rounded(.up))
        let minY = Int((cy - r).rounded(.down)), maxY = Int((cy + r).rounded(.up))
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                if dx * dx + dy * dy <= r * r { set(x, y, color) }
            }
        }
    }

    mutating func fillEllipse(cx: Double, cy: Double, rx: Double, ry: Double, _ color: PixelColor) {
        let minX = Int((cx - rx).rounded(.down)), maxX = Int((cx + rx).rounded(.up))
        let minY = Int((cy - ry).rounded(.down)), maxY = Int((cy + ry).rounded(.up))
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 { set(x, y, color) }
            }
        }
    }

    /// Draws a ring. `pattern` decides per angle step whether a pixel is drawn (for dashes and sparkle).
    mutating func ring(cx: Double, cy: Double, r: Double, thickness: Double = 1, _ color: PixelColor,
                       pattern: ((Int, Int) -> Bool)? = nil) {
        let outer = r + thickness / 2, inner = max(0, r - thickness / 2)
        let minX = Int((cx - outer).rounded(.down)), maxX = Int((cx + outer).rounded(.up))
        let minY = Int((cy - outer).rounded(.down)), maxY = Int((cy + outer).rounded(.up))
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= outer, d >= inner else { continue }
                if let pattern, !pattern(x, y) { continue }
                set(x, y, color)
            }
        }
    }

    /// Bresenham line.
    mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: PixelColor) {
        var x = x0, y = y0
        let dx = abs(x1 - x0), dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
        var error = dx + dy
        while true {
            set(x, y, color)
            if x == x1 && y == y1 { break }
            let e2 = 2 * error
            if e2 >= dy { error += dy; x += sx }
            if e2 <= dx { error += dx; y += sy }
        }
    }

    /// Copies the opaque pixels of `other` with its top-left corner at (x, y).
    mutating func stamp(_ other: PixelCanvas, x: Int, y: Int, flipX: Bool = false, tint: PixelColor? = nil) {
        for sy in 0..<other.height {
            for sx in 0..<other.width {
                let source = other[flipX ? other.width - 1 - sx : sx, sy]
                guard !source.isClear else { continue }
                if let tint {
                    set(x + sx, y + sy, tint.alpha(source.a))
                } else {
                    set(x + sx, y + sy, source)
                }
            }
        }
    }

    /// Adds a 1-pixel outline around every opaque shape.
    mutating func outline(_ color: PixelColor = Pal.ink, diagonals: Bool = false) {
        let source = self
        for y in 0..<height {
            for x in 0..<width where source[x, y].isClear {
                var touches = !source[x - 1, y].isClear || !source[x + 1, y].isClear
                    || !source[x, y - 1].isClear || !source[x, y + 1].isClear
                if diagonals && !touches {
                    touches = !source[x - 1, y - 1].isClear || !source[x + 1, y - 1].isClear
                        || !source[x - 1, y + 1].isClear || !source[x + 1, y + 1].isClear
                }
                if touches { set(x, y, color) }
            }
        }
    }

    /// Returns a copy with a transparent border so outlines have room.
    func padded(_ amount: Int) -> PixelCanvas {
        var result = PixelCanvas(width: width + amount * 2, height: height + amount * 2)
        result.stamp(self, x: amount, y: amount)
        return result
    }

    /// Replaces every opaque pixel's color while keeping its alpha.
    func recolored(_ mapping: (PixelColor) -> PixelColor) -> PixelCanvas {
        var copy = self
        for i in copy.pixels.indices where !copy.pixels[i].isClear {
            copy.pixels[i] = mapping(copy.pixels[i])
        }
        return copy
    }

    func makeCGImage() -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (i, p) in pixels.enumerated() {
            // Premultiplied alpha.
            let alpha = UInt16(p.a)
            bytes[i * 4] = UInt8(UInt16(p.r) * alpha / 255)
            bytes[i * 4 + 1] = UInt8(UInt16(p.g) * alpha / 255)
            bytes[i * 4 + 2] = UInt8(UInt16(p.b) * alpha / 255)
            bytes[i * 4 + 3] = p.a
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    func makeUIImage() -> UIImage {
        guard let cg = makeCGImage() else { return UIImage() }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}

/// Deterministic hash noise for procedural pixel textures.
enum PixelNoise {
    static func value(_ x: Int, _ y: Int, seed: Int = 0) -> Int {
        var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 1_442_695_041)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Int(h % 1000)
    }
}
