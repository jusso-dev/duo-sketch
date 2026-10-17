import XCTest
@testable import SketchCore

final class DialTests: XCTestCase {
    func testFullTurnTravelsConfiguredDistance() {
        var dial = Dial(config: DialConfig(pointsPerTurn: 120, detentsPerTurn: 24))
        let step = dial.rotate(by: 360)
        XCTAssertEqual(step.distance, 120, accuracy: 1e-9)
        XCTAssertEqual(step.detentsCrossed, 24)
        XCTAssertEqual(dial.rotate(by: -90).distance, -30, accuracy: 1e-9)
    }

    func testDragWrapsAcrossZeroTheShortWay() {
        var dial = Dial()
        dial.begin(at: 350)
        let step = dial.drag(to: 10)
        XCTAssertEqual(step.degrees, 20, accuracy: 1e-9)
        let back = dial.drag(to: 340)
        XCTAssertEqual(back.degrees, -30, accuracy: 1e-9)
    }

    func testDragWithoutBeginOnlyPrimes() {
        var dial = Dial()
        XCTAssertEqual(dial.drag(to: 45), .none)
        XCTAssertEqual(dial.drag(to: 60).degrees, 15, accuracy: 1e-9)
        dial.end()
        XCTAssertEqual(dial.drag(to: 200), .none)
    }

    func testDetentCountingSlowFastAndReverse() {
        var dial = Dial(config: DialConfig(detentsPerTurn: 24)) // 15 degrees per detent
        XCTAssertEqual(dial.rotate(by: 10).detentsCrossed, 0)
        XCTAssertEqual(dial.rotate(by: 10).detentsCrossed, 1)  // 20
        XCTAssertEqual(dial.rotate(by: 100).detentsCrossed, 7) // 120
        XCTAssertEqual(dial.rotate(by: -121).detentsCrossed, 9) // -1, crosses 0 too
    }

    func testCapAngleStaysInRange() {
        var dial = Dial()
        dial.rotate(by: -30)
        XCTAssertEqual(dial.capAngle, 330, accuracy: 1e-9)
        dial.rotate(by: 400)
        XCTAssertEqual(dial.capAngle, 10, accuracy: 1e-9)
    }

    func testIgnoresNonFiniteInput() {
        var dial = Dial()
        XCTAssertEqual(dial.rotate(by: .nan), .none)
        XCTAssertEqual(dial.rotate(by: .infinity), .none)
        XCTAssertEqual(dial.totalDegrees, 0)
    }

    func testTwoDialsDrawALineThroughTheSketch() {
        // Alternating small turns of both dials gives a staircase that reads as a diagonal.
        var across = Dial()
        var upDown = Dial()
        var sketch = Sketch()
        let size = CanvasSize(width: 240, height: 240)
        for _ in 0..<36 {
            sketch.movePen(dx: across.rotate(by: 10).distance, dy: 0, in: size)
            sketch.movePen(dx: 0, dy: upDown.rotate(by: 10).distance, in: size)
        }
        // 36 x 10 degrees = one full turn each = 120 pt = half the canvas.
        XCTAssertEqual(sketch.pen.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(sketch.pen.y, 0.0, accuracy: 1e-9)
        XCTAssertEqual(sketch.strokes.count, 1)
        XCTAssertEqual(sketch.pointCount, 73)
    }

    func testAnticlockwiseDrawsLeftAndDown() {
        var dial = Dial()
        var sketch = Sketch()
        let size = CanvasSize(width: 120, height: 120)
        sketch.movePen(dx: dial.rotate(by: -90).distance, dy: 0, in: size)
        sketch.movePen(dx: 0, dy: dial.rotate(by: -90).distance, in: size)
        XCTAssertEqual(sketch.pen, Point(x: 0.25, y: 0.75))
    }

    // MARK: Dead zone (#16 review, finding 2)

    func testWobbleThroughTheCentreDoesNotMoveThePen() {
        var dial = Dial()
        let r = 46.0
        // A finger resting on the middle of the knob, wobbling by 1 pt.
        XCTAssertEqual(dial.drag(touchX: 0.5, y: 0, radius: r), .none)
        XCTAssertEqual(dial.drag(touchX: -0.5, y: 0, radius: r), .none)
        XCTAssertEqual(dial.drag(touchX: 0, y: 0.5, radius: r), .none)
        XCTAssertEqual(dial.totalDegrees, 0)
    }

    func testOldAngleOnlyPathJumpsNearTheCentre() {
        // Documents the bug the dead zone fixes: 1 pt across the centre is 180 degrees.
        var dial = Dial()
        dial.begin(at: atan2(0, 0.5) * 180 / .pi)
        let jump = dial.drag(to: atan2(0, -0.5) * 180 / .pi)
        XCTAssertEqual(abs(jump.distance), 60, accuracy: 1e-9)
    }

    func testLeavingTheDeadZoneStartsAFreshTurn() {
        var dial = Dial()
        let r = 46.0
        XCTAssertEqual(dial.drag(touchX: 40, y: 0, radius: r), .none, "first touch primes")
        XCTAssertGreaterThan(dial.drag(touchX: 28, y: 28, radius: r).degrees, 0, "eighth turn clockwise")
        XCTAssertGreaterThan(dial.drag(touchX: 0, y: 40, radius: r).degrees, 0, "quarter turn clockwise")
        let before = dial.totalDegrees
        XCTAssertEqual(dial.drag(touchX: 1, y: 1, radius: r), .none, "into the dead zone")
        // Out the opposite side: no half-turn jump, it just primes.
        XCTAssertEqual(dial.drag(touchX: -40, y: 0, radius: r), .none)
        XCTAssertEqual(dial.totalDegrees, before)
        XCTAssertEqual(dial.drag(touchX: -40, y: -1, radius: r).degrees, atan2(1, 40) * 180 / .pi, accuracy: 1e-9)
    }

    func testDeadZoneEdge() {
        var dial = Dial()
        let r = 50.0
        let edge = r * Dial.deadZoneFraction
        XCTAssertEqual(dial.drag(touchX: edge - 0.01, y: 0, radius: r), .none)
        _ = dial.drag(touchX: edge, y: 0, radius: r)
        XCTAssertNotEqual(dial.drag(touchX: 0, y: edge, radius: r), .none, "on the boundary counts as outside")
    }

    // MARK: Cancelled drag (SK-2)

    func testTouchFarFromTheLastOneStartsAFreshTurn() {
        var dial = Dial()
        let r = 46.0
        _ = dial.drag(touchX: 40, y: 0, radius: r)
        _ = dial.drag(touchX: 38, y: 10, radius: r)
        let before = dial.totalDegrees
        // The drag was cancelled (no end()), then a new touch lands on the opposite side.
        XCTAssertEqual(dial.drag(touchX: -38, y: -10, radius: r), .none, "no half-turn jump")
        XCTAssertEqual(dial.totalDegrees, before)
        XCTAssertNotEqual(dial.drag(touchX: -36, y: -16, radius: r), .none, "turning carries on from there")
    }

    func testNormalDragStepsStillTurn() {
        var dial = Dial()
        let r = 46.0
        _ = dial.drag(touchX: 40, y: 0, radius: r)
        var total = 0.0
        for i in 1...9 {
            let a = Double(i) * 10 * .pi / 180
            total += dial.drag(touchX: 40 * cos(a), y: 40 * sin(a), radius: r).degrees
        }
        XCTAssertEqual(total, 90, accuracy: 1e-9)
    }
}
