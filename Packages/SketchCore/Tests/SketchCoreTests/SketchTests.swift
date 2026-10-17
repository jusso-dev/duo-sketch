import XCTest
@testable import SketchCore

final class SketchTests: XCTestCase {
    let size = CanvasSize(width: 200, height: 100)

    func testRightAndUpDirections() {
        var s = Sketch()
        s.movePen(dx: 20, dy: 0, in: size)
        XCTAssertEqual(s.pen, Point(x: 0.6, y: 0.5))
        s.movePen(dx: 0, dy: 10, in: size)
        XCTAssertEqual(s.pen.y, 0.4, accuracy: 1e-9) // up means smaller y
        XCTAssertFalse(s.isEmpty)
    }

    func testClampsAtAllEdgesAndBumpsOnce() {
        var s = Sketch()
        let first = s.movePen(dx: 500, dy: 0, in: size)
        XCTAssertTrue(first.bumpedEdge)
        XCTAssertEqual(s.pen.x, 1)
        let again = s.movePen(dx: 10, dy: 0, in: size)
        XCTAssertFalse(again.moved)
        XCTAssertFalse(again.bumpedEdge)
        let count = s.pointCount
        s.movePen(dx: 5, dy: 0, in: size)
        XCTAssertEqual(s.pointCount, count, "no segments past the edge")

        s.movePen(dx: -1000, dy: 0, in: size); XCTAssertEqual(s.pen.x, 0)
        s.movePen(dx: 0, dy: 1000, in: size); XCTAssertEqual(s.pen.y, 0)
        s.movePen(dx: 0, dy: -1000, in: size); XCTAssertEqual(s.pen.y, 1)
    }

    func testLeavingEdgeThenReturningBumpsAgain() {
        var s = Sketch()
        XCTAssertTrue(s.movePen(dx: 500, dy: 0, in: size).bumpedEdge)
        XCTAssertFalse(s.movePen(dx: -10, dy: 0, in: size).bumpedEdge)
        XCTAssertTrue(s.movePen(dx: 50, dy: 0, in: size).bumpedEdge)
    }

    func testStraightRunsAreMerged() {
        var s = Sketch()
        for _ in 0..<100 { s.movePen(dx: 0.5, dy: 0, in: size) }
        XCTAssertEqual(s.pointCount, 2)
        s.movePen(dx: 0, dy: 1, in: size)
        XCTAssertEqual(s.pointCount, 3)
        s.movePen(dx: 0, dy: -2, in: size) // reverse is not merged
        XCTAssertEqual(s.pointCount, 4)
    }

    func testClearKeepsPen() {
        var s = Sketch()
        s.movePen(dx: 30, dy: 10, in: size)
        let pen = s.pen
        s.clear()
        XCTAssertTrue(s.isEmpty)
        XCTAssertEqual(s.pen, pen)
        s.movePen(dx: 1, dy: 0, in: size)
        XCTAssertEqual(s.strokes.first?.points.first, pen)
    }

    func testFadeThenDrawStartsFreshStroke() {
        var s = Sketch()
        s.movePen(dx: 10, dy: 0, in: size)
        XCTAssertFalse(s.fade(by: 1.0 / 3.0))
        s.movePen(dx: 10, dy: 0, in: size)
        XCTAssertEqual(s.strokes.count, 2)
        XCTAssertEqual(s.strokes[0].opacity, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(s.strokes[1].opacity, 1)
    }

    func testNormalisedPointsSurviveResize() {
        var s = Sketch()
        s.movePen(dx: 50, dy: 0, in: CanvasSize(width: 100, height: 100))
        XCTAssertEqual(s.pen.x, 1)
        // Same drawing rendered on a bigger canvas keeps proportions.
        let svg = SVGExporter.svg(s, width: 400, height: 400, background: nil)
        XCTAssertTrue(svg.contains("200,200 400,200"))
    }

    func testLargeDrawingStaysCompact() {
        var s = Sketch()
        // 20,000 tiny moves along a staircase still merge runs.
        for i in 0..<20_000 {
            s.movePen(dx: i % 200 < 100 ? 0.01 : 0, dy: i % 200 < 100 ? 0 : 0.01, in: size)
        }
        XCTAssertLessThanOrEqual(s.pointCount, 202)
    }

    func testCodableRoundTrip() throws {
        var s = DemoDrawings.spiral()
        s.fade(by: 0.25)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(Sketch.self, from: data), s)
    }

