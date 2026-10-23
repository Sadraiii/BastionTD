import CoreGraphics

/// The enemy route as a polyline through waypoint centers, measured in tiles.
struct PathGeometry {
    let points: [CGPoint]
    let totalLength: CGFloat
    private let cumulative: [CGFloat]

    init(waypoints: [GridPoint]) {
        precondition(waypoints.count >= 2, "A path needs at least two waypoints")
        let points = waypoints.map(\.center)
        var cumulative: [CGFloat] = [0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + points[i].distance(to: points[i - 1]))
        }
        self.points = points
        self.cumulative = cumulative
        self.totalLength = cumulative[cumulative.count - 1]
    }

    /// Index of the segment containing `distance`.
    private func segment(containing distance: CGFloat) -> Int {
        var i = 0
        while i < points.count - 2 && cumulative[i + 1] <= distance { i += 1 }
        return i
    }

    func point(at distance: CGFloat) -> CGPoint {
        let d = max(0, min(distance, totalLength))
        let i = segment(containing: d)
        let length = cumulative[i + 1] - cumulative[i]
        let t = length > 0 ? (d - cumulative[i]) / length : 0
        return points[i].lerp(to: points[i + 1], t)
    }

    /// Unit direction of travel at `distance`.
    func direction(at distance: CGFloat) -> CGPoint {
        let i = segment(containing: max(0, min(distance, totalLength)))
        return (points[i + 1] - points[i]).normalized
    }

    /// How far along the route a cell's center lies, or nil if the route doesn't pass it.
    func distance(to cell: GridPoint) -> CGFloat? {
        for i in 0..<points.count - 1 where cell.center.distance(toSegment: points[i], points[i + 1]) < 0.01 {
            return cumulative[i] + points[i].distance(to: cell.center)
        }
        return nil
    }

    /// Evenly spaced points along the route, skipping the off-board entry.
    func samples(spacing: CGFloat, from start: CGFloat = 0.5) -> [CGPoint] {
        stride(from: start, through: totalLength, by: spacing).map { point(at: $0) }
    }
}
