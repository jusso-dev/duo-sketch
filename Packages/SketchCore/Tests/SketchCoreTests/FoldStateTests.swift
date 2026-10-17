import XCTest
@testable import SketchCore

@MainActor
final class FoldStateTests: XCTestCase {
    func testNilReadingMeansUnknown() {
        XCTAssertEqual(FoldState(reading: nil), .unknown)
    }

    func testStatusMapping() {
        XCTAssertEqual(FoldState(reading: .init(status: .closed, angleDegrees: 3)), .closed)
        XCTAssertEqual(FoldState(reading: .init(status: .fullyOpen, angleDegrees: 178)), .open)
        XCTAssertEqual(FoldState(reading: .init(status: .partiallyOpen, angleDegrees: 95)), .halfOpen(angle: 95))
    }

    func testHalfOpenAngleIsClampedAndSanitised() {
        XCTAssertEqual(FoldState(reading: .init(status: .partiallyOpen, angleDegrees: -10)), .halfOpen(angle: 0))
        XCTAssertEqual(FoldState(reading: .init(status: .partiallyOpen, angleDegrees: 400)), .halfOpen(angle: 180))
        XCTAssertEqual(FoldState(reading: .init(status: .partiallyOpen, angleDegrees: .nan)), .halfOpen(angle: 90))
    }

    func testAngleAndFlags() {
        XCTAssertEqual(FoldState.closed.angle, 0)
        XCTAssertEqual(FoldState.open.angle, 180)
        XCTAssertNil(FoldState.unknown.angle)
        XCTAssertTrue(FoldState.halfOpen(angle: 45).isHalfOpen)
        XCTAssertEqual(FoldState.halfOpen(angle: 44.6).description, "halfOpen(45°)")
    }

    func testMockDeliversChangesInOrderAndSkipsDuplicates() {
        let mock = MockFoldStateService(initial: .open)
        var seen: [FoldState] = []
        let token = mock.observe { seen.append($0) }
        mock.send(.open)
        mock.closeAndReopen()
        XCTAssertEqual(seen, [.halfOpen(angle: 60), .closed, .halfOpen(angle: 60), .open])
        XCTAssertEqual(mock.current, .open)
        token.cancel()
        mock.send(.closed)
        XCTAssertEqual(seen.count, 4)
    }

    func testObservationStopsWhenReleased() {
        let mock = MockFoldStateService()
        var count = 0
        var token: FoldObservation? = mock.observe { _ in count += 1 }
        mock.send(.closed)
        XCTAssertNotNil(token)
        token = nil
        mock.send(.open)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(mock.observerCount, 0)
    }

    func testHingeServiceTracksAvailability() {
        let service = HingeFoldStateService()
        XCTAssertFalse(service.isHingeAvailable)
        service.update(reading: .init(status: .partiallyOpen, angleDegrees: 120))
        XCTAssertTrue(service.isHingeAvailable)
        XCTAssertEqual(service.current, .halfOpen(angle: 120))
        service.update(reading: nil)
        XCTAssertFalse(service.isHingeAvailable)
        XCTAssertEqual(service.current, .unknown)
    }

    func testNoHingeService() {
        let service = NoHingeFoldStateService()
        XCTAssertFalse(service.isHingeAvailable)
        XCTAssertEqual(service.current, .unknown)
    }

    func testMockReadingUpdatesAvailability() {
        let mock = MockFoldStateService()
        mock.send(reading: nil)
        XCTAssertFalse(mock.isHingeAvailable)
        XCTAssertEqual(mock.current, .unknown)
    }
}