    // MARK: Stroke growth (issue #21, finding 1)

    func testTinyMovesAreMergedIntoSpacedPoints() {
        var s = Sketch(pen: Point(x: 0.1, y: 0.9))
        let canvas = CanvasSize(width: 400, height: 400)
        for i in 0..<2_000 {
            // 0.1 pt steps in a staircase: never a straight continuation.
            if i.isMultiple(of: 2) { s.movePen(dx: 0.1, dy: 0, in: canvas) } else { s.movePen(dx: 0, dy: 0.1, in: canvas) }
        }
        // About 141 pt of diagonal travel at 0.5 pt spacing.
        XCTAssertLessThan(s.pointCount, 400)
        XCTAssertGreaterThan(s.pointCount, 100)
        XCTAssertEqual(s.strokes.last?.points.last, s.pen, "the stroke still ends at the pen")
        let points = s.strokes[0].points
        for i in 1..<(points.count - 1) {
            XCTAssertGreaterThanOrEqual(Sketch.distance(points[i - 1], points[i], in: canvas), Sketch.minimumSpacing - 1e-9)
        }
    }

    func testPointCountIsCappedOnLongDrawings() {
        var s = Sketch(pen: Point(x: 0.05, y: 0.95))
        let canvas = CanvasSize(width: 400, height: 400)
        var direction = 1.0
        for i in 0..<60_000 {
            // A 1 pt zigzag that turns back every 300 pt so it stays on the canvas.
            if i.isMultiple(of: 600) { direction = -direction }
            if i.isMultiple(of: 2) { s.movePen(dx: direction, dy: 0, in: canvas) } else { s.movePen(dx: 0, dy: (i % 4 == 1) ? 1 : -1, in: canvas) }
        }
        XCTAssertLessThanOrEqual(s.pointCount, Sketch.maximumPoints)
        XCTAssertEqual(s.strokes.last?.points.last, s.pen)
        XCTAssertFalse(s.isEmpty)
    }

    func testThinningKeepsEndsAndDropsClosePoints() {
        let line = [
            Point(x: 0, y: 0), Point(x: 0.001, y: 0), Point(x: 0.01, y: 0),
            Point(x: 0.011, y: 0), Point(x: 0.0115, y: 0)
        ]
        let out = Sketch.thinned(line, minimumDistance: 0.005, in: CanvasSize(width: 1, height: 1))
        XCTAssertEqual(out, [Point(x: 0, y: 0), Point(x: 0.01, y: 0), Point(x: 0.0115, y: 0)])
    }

    func testThinningLeavesShortStrokesAlone() {
        let two = [Point(x: 0, y: 0), Point(x: 0.0001, y: 0)]
        XCTAssertEqual(Sketch.thinned(two, minimumDistance: 0.5, in: CanvasSize(width: 1, height: 1)), two)
    }

    // MARK: Canvas shape changes (SK-3)

    /// Width and height on screen, in canvas points, of everything drawn.
    func drawnExtent(_ s: Sketch, on canvas: CanvasSize) -> (Double, Double) {
        let f = s.frame(in: canvas)
        let pts = s.strokes.flatMap(\.points).map { f.position(of: $0) }
        let xs = pts.map(\.x), ys = pts.map(\.y)
        return (xs.max()! - xs.min()!, ys.max()! - ys.min()!)
    }

    func testSquareStaysSquareWhenTheCanvasChangesShape() {
        var s = Sketch()
        let wide = CanvasSize(width: 800, height: 400)
        s.movePen(dx: 100, dy: 0, in: wide)
        s.movePen(dx: 0, dy: 100, in: wide)
        s.movePen(dx: -100, dy: 0, in: wide)
        s.movePen(dx: 0, dy: -100, in: wide)
        let (w0, h0) = drawnExtent(s, on: wide)
        XCTAssertEqual(w0, 100, accuracy: 1e-6)
        XCTAssertEqual(h0, 100, accuracy: 1e-6)
        // Shown on a tall canvas it used to come out 45 x 125 pt.
        let (w, h) = drawnExtent(s, on: CanvasSize(width: 360, height: 500))
        XCTAssertEqual(w, 45, accuracy: 1e-6)
        XCTAssertEqual(h, 45, accuracy: 1e-6)
    }

