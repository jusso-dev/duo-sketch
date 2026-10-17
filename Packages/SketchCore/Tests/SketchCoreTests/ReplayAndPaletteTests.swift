import XCTest
@testable import SketchCore

final class ReplayTimelineTests: XCTestCase {
    private let canvas = CanvasSize(width: 100, height: 100)

    func testEmptySketchReplaysAsEmpty() {
        let timeline = ReplayTimeline(Sketch())
        XCTAssertEqual(timeline.totalPoints, 0)
        for p in [0, 0.5, 1] { XCTAssertTrue(timeline.frame(at: p).isEmpty) }
    }

    func testOneStrokeRevealsInOrder() {
        var sketch = Sketch(pen: Point(x: 0, y: 0.5))
        // A zigzag so every move keeps its own point: 9 points in one stroke.
        for i in 0..<8 { sketch.movePen(dx: 10, dy: i % 2 == 0 ? 10 : -10, in: canvas) }
        let timeline = ReplayTimeline(sketch)
        XCTAssertEqual(timeline.totalPoints, 9)

        let start = timeline.frame(at: 0)
        XCTAssertTrue(start.isEmpty)
        XCTAssertEqual(start.pen, Point(x: 0, y: 0.5), "the pen waits where the drawing starts")

        let half = timeline.frame(at: 0.5)
        XCTAssertEqual(half.strokes.count, 1)
        XCTAssertEqual(half.strokes[0].points, Array(sketch.strokes[0].points.prefix(4)))
        XCTAssertEqual(half.pen, sketch.strokes[0].points[3])
        XCTAssertEqual(half.aspectRatio, sketch.aspectRatio)

        XCTAssertEqual(timeline.frame(at: 1), sketch)
    }

    func testManyStrokesKeepTheirOpacity() {
        var sketch = Sketch()
        sketch.movePen(dx: 20, dy: 0, in: canvas)
        sketch.movePen(dx: 0, dy: 20, in: canvas)
        sketch.fade(by: 0.5)
        sketch.movePen(dx: -20, dy: 0, in: canvas)
        sketch.movePen(dx: 0, dy: -10, in: canvas)
        XCTAssertEqual(sketch.strokes.count, 2)
        let timeline = ReplayTimeline(sketch)
        XCTAssertEqual(timeline.totalPoints, sketch.pointCount)

        let firstOnly = timeline.frame(at: Double(sketch.strokes[0].points.count) / Double(timeline.totalPoints))
        XCTAssertEqual(firstOnly.strokes.count, 1)
        XCTAssertEqual(firstOnly.strokes[0].opacity, 0.5)

        let almost = timeline.frame(at: 0.999)
        XCTAssertEqual(almost.strokes.count, 2)
        XCTAssertEqual(almost.strokes[1].opacity, 1)
        XCTAssertEqual(timeline.frame(at: 1), sketch)
    }

    func testOutOfRangeProgressIsClamped() {
        let timeline = ReplayTimeline(DemoDrawings.spiral())
        XCTAssertTrue(timeline.frame(at: -1).isEmpty)
        XCTAssertTrue(timeline.frame(at: .nan).isEmpty)
        XCTAssertEqual(timeline.frame(at: 7), DemoDrawings.spiral())
        XCTAssertEqual(ReplayTimeline.progress(atElapsed: 4), 0.5)
        XCTAssertEqual(ReplayTimeline.progress(atElapsed: -1), 0)
        XCTAssertEqual(ReplayTimeline.progress(atElapsed: 100), 1)
        XCTAssertEqual(ReplayTimeline.progress(atElapsed: .nan), 1)
    }

    func testProgressOnlyEverAddsInk() {
        let timeline = ReplayTimeline(DemoDrawings.hills())
        var last = 0
        for step in 0...100 {
            let count = timeline.frame(at: Double(step) / 100).pointCount
            XCTAssertGreaterThanOrEqual(count, last)
            last = count
        }
        XCTAssertEqual(last, DemoDrawings.hills().pointCount)
    }
}

final class DialGearTests: XCTestCase {
    func testFineGearMovesAQuarterWithTheSameDetents() {
        var coarse = Dial()
        var fine = Dial()
        fine.gear = .fine
        let a = coarse.rotate(by: 90)
        let b = fine.rotate(by: 90)
        XCTAssertEqual(b.distance, a.distance / 4, accuracy: 1e-9)
        XCTAssertEqual(b.detentsCrossed, a.detentsCrossed)
        XCTAssertEqual(DialGear.coarse.toggled, .fine)
        XCTAssertEqual(DialGear.fine.toggled, .coarse)
    }
}

final class FramePaletteTests: XCTestCase {
    func testEveryPaletteMeetsContrastRules() {
        for p in FramePalette.all {
            XCTAssertGreaterThanOrEqual(FramePalette.contrast(p.ink, p.surface), 4.5, "\(p.name) ink on surface")
            XCTAssertGreaterThanOrEqual(FramePalette.contrast(p.label, p.body), 4.5, "\(p.name) wordmark on body")
            XCTAssertGreaterThanOrEqual(FramePalette.contrast(p.label, p.bodyShade), 4.5, "\(p.name) wordmark on shade")
            // Dial marks sit on a gradient; check both ends.
            XCTAssertGreaterThanOrEqual(FramePalette.contrast(p.dialMark, p.dial), 3, "\(p.name) dial mark")
            XCTAssertGreaterThanOrEqual(FramePalette.contrast(p.dialMark, p.dialShade), 3, "\(p.name) dial mark on shade")
        }
    }

    func testNoPaletteUsesRed() {
        XCTAssertTrue(FramePalette.isRed("#C0392B"))
        XCTAssertTrue(FramePalette.isRed("#FF0000"))
        XCTAssertFalse(FramePalette.isRed("#2B2B2B"), "grey has no hue")
        for p in FramePalette.all {
            for colour in p.colours { XCTAssertFalse(FramePalette.isRed(colour), "\(p.name) \(colour)") }
        }
    }

    func testLookupAndParsing() {
        XCTAssertEqual(FramePalette.palette(.ocean), .ocean)
        XCTAssertEqual(Set(FramePalette.all.map(\.id)), Set(FramePalette.ID.allCases))
        XCTAssertEqual(FramePalette.contrast("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        XCTAssertEqual(FramePalette.luminance("nonsense"), 0)
    }
}
