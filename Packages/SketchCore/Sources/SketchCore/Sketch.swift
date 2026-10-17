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
    /// Width over height of the canvas the drawing was started on, or nil while
    /// the sketch is empty. Points are fractions of a frame with this shape, so
    /// the drawing keeps its proportions when the canvas changes shape.
    public private(set) var aspectRatio: Double?
    /// Bumped by every change other than drawing at the pen: clearing, fading
    /// and thinning. Renderers use it to know when settled ink must be redrawn.
    /// Not encoded.
    public private(set) var revision = 0

    private enum CodingKeys: String, CodingKey {
        case pen, strokes, touchingEdge, aspectRatio
    }

    /// Two sketches are equal when they hold the same drawing. `revision` is
    /// render bookkeeping and doesn't count.
    public static func == (a: Sketch, b: Sketch) -> Bool {
        a.pen == b.pen && a.strokes == b.strokes && a.touchingEdge == b.touchingEdge && a.aspectRatio == b.aspectRatio
    }

    public init(pen: Point = .centre) {
        self.pen = pen
        self.strokes = []
    }

    /// A sketch made of `strokes` as they are, for replay frames. The aspect
    /// ratio is the original drawing's, so a frame sits where the full drawing does.
    init(replaying strokes: [Stroke], pen: Point, aspectRatio: Double?) {
        self.pen = pen
        self.strokes = strokes
        self.aspectRatio = aspectRatio
    }

    /// True when nothing has been drawn.
    public var isEmpty: Bool {
        !strokes.contains { $0.points.count > 1 }
    }

    public var pointCount: Int {
        strokes.reduce(0) { $0 + $1.points.count }
    }

    /// Where the drawing sits on a canvas of `size`: its own aspect ratio, as
    /// large as fits, centred (letterboxed). The whole canvas while empty.
    public func frame(in size: CanvasSize) -> DrawingFrame {
        guard let aspect = aspectRatio, aspect.isFinite, aspect > 0 else {
            return DrawingFrame(x: 0, y: 0, width: size.width, height: size.height)
        }
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return DrawingFrame(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// Moves the pen by `dx`, `dy` canvas points on a canvas of `size`.
    /// Positive `dy` moves the pen up. The pen is clamped to the drawing's frame.
    @discardableResult
    public mutating func movePen(dx: Double, dy: Double, in canvas: CanvasSize) -> PenMove {
        guard dx.isFinite, dy.isFinite else { return PenMove(moved: false, bumpedEdge: false) }
        if isEmpty { aspectRatio = canvas.width / canvas.height }
        let size = frame(in: canvas).size
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
        aspectRatio = nil
        revision &+= 1
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
        if isEmpty { aspectRatio = nil }
        revision &+= 1
        return isEmpty
    }

    /// Splits the ink for rendering. Everything except the end of the stroke
    /// being drawn is "settled": it only changes when `InkSplit` changes, so a
    /// renderer can draw it once and keep it. The live part is at most
    /// `chunk + 1` points, drawn from `settledPoints - 1` (one point of overlap)
    /// to the end of the last stroke. The last two points are always live,
    /// because drawing replaces the tip in place.
    public func inkSplit(chunk: Int = 256) -> InkSplit {
        let chunk = max(chunk, 1)
        guard let last = strokes.last, last.opacity >= 1, last.points.count >= 2 else {
            return InkSplit(revision: revision, strokeCount: strokes.count, settledPoints: strokes.last?.points.count ?? 0, hasLiveStroke: false)
        }
        let n = last.points.count
        let settled = ((n - 2) / chunk) * chunk + 1
        return InkSplit(revision: revision, strokeCount: strokes.count, settledPoints: settled, hasLiveStroke: true)
    }

    /// Points closer together than this (in canvas points) are merged: the tip of
    /// the stroke follows the pen until it is at least this far from the point
    /// before it. Below half a point the difference can't be seen.
    public static let minimumSpacing = 0.5

    /// Most points a sketch keeps. Past this, the oldest part of the drawing is
    /// thinned until the sketch is back to `simplifiedTarget`.
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
            simplify(toAtMost: Sketch.simplifiedTarget, in: size)
        }
    }

    /// Distance between two normalised points, in canvas points.
    static func distance(_ a: Point, _ b: Point, in size: CanvasSize) -> Double {
        let dx = (b.x - a.x) * size.width
        let dy = (b.y - a.y) * size.height
        return (dx * dx + dy * dy).squareRoot()
    }

    /// The newest points are never thinned, so the part being drawn keeps full detail.
    public static let newestPointsKept = 5_000

    /// Thins the oldest part of the drawing, doubling the spacing between kept
    /// points (in canvas points, so both axes are treated the same) until the
    /// sketch has at most `target` points. The newest `newestPointsKept` points
    /// and every stroke's ends are left alone. Each pass is O(n). Runs rarely:
    /// only after `maximumPoints`, then not again until thousands more points
    /// are drawn.
    mutating func simplify(toAtMost target: Int, in size: CanvasSize) {
        revision &+= 1
        var spacing = 1.0 // canvas points
        while pointCount > target, spacing < max(size.width, size.height) {
            var oldRemaining = pointCount - Sketch.newestPointsKept
            guard oldRemaining > 2 else { return }
            for i in strokes.indices {
                guard oldRemaining > 0 else { break }
                let count = strokes[i].points.count
                if count <= oldRemaining {
                    oldRemaining -= count
                    strokes[i].points = Sketch.thinned(strokes[i].points, minimumDistance: spacing, in: size)
                } else {
                    // The stroke straddles the newest points: thin only its older part.
                    let split = oldRemaining
                    oldRemaining = 0
                    guard split > 2 else { break }
                    var head = Sketch.thinned(Array(strokes[i].points[0..<split]), minimumDistance: spacing, in: size)
                    head.append(contentsOf: strokes[i].points[split...])
                    strokes[i].points = head
                }
            }
            spacing *= 2
        }
    }

    /// Keeps the first and last point, and each point in between that is at
    /// least `minimumDistance` canvas points from the last point kept.
    static func thinned(_ points: [Point], minimumDistance: Double, in size: CanvasSize) -> [Point] {
        guard points.count > 2 else { return points }
        let limit = minimumDistance * minimumDistance
        var out: [Point] = [points[0]]
        out.reserveCapacity(points.count)
        for p in points[1..<(points.count - 1)] {
            let k = out[out.count - 1]
            let dx = (p.x - k.x) * size.width, dy = (p.y - k.y) * size.height
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

/// How the ink is split between a cached, settled layer and a small live tail.
/// See `Sketch.inkSplit(chunk:)`.
public struct InkSplit: Sendable, Hashable {
    public var revision: Int
    public var strokeCount: Int
    /// Points of the last stroke that belong to the settled layer.
    public var settledPoints: Int
    /// False when the last stroke is faded ink, which never grows.
    public var hasLiveStroke: Bool
}
