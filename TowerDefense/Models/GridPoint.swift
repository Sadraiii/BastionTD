import CoreGraphics

/// A cell on the battlefield grid. Columns grow to the right, rows grow downward.
struct GridPoint: Hashable, Codable, CustomStringConvertible {
    var col: Int
    var row: Int

    init(_ col: Int, _ row: Int) {
        self.col = col
        self.row = row
    }

    /// Center of the cell in logical board units (1 unit = 1 tile, y grows downward).
    var center: CGPoint { CGPoint(x: CGFloat(col) + 0.5, y: CGFloat(row) + 0.5) }

    var description: String { "(\(col), \(row))" }
}

// MARK: - Vector math in logical board space

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }

    var length: CGFloat { hypot(x, y) }

    var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : .zero
    }

    /// The vector rotated by 90 degrees.
    var perpendicular: CGPoint { CGPoint(x: -y, y: x) }

    func distance(to other: CGPoint) -> CGFloat { (self - other).length }

    func lerp(to other: CGPoint, _ t: CGFloat) -> CGPoint { self + (other - self) * t }

    /// Shortest distance from this point to the segment `a`-`b`.
    func distance(toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = b - a
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        guard lengthSquared > 0 else { return distance(to: a) }
        let t = max(0, min(1, ((x - a.x) * ab.x + (y - a.y) * ab.y) / lengthSquared))
        return distance(to: a + ab * t)
    }
}
