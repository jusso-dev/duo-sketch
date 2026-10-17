import XCTest
@testable import SketchCore

final class FoldStateTests: XCTestCase {
    func testNilReadingMeansUnavailable() {
        XCTAssertEqual(FoldPosture(reading: nil), .unavailable)
    }

    func testStatusMapping() {
        XCTAssertEqual(FoldPosture(reading: .init(status: .closed, angleDegrees: 3)), .closed)
        XCTAssertEqual(FoldPosture(reading: .init(status: .fullyOpen, angleDegrees: 178)), .open)
        XCTAssertEqual(FoldPosture(reading: .init(status: .partiallyOpen, angleDegrees: 95)), .partiallyOpen(angleDegrees: 95))
    }

    func testAngleIsClampedAndSanitised() {
        XCTAssertEqual(FoldPosture(reading: .init(status: .partiallyOpen, angleDegrees: -10)), .partiallyOpen(angleDegrees: 0))
        XCTAssertEqual(FoldPosture(reading: .init(status: .partiallyOpen, angleDegrees: 400)), .partiallyOpen(angleDegrees: 180))
        XCTAssertEqual(FoldPosture(reading: .init(status: .partiallyOpen, angleDegrees: .nan)), .partiallyOpen(angleDegrees: 90))
    }

    func testHelpers() {
        XCTAssertEqual(FoldPosture.closed.angleDegrees, 0)
        XCTAssertEqual(FoldPosture.open.angleDegrees, 180)
        XCTAssertNil(FoldPosture.unavailable.angleDegrees)
        XCTAssertTrue(FoldPosture.partiallyOpen(angleDegrees: 45).isPartiallyOpen)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: 44.6).description, "partiallyOpen(45°)")
    }

    func testMockFansOutToTwoSubscribersAndSkipsDuplicates() async {
        let mock = MockFoldStateService(initial: .open)
        let a = mock.updates
        let b = mock.updates
        XCTAssertEqual(mock.subscriberCount, 2)
        mock.send(.open) // duplicate, not delivered
        mock.closeAndReopen()
        mock.finish()
        var seenA: [FoldPosture] = []
        for await p in a { seenA.append(p) }
        var seenB: [FoldPosture] = []
        for await p in b { seenB.append(p) }
        let expected: [FoldPosture] = [.open, .partiallyOpen(angleDegrees: 60), .closed, .partiallyOpen(angleDegrees: 60), .open]
        XCTAssertEqual(seenA, expected, "current first, then changes")
        XCTAssertEqual(seenB, expected)
        XCTAssertEqual(mock.current, .open)
        XCTAssertEqual(mock.subscriberCount, 0)
        XCTAssertEqual(mock.history, expected)
    }

    func testCancelledStreamUnsubscribes() async {
        let mock = MockFoldStateService()
        let task = Task {
            for await _ in mock.updates {}
        }
        while mock.subscriberCount == 0 { await Task.yield() }
        task.cancel()
        await task.value
        XCTAssertEqual(mock.subscriberCount, 0)
    }

    func testHingeServiceThresholdAndAvailability() async {
        let service = HingeFoldStateService(angleThreshold: 2)
        XCTAssertFalse(service.isHingeAvailable)
        let stream = service.updates
        service.update(reading: .init(status: .partiallyOpen, angleDegrees: 120))
        service.update(reading: .init(status: .partiallyOpen, angleDegrees: 121.5)) // below threshold
        service.update(reading: .init(status: .partiallyOpen, angleDegrees: 123))
        service.update(reading: .init(status: .fullyOpen, angleDegrees: 180))
        XCTAssertTrue(service.isHingeAvailable)
        service.update(reading: nil)
        XCTAssertEqual(service.current, .unavailable)
        var seen: [FoldPosture] = []
        for await p in stream {
            seen.append(p)
            if seen.count == 5 { break }
        }
        XCTAssertEqual(seen, [.unavailable, .partiallyOpen(angleDegrees: 120), .partiallyOpen(angleDegrees: 123), .open, .unavailable])
    }

    func testStaticService() async {
        let service = UnavailableFoldStateService()
        XCTAssertFalse(service.isHingeAvailable)
        XCTAssertEqual(service.current, .unavailable)
        var seen: [FoldPosture] = []
        for await p in service.updates { seen.append(p) }
        XCTAssertEqual(seen, [.unavailable])
    }

    func testStaticServiceKeepsItsPosture() async {
        let service = StaticFoldStateService(.partiallyOpen(angleDegrees: 100))
        XCTAssertTrue(service.isHingeAvailable)
        var seen: [FoldPosture] = []
        for await p in service.updates { seen.append(p) }
        XCTAssertEqual(seen, [.partiallyOpen(angleDegrees: 100)])
    }

    func testSlowSubscriberKeepsOnlyTheNewestPostures() async {
        let mock = MockFoldStateService(initial: .open)
        let stream = mock.updates
        for i in 1...(FoldBroadcaster.bufferSize + 50) { mock.send(.partiallyOpen(angleDegrees: Double(i) / 10)) }
        mock.finish()
        var seen: [FoldPosture] = []
        for await p in stream { seen.append(p) }
        XCTAssertEqual(seen.count, FoldBroadcaster.bufferSize)
        XCTAssertEqual(seen.last, .partiallyOpen(angleDegrees: Double(FoldBroadcaster.bufferSize + 50) / 10))
    }

    func testUnreadSubscriberKeepsAWholeFoldGesture() async {
        // Open flat, close in 2 degree steps, then open again: what the hinge
        // service publishes at most for one fold. Nobody reads until the end.
        let mock = MockFoldStateService(initial: .open)
        let stream = mock.updates
        for a in stride(from: 178.0, through: 2, by: -2) { mock.send(.partiallyOpen(angleDegrees: a)) }
        mock.send(.closed)
        for a in stride(from: 2.0, through: 178, by: 2) { mock.send(.partiallyOpen(angleDegrees: a)) }
        mock.send(.open)
        mock.finish()
        var policy = FoldClearPolicy()
        var t = 0.0
        var clears = 0
        for await p in stream {
            t += 0.01
            if policy.handle(p, at: t) { clears += 1 }
            if p == .closed { t += 1 } // stayed shut for a second
        }
        XCTAssertEqual(clears, 1, "the .closed posture was not dropped")
    }

    func testOpeningScriptAndOpenFraction() {
        let mock = MockFoldStateService()
        XCTAssertEqual(mock.current, .closed)
        mock.play(MockFoldStateService.openingScript)
        XCTAssertEqual(mock.history, MockFoldStateService.openingScript)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: 90).openFraction(), 0.5)
        XCTAssertEqual(FoldPosture.closed.openFraction(), 0)
        XCTAssertEqual(FoldPosture.unavailable.openFraction(), 1)
        XCTAssertFalse(FoldPosture.unavailable.hasHinge)
        XCTAssertFalse(mock.send(.open), "duplicate")
    }

    func testMockReading() {
        let mock = MockFoldStateService()
        mock.send(reading: nil)
        XCTAssertFalse(mock.isHingeAvailable)
        mock.send(reading: .init(status: .closed, angleDegrees: 0))
        XCTAssertEqual(mock.current, .closed)
    }
}
