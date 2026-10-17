// Draws the Bastion TD app icon as 32x32 pixel art, scaled to 1024x1024.
// Usage: swift Tools/make_app_icon.swift TowerDefense/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 32
var pixels = [UInt32?](repeating: nil, count: size * size)

func set(_ x: Int, _ y: Int, _ c: UInt32) {
    guard x >= 0, y >= 0, x < size, y < size else { return }
    pixels[y * size + x] = c
}
func get(_ x: Int, _ y: Int) -> UInt32? {
    guard x >= 0, y >= 0, x < size, y < size else { return nil }
    return pixels[y * size + x]
}
func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) {
    for yy in y..<(y + h) { for xx in x..<(x + w) { set(xx, yy, c) } }
}

let ink: UInt32 = 0x181425, navy: UInt32 = 0x262B44, slate: UInt32 = 0x3A4466, steel: UInt32 = 0x5A6988
let silver: UInt32 = 0x8B9BB4, mist: UInt32 = 0xC0CBDC, red: UInt32 = 0xE43B44, crimson: UInt32 = 0xA22633
let amber: UInt32 = 0xFEAE34, yellow: UInt32 = 0xFEE761, lime: UInt32 = 0x63C74D, green: UInt32 = 0x3E8948
let forest: UInt32 = 0x265C42, bark: UInt32 = 0x733E39, cyan: UInt32 = 0x2CE8F5, blue: UInt32 = 0x0099DB
let white: UInt32 = 0xFFFFFF, purple: UInt32 = 0x68386C

// Sky with banded dithering and stars.
var background = [UInt32](repeating: navy, count: size * size)
for y in 0..<size {
    for x in 0..<size {
        let band = y < 8 ? ink : (y < 12 && (x + y) % 2 == 0 ? ink : (y > 18 && (x + y) % 2 == 0 ? purple : navy))
        background[y * size + x] = band
    }
}
for (x, y) in [(3, 3), (27, 5), (6, 10), (25, 12), (29, 2), (2, 15)] { background[y * size + x] = yellow }
for (x, y) in [(13, 2), (22, 9)] { background[y * size + x] = white }

// Hill.
for y in 22..<size {
    for x in 0..<size {
        let dx = Double(x) - 15.5, dy = Double(y) - 34
        if dx * dx / 400 + dy * dy / 144 <= 1 {
            set(x, y, (x * 7 + y * 3) % 11 == 0 ? lime : ((x + y) % 9 == 0 ? forest : green))
        }
    }
}

// Tower body.
rect(9, 10, 14, 15, steel)
for y in 10..<25 { set(9, y, silver); set(22, y, slate) }
for y in stride(from: 12, to: 25, by: 3) {
    for x in 10..<22 where (x + (y / 3) * 2) % 4 != 0 { set(x, y, slate) }
}
// Battlements.
rect(8, 8, 16, 2, steel)
for x in 8..<24 { set(x, 8, silver) }
for x in [8, 9, 12, 13, 18, 19, 22, 23] { rect(x, 6, 1, 2, steel); set(x, 6, silver) }
// Flag.
rect(16, 1, 1, 7, slate)
rect(17, 1, 5, 3, red)
rect(17, 3, 5, 1, crimson)
set(21, 2, crimson)
// Glowing window and door.
rect(15, 13, 2, 3, amber)
set(15, 13, yellow)
rect(14, 20, 4, 5, bark)
rect(15, 20, 2, 1, ink)
// Crystal on the hill.
let crystal: [(Int, Int, UInt32)] = [
    (26, 21, white), (25, 22, cyan), (26, 22, white), (27, 22, blue), (24, 23, cyan), (25, 23, cyan),
    (26, 23, blue), (27, 23, blue), (28, 23, blue), (25, 24, cyan), (26, 24, blue), (27, 24, blue), (26, 25, blue),
]
for (x, y, c) in crystal { set(x, y, c) }
// Tiny enemy approaching.
rect(3, 25, 3, 2, red)
set(4, 25, white)
set(3, 27, crimson); set(5, 27, crimson)

// Outline every shape in ink.
let shapes = pixels
for y in 0..<size {
    for x in 0..<size where shapes[y * size + x] == nil {
        let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
        if neighbors.contains(where: { $0.0 >= 0 && $0.1 >= 0 && $0.0 < size && $0.1 < size && shapes[$0.1 * size + $0.0] != nil }) {
            set(x, y, ink)
        }
    }
}

let scale = 32
let out = size * scale
var bytes = [UInt8](repeating: 255, count: out * out * 4)
for y in 0..<out {
    for x in 0..<out {
        let px = x / scale, py = y / scale
        let c = get(px, py) ?? background[py * size + px]
        let i = (y * out + x) * 4
        bytes[i] = UInt8((c >> 16) & 0xFF)
        bytes[i + 1] = UInt8((c >> 8) & 0xFF)
        bytes[i + 2] = UInt8(c & 0xFF)
        bytes[i + 3] = 255
    }
}

let provider = CGDataProvider(data: Data(bytes) as CFData)!
let image = CGImage(
    width: out, height: out, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: out * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
)!
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("Wrote \(path)")
