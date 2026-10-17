import SwiftUI

/// Colors and fonts for the SwiftUI interface, matched to the pixel palette.
enum Theme {
    static let background = Color(pixel: Pal.ink)
    static let panel = Color(pixel: Pal.navy)
    static let panelLight = Color(pixel: Pal.slate)
    static let border = Color(pixel: Pal.ink)
    static let text = Color(pixel: Pal.white)
    static let secondaryText = Color(pixel: Pal.silver)
    static let gold = Color(pixel: Pal.yellow)
    static let danger = Color(pixel: Pal.red)
    static let accent = Color(pixel: Pal.lime)
    static let highlight = Color(pixel: Pal.amber)

    /// Monospaced body text; the pixel font is reserved for headings and numbers.
    static func body(_ size: CGFloat = 13, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func tower(_ kind: TowerKind) -> Color { Color(pixel: Pal.tower(kind)) }
}

extension Color {
    init(pixel: PixelColor) {
        self.init(.sRGB, red: Double(pixel.r) / 255, green: Double(pixel.g) / 255, blue: Double(pixel.b) / 255,
                  opacity: Double(pixel.a) / 255)
    }
}

// MARK: - Pixel font text

/// Text drawn with the game's 5x7 bitmap font.
struct PixelText: View {
    let text: String
    var pixel: CGFloat = 2
    var color: Color = Theme.text
    var shadow: Color? = Theme.border

    init(_ text: String, pixel: CGFloat = 2, color: Color = Theme.text, shadow: Color? = Theme.border) {
        self.text = text
        self.pixel = pixel
        self.color = color
        self.shadow = shadow
    }

    var body: some View {
        let width = CGFloat(PixelFont.width(of: text)) * pixel
        let height = CGFloat(PixelFont.glyphHeight) * pixel
        let offset = shadow == nil ? 0 : pixel
        Canvas { context, _ in
            var path = Path()
            PixelFont.layout(text) { x, y in
                path.addRect(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel))
            }
            if let shadow {
                context.fill(path.offsetBy(dx: offset, dy: offset), with: .color(shadow))
            }
            context.fill(path, with: .color(color))
        }
        .frame(width: width + offset, height: height + offset)
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

// MARK: - Pixel images

/// A pixel-art image scaled by whole multiples without smoothing.
struct PixelImage: View {
    let image: UIImage
    var scale: CGFloat = 2

    var body: some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .frame(width: image.size.width * scale, height: image.size.height * scale)
    }
}

struct PixelIcon: View {
    let icon: SpriteMaps.Icon
    var scale: CGFloat = 2
    var outlined = true

    var body: some View {
        PixelImage(image: Art.icon(icon, outlined: outlined), scale: scale)
            .accessibilityHidden(true)
    }
}

// MARK: - Frames and panels

/// A rectangle with stepped (pixelated) corners.
struct PixelFrame: InsettableShape {
    var step: CGFloat = 3
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let s = step
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 2 * s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.minY + s))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> PixelFrame {
        PixelFrame(step: step, inset: inset + amount)
    }
}

/// Classic pixel panel: dark outline, filled body, light top bevel and a hard drop shadow.
struct PixelPanelBackground: View {
    var fill: Color = Theme.panel
    var bevel: Color = Theme.panelLight
    var step: CGFloat = 3
    var shadow = true

    var body: some View {
        ZStack {
            if shadow {
                PixelFrame(step: step).fill(Color.black.opacity(0.45)).offset(y: step)
            }
            PixelFrame(step: step).fill(Theme.border)
            PixelFrame(step: step).inset(by: step).fill(bevel)
            PixelFrame(step: step).inset(by: step).fill(fill).padding(.top, step)
        }
    }
}

extension View {
    func pixelPanel(fill: Color = Theme.panel, bevel: Color = Theme.panelLight, step: CGFloat = 3, shadow: Bool = true) -> some View {
        background(PixelPanelBackground(fill: fill, bevel: bevel, step: step, shadow: shadow))
    }
}

/// Chunky pixel button that presses down into its shadow.
struct PixelButtonStyle: ButtonStyle {
    var color: Color = Color(pixel: Pal.green)
    var highlight: Color = Color(pixel: Pal.lime)
    var shade: Color = Color(pixel: Pal.forest)
    var step: CGFloat = 3
    var minHeight: CGFloat = 44

    static let primary = PixelButtonStyle()
    static let gold = PixelButtonStyle(color: Color(pixel: Pal.amber), highlight: Color(pixel: Pal.yellow), shade: Color(pixel: Pal.rust))
    static let danger = PixelButtonStyle(color: Color(pixel: Pal.red), highlight: Color(pixel: Pal.pink), shade: Color(pixel: Pal.crimson))
    static let neutral = PixelButtonStyle(color: Color(pixel: Pal.steel), highlight: Color(pixel: Pal.silver), shade: Color(pixel: Pal.slate))
    static let blue = PixelButtonStyle(color: Color(pixel: Pal.blue), highlight: Color(pixel: Pal.cyan), shade: Color(pixel: Pal.ocean))

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: minHeight)
            .background {
                ZStack(alignment: .top) {
                    PixelFrame(step: step).fill(Theme.border).offset(y: pressed ? 0 : step)
                    PixelFrame(step: step).fill(Theme.border)
                    PixelFrame(step: step).inset(by: step).fill(shade)
                    PixelFrame(step: step).inset(by: step).fill(color).padding(.bottom, step)
                    Rectangle().fill(highlight)
                        .frame(height: step)
                        .padding(.top, step)
                        .padding(.horizontal, step * 3)
                }
            }
            .offset(y: pressed ? step : 0)
            .contentShape(Rectangle())
    }
}

/// A row of stars earned on a map.
struct StarRow: View {
    let earned: Int
    var scale: CGFloat = 2

    var body: some View {
        HStack(spacing: scale * 2) {
            ForEach(0..<3, id: \.self) { index in
                PixelImage(image: index < earned ? Art.icon(.star) : Art.starEmpty, scale: scale)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(earned) of 3 stars")
    }
}

/// Gold amount with the coin icon.
struct GoldLabel: View {
    let amount: Int
    var pixel: CGFloat = 2
    var color: Color = Theme.gold

    var body: some View {
        HStack(spacing: pixel * 2) {
            PixelIcon(icon: .coin, scale: pixel)
            PixelText("\(amount)", pixel: pixel, color: color)
        }
        .accessibilityElement()
        .accessibilityLabel("\(amount) gold")
    }
}

/// Small helper so every button gives the same audible tap.
@MainActor func playTap() { SoundEngine.shared.play(.tap) }
