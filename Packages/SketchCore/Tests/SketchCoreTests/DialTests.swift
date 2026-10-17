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
}
