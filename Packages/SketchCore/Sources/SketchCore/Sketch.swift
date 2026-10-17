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
        append(next)
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

    private mutating func append(_ next: Point) {
        if let last = strokes.indices.last, strokes[last].opacity >= 1 {
            var points = strokes[last].points
            if points.count >= 2, Sketch.isStraightContinuation(points[points.count - 2], points[points.count - 1], next) {
                points[points.count - 1] = next
            } else {
                points.append(next)
            }
            strokes[last].points = points
        } else {
            strokes.append(Stroke(points: [pen, next]))
        }
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
