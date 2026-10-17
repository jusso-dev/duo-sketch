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
}
