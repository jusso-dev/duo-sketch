import XCTest
import SketchCore
@testable import DuoSketch

@MainActor
final class DuoSketchTests: XCTestCase {
    func testTurningDialsMovesPen() {
        let model = SketchViewModel(foldService: UnavailableFoldStateService())
        model.canvasSize = CanvasSize(width: 240, height: 240)
        model.turn(.horizontal, by: 360) // 120 pt right
        XCTAssertEqual(model.sketch.pen.x, 1, accuracy: 1e-9)
        model.turn(.vertical, by: 180)   // 60 pt up
        XCTAssertEqual(model.sketch.pen.y, 0.25, accuracy: 1e-9)
        XCTAssertFalse(model.sketch.isEmpty)
    }

    func testCloseAndReopenStartsShakeClear() async {
        let mock = MockFoldStateService(initial: .open)
        let model = SketchViewModel(foldService: mock, sketch: DemoDrawings.spiral())
        model.handle(.closed)
        try? await Task.sleep(for: .milliseconds(450))
        model.handle(.open)
        XCTAssertEqual(model.shakeTrigger, 1)
        try? await Task.sleep(for: .milliseconds(800))
        XCTAssertTrue(model.sketch.isEmpty)
    }

    func testDeviceShakeFades() {
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), sketch: DemoDrawings.hills())
        model.deviceShaken()
        model.deviceShaken()
        XCTAssertFalse(model.sketch.isEmpty)
        model.deviceShaken()
        XCTAssertTrue(model.sketch.isEmpty)
    }
}