    func testFrameIsLetterboxedAndCentred() {
        var s = Sketch()
        s.movePen(dx: 10, dy: 0, in: CanvasSize(width: 800, height: 400))
        let f = s.frame(in: CanvasSize(width: 360, height: 500))
        XCTAssertEqual(f, DrawingFrame(x: 0, y: 160, width: 360, height: 180))
    }

    func testPenSpeedFollowsTheFrameAfterAShapeChange() {
        var s = Sketch()
        s.movePen(dx: 10, dy: 0, in: CanvasSize(width: 800, height: 400))
        let x = s.pen.x
        // 36 pt on a frame 360 pt wide is a tenth of the width.
        s.movePen(dx: 36, dy: 0, in: CanvasSize(width: 360, height: 500))
        XCTAssertEqual(s.pen.x - x, 0.1, accuracy: 1e-9)
    }

    func testClearingForgetsTheShape() {
        var s = Sketch()
        s.movePen(dx: 10, dy: 0, in: CanvasSize(width: 800, height: 400))
        XCTAssertEqual(s.aspectRatio, 2)
        s.clear()
        XCTAssertNil(s.aspectRatio)
        s.movePen(dx: 10, dy: 0, in: CanvasSize(width: 300, height: 600))
        XCTAssertEqual(s.aspectRatio, 0.5)
    }

    func testFadingToEmptyForgetsTheShape() {
        var s = Sketch()
        s.movePen(dx: 10, dy: 0, in: CanvasSize(width: 800, height: 400))
        XCTAssertTrue(s.fade(by: 1))
        XCTAssertNil(s.aspectRatio)
    }

    func testOldSketchJSONWithoutAspectStillDecodes() throws {
        let json = #"{"pen":{"x":0.5,"y":0.5},"strokes":[],"touchingEdge":false}"#
        let s = try JSONDecoder().decode(Sketch.self, from: Data(json.utf8))
        XCTAssertNil(s.aspectRatio)
    }

    // MARK: Thinning (SK-5)

    func testThinningMeasuresInCanvasPoints() {
        // On a 800 x 100 canvas, 0.01 across is 8 pt but 0.01 down is only 1 pt.
        let canvas = CanvasSize(width: 800, height: 100)
        let across = [Point(x: 0, y: 0), Point(x: 0.01, y: 0), Point(x: 0.02, y: 0), Point(x: 0.03, y: 0)]
        let down = [Point(x: 0, y: 0), Point(x: 0, y: 0.01), Point(x: 0, y: 0.02), Point(x: 0, y: 0.03)]
        XCTAssertEqual(Sketch.thinned(across, minimumDistance: 4, in: canvas).count, 4, "8 pt apart: all kept")
        XCTAssertEqual(Sketch.thinned(down, minimumDistance: 4, in: canvas).count, 2, "1 pt apart: only the ends")
    }

    func testCapLeavesTheNewestPointsAlone() {
        var s = Sketch(pen: Point(x: 0.05, y: 0.95))
        let canvas = CanvasSize(width: 400, height: 400)
        var direction = 1.0
        for i in 0..<19_000 {
            if i.isMultiple(of: 600) { direction = -direction }
            if i.isMultiple(of: 2) { s.movePen(dx: direction, dy: 0, in: canvas) } else { s.movePen(dx: 0, dy: (i % 4 == 1) ? 1 : -1, in: canvas) }
        }
        XCTAssertGreaterThan(s.pointCount, 15_000, "below the cap so far")
        let newest = Array(s.strokes[0].points.suffix(Sketch.newestPointsKept))
        let oldest = s.strokes[0].points.first
        s.simplify(toAtMost: 10_000, in: canvas)
        XCTAssertLessThanOrEqual(s.pointCount, 10_000)
        XCTAssertEqual(Array(s.strokes[0].points.suffix(Sketch.newestPointsKept)), newest, "newest points untouched")
        XCTAssertEqual(s.strokes[0].points.first, oldest, "stroke start kept")
        XCTAssertEqual(s.strokes[0].points.last, s.pen)
    }
}
