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
        let mock = MockFoldStateService(.open)
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
        let expected: [FoldPosture] = [.partiallyOpen(angleDegrees: 60), .closed, .partiallyOpen(angleDegrees: 60), .open]
        XCTAssertEqual(seenA, expected)
        XCTAssertEqual(seenB, expected)
        XCTAssertEqual(mock.current, .open)
        XCTAssertEqual(mock.subscriberCount, 0)
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
            if seen.count == 4 { break }
        }
        XCTAssertEqual(seen, [.partiallyOpen(angleDegrees: 120), .partiallyOpen(angleDegrees: 123), .open, .unavailable])
    }

    func testStaticService() async {
        let service = StaticFoldStateService()
        XCTAssertFalse(service.isHingeAvailable)
        XCTAssertEqual(service.current, .unavailable)
        var count = 0
        for await _ in service.updates { count += 1 }
        XCTAssertEqual(count, 0)
    }

    func testMockReading() {
        let mock = MockFoldStateService()
        mock.send(reading: nil)
        XCTAssertFalse(mock.isHingeAvailable)
        mock.send(reading: .init(status: .closed, angleDegrees: 0))
        XCTAssertEqual(mock.current, .closed)
    }
}
