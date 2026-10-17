import CoreGraphics

/// Maps between the engine's logical board space and the scene.
///
/// The logical board is always landscape (columns x rows, y down). In a portrait
/// view the board is shown rotated 90 degrees clockwise, so enemies enter from the
/// top. Inside the scene, everything lives in a "world" node measured in art pixels
/// (16 per tile, y up) and scaled by `pixelSize`, an integer number of device pixels,
/// so pixel art stays perfectly crisp.
struct BoardLayout: Equatable {
    static let tilePixels: CGFloat = 16

    let columns: Int
    let rows: Int
    let rotated: Bool
    /// Points per art pixel.
    let pixelSize: CGFloat
    /// Scene position of the board's bottom-left corner.
    let origin: CGPoint

    init(columns: Int, rows: Int, sceneSize: CGSize, screenScale: CGFloat) {
        self.columns = columns
        self.rows = rows
        rotated = sceneSize.height > sceneSize.width
        let displayColumns = CGFloat(rotated ? rows : columns)
        let displayRows = CGFloat(rotated ? columns : rows)
        let margin: CGFloat = 4
        let maxTile = min((sceneSize.width - margin * 2) / displayColumns, (sceneSize.height - margin * 2) / displayRows)
        let scale = max(1, screenScale)
        let devicePixelsPerArtPixel = max(1, floor(maxTile * scale / Self.tilePixels))
        pixelSize = devicePixelsPerArtPixel / scale
        let boardWidth = displayColumns * Self.tilePixels * pixelSize
        let boardHeight = displayRows * Self.tilePixels * pixelSize
        origin = CGPoint(
            x: ((sceneSize.width - boardWidth) / 2 * scale).rounded() / scale,
            y: ((sceneSize.height - boardHeight) / 2 * scale).rounded() / scale
        )
    }

    var tileSize: CGFloat { pixelSize * Self.tilePixels }
    var displayColumns: Int { rotated ? rows : columns }
    var displayRows: Int { rotated ? columns : rows }

    /// Board size in art pixels as displayed.
    var worldSize: CGSize {
        CGSize(width: CGFloat(displayColumns) * Self.tilePixels, height: CGFloat(displayRows) * Self.tilePixels)
    }

    /// Logical point (tiles, y down) to world art pixels (y up).
    func worldPoint(_ p: CGPoint) -> CGPoint {
        let d = rotated ? CGPoint(x: CGFloat(rows) - p.y, y: p.x) : p
        return CGPoint(x: d.x * Self.tilePixels, y: (CGFloat(displayRows) - d.y) * Self.tilePixels)
    }

    /// World point snapped to whole art pixels.
    func snappedWorldPoint(_ p: CGPoint) -> CGPoint {
        let w = worldPoint(p)
        return CGPoint(x: w.x.rounded(), y: w.y.rounded())
    }

    func logicalPoint(fromWorld w: CGPoint) -> CGPoint {
        let d = CGPoint(x: w.x / Self.tilePixels, y: CGFloat(displayRows) - w.y / Self.tilePixels)
        return rotated ? CGPoint(x: d.y, y: CGFloat(rows) - d.x) : d
    }

    func cell(atWorld w: CGPoint) -> GridPoint? {
        let p = logicalPoint(fromWorld: w)
        let col = Int(floor(p.x)), row = Int(floor(p.y))
        guard (0..<columns).contains(col), (0..<rows).contains(row) else { return nil }
        return GridPoint(col, row)
    }

    /// World-space angle (radians, counter-clockwise from +x) of a logical direction.
    func worldAngle(of direction: CGPoint) -> CGFloat {
        let d = rotated ? CGPoint(x: -direction.y, y: direction.x) : direction
        return atan2(-d.y, d.x)
    }

    /// Horizontal component of a logical direction as seen on screen.
    func screenDX(of direction: CGPoint) -> CGFloat {
        rotated ? -direction.y : direction.x
    }
}
