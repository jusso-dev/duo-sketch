import XCTest
@testable import SketchCore

final class ClearControllerTests: XCTestCase {
    func drawn() -> Sketch {
        var s = Sketch()
        s.movePen(dx: 40, dy: 20, in: CanvasSize(width: 100, height: 100))
        return s
    }

    func testShakeClearFinishesAfterDuration() {
        var c = ClearController()
        var s = drawn()
        XCTAssertTrue(c.beginShakeClear(at: 10))
        XCTAssertFalse(c.beginShakeClear(at: 10.1), "no double trigger")
        XCTAssertFalse(c.tick(at: 10.3, sketch: &s))
        XCTAssertFalse(s.isEmpty)
        XCTAssertEqual(c.progress(at: 10.3)!, 0.5, accuracy: 1e-9)
        XCTAssertTrue(c.tick(at: 10.6, sketch: &s))
        XCTAssertTrue(s.isEmpty)
        XCTAssertEqual(c.phase, .idle)
        XCTAssertNil(c.progress(at: 11))
    }

    func testShakeOffsetDecaysToZero() {
        var c = ClearController()
        XCTAssertEqual(c.shakeOffset(at: 0), 0)
        c.beginShakeClear(at: 0)
        XCTAssertEqual(c.shakeOffset(at: 0.6), 0, accuracy: 1e-9)
        let peak = (0..<60).map { abs(c.shakeOffset(at: Double($0) / 100)) }.max()!
        XCTAssertGreaterThan(peak, 5)
        XCTAssertLessThanOrEqual(peak, 14)
    }

    func testThreeDeviceShakesClear() {
        let c = ClearController()
        var s = drawn()
        XCTAssertFalse(c.deviceShaken(sketch: &s))
        XCTAssertFalse(c.deviceShaken(sketch: &s))
        XCTAssertTrue(c.deviceShaken(sketch: &s))
        XCTAssertTrue(s.isEmpty)
    }

    func testDeviceShakeIgnoredDuringFoldClear() {
        var c = ClearController()
        var s = drawn()
        c.beginShakeClear(at: 0)
        c.deviceShaken(sketch: &s)
        XCTAssertEqual(s.strokes.first?.opacity, 1)
    }
}

final class FoldClearPolicyTests: XCTestCase {
    func testCloseAndReopenClears() {
        var p = FoldClearPolicy()
        XCTAssertFalse(p.handle(.open, at: 0))
        XCTAssertFalse(p.handle(.partiallyOpen(angleDegrees: 60), at: 1))
        XCTAssertFalse(p.handle(.closed, at: 1.2))
        XCTAssertFalse(p.handle(.partiallyOpen(angleDegrees: 50), at: 2))
        XCTAssertTrue(p.handle(.open, at: 2.5))
        XCTAssertFalse(p.handle(.open, at: 3), "only once")
    }

    func testQuickWobbleDoesNotClear() {
        var p = FoldClearPolicy(minimumClosedDuration: 0.4)
        _ = p.handle(.open, at: 0)
        _ = p.handle(.closed, at: 1.0)
        _ = p.handle(.partiallyOpen(angleDegrees: 20), at: 1.2)
        XCTAssertFalse(p.handle(.open, at: 3))
    }

    func testHalfOpenToOpenDoesNotClear() {
        var p = FoldClearPolicy()
        _ = p.handle(.partiallyOpen(angleDegrees: 90), at: 0)
        XCTAssertFalse(p.handle(.open, at: 5))
    }

    func testClosedStraightToOpen() {
        var p = FoldClearPolicy()
        _ = p.handle(.closed, at: 0)
        XCTAssertTrue(p.handle(.open, at: 1))
    }

    func testReclosingRestartsTimer() {
        var p = FoldClearPolicy(minimumClosedDuration: 0.4)
        _ = p.handle(.closed, at: 0)
        _ = p.handle(.partiallyOpen(angleDegrees: 30), at: 0.1)
        _ = p.handle(.closed, at: 0.2)
        _ = p.handle(.partiallyOpen(angleDegrees: 30), at: 0.3)
        XCTAssertFalse(p.handle(.open, at: 1))
    }

    func testUnknownResets() {
        var p = FoldClearPolicy()
        _ = p.handle(.closed, at: 0)
        _ = p.handle(.unavailable, at: 1)
        XCTAssertFalse(p.handle(.open, at: 2))
    }

    func testEndToEndWithMockService() async {
        let mock = MockFoldStateService(.open)
        let stream = mock.updates
        mock.closeAndReopen()
        mock.send(.partiallyOpen(angleDegrees: 100))
        mock.send(.open)
        mock.finish()
        var policy = FoldClearPolicy(minimumClosedDuration: 0)
        var clears = 0
        var t = 0.0
        for await posture in stream {
            t += 1
            if policy.handle(posture, at: t) { clears += 1 }
        }
        XCTAssertEqual(clears, 1)
    }
}
