/// A continuous line made while the ink was at one strength.
public struct Stroke: Sendable, Equatable, Codable {
    public var points: [Point]
    /// 1 is full ink. Shaking fades existing strokes.
    public var opacity: Double

    public init(points: [Point], opacity: Double = 1) {
        self.points = points
        self.opacity = opacity
    }
}

/// What happened when the pen was asked to move.
public struct PenMove: Sendable, Equatable {
    /// The pen actually moved.
    public var moved: Bool
    /// The pen just came into contact with an edge (fires once per contact).
    public var bumpedEdge: Bool
}

/// The drawing: one pen and the lines it has left behind.
public struct Sketch: Sendable, Equatable, Codable {
    public private(set) var pen: Point
    public private(set) var strokes: [Stroke]
    private var touchingEdge = false

    public init(pen: Point = .centre) {
        self.pen = pen
        self.strokes = []
    }

    /// True when nothing has been drawn.
    public var isEmpty: Bool {
        !strokes.contains { $0.points.count > 1 }
    }

    public var pointCount: Int {
        strokes.reduce(0) { $0 + $1.points.count }
    }

    /// Moves the pen by `dx`, `dy` canvas points on a canvas of `size`.
    /// Positive `dy` moves the pen up. The pen is clamped to the canvas.
    @discardableResult
    public mutating func movePen(dx: Double, dy: Double, in size: CanvasSize) -> PenMove {
        guard dx.isFinite, dy.isFinite else { return PenMove(moved: false, bumpedEdge: false) }
        let rawX = pen.x + dx / size.width
        let rawY = pen.y - dy / size.height
        let next = Point(x: min(max(rawX, 0), 1), y: min(max(rawY, 0), 1))
        let clamped = next.x != rawX || next.y != rawY
        let bumped = clamped && !touchingEdge
        touchingEdge = clamped

        guard next != pen else { return PenMove(moved: false, bumpedEdge: bumped) }
        append(next, in: size)
        pen = next
        return PenMove(moved: true, bumpedEdge: bumped)
    }

    /// Removes every line. The pen stays where it is.
    public mutating func clear() {
        strokes = []
    }

    /// Fades every existing line by `amount` (0 to 1). Lines that fade out are removed.
    /// Returns true when the drawing is now empty.
    @discardableResult
    public mutating func fade(by amount: Double) -> Bool {
        let amount = min(max(amount, 0), 1)
        strokes = strokes.compactMap { stroke in
            var s = stroke
            s.opacity -= amount
            return s.opacity > 0.01 ? s : nil
        }
        return isEmpty
    }

    /// Points closer together than this (in canvas points) are merged: the tip of
    /// the stroke follows the pen until it is at least this far from the point
    /// before it. Below half a point the difference can't be seen.
    public static let minimumSpacing = 0.5

    /// Most points a sketch keeps. Past this, every stroke is simplified
    /// (keeping its ends) until the sketch is back to `simplifiedTarget`.
    public static let maximumPoints = 20_000
    static let simplifiedTarget = 15_000

    /// Adds `next` to the current stroke, changing the stroke's point array in
    /// place so a move costs amortised O(1) rather than a copy of the stroke.
    private mutating func append(_ next: Point, in size: CanvasSize) {
        guard let last = strokes.indices.last, strokes[last].opacity >= 1 else {
            strokes.append(Stroke(points: [pen, next]))
            return
        }
        let n = strokes[last].points.count
        if n >= 2 {
            let anchor = strokes[last].points[n - 2]
            let tip = strokes[last].points[n - 1]
            if Sketch.isStraightContinuation(anchor, tip, next)
                || Sketch.distance(anchor, next, in: size) < Sketch.minimumSpacing {
                strokes[last].points[n - 1] = next
                return
            }
        }
        strokes[last].points.append(next)
        if pointCount > Sketch.maximumPoints {
            simplify(toAtMost: Sketch.simplifiedTarget)
        }
    }

    /// Distance between two normalised points, in canvas points.
    static func distance(_ a: Point, _ b: Point, in size: CanvasSize) -> Double {
        let dx = (b.x - a.x) * size.width
        let dy = (b.y - a.y) * size.height
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Thins every stroke, doubling the spacing between kept points until the
    /// sketch has at most `target` points. Each pass is O(n) and roughly halves
    /// the density, so detail fades gradually instead of collapsing. Stroke ends
    /// are always kept, so the pen stays where it is. Runs rarely: only after
    /// `maximumPoints`, then not again until thousands more points are drawn.
    mutating func simplify(toAtMost target: Int) {
        var spacing = 0.002 // normalised, about 0.8 pt on a 400 pt canvas
        while pointCount > target, spacing < 1 {
            for i in strokes.indices where strokes[i].points.count > 2 {
                strokes[i].points = Sketch.thinned(strokes[i].points, minimumDistance: spacing)
            }
            spacing *= 2
        }
    }

    /// Keeps the first and last point, and each point in between that is at
    /// least `minimumDistance` (normalised) from the last point kept.
    static func thinned(_ points: [Point], minimumDistance: Double) -> [Point] {
        guard points.count > 2 else { return points }
        let limit = minimumDistance * minimumDistance
        var out: [Point] = [points[0]]
        out.reserveCapacity(points.count)
        for p in points[1..<(points.count - 1)] {
            let k = out[out.count - 1]
            let dx = p.x - k.x, dy = p.y - k.y
            if dx * dx + dy * dy >= limit { out.append(p) }
        }
        out.append(points[points.count - 1])
        return out
    }

    /// True when `c` carries on in the same direction as `a` to `b`.
    static func isStraightContinuation(_ a: Point, _ b: Point, _ c: Point) -> Bool {
        let abx = b.x - a.x, aby = b.y - a.y
        let bcx = c.x - b.x, bcy = c.y - b.y
        let cross = abx * bcy - aby * bcx
        let dot = abx * bcx + aby * bcy
        return abs(cross) < 1e-12 && dot > 0
    }
}
