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

    /// The share sheet offers Save Image for the PNG export. Without this key
    /// iOS terminates the app the first time someone taps it.
    func testInfoPlistDeclaresPhotoLibraryAddUsage() {
        let text = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String
        XCTAssertNotNil(text, "NSPhotoLibraryAddUsageDescription is missing from the app's Info.plist")
        XCTAssertFalse(text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    /// A shake clear must always finish, even when the model's clock has not
    /// moved on by the shake duration (for example it paused while the phone
    /// slept). Before the fix the board stayed in `.shaking` and ignored the dials.
    func testShakeClearFinishesWhenClockLags() async {
        let model = SketchViewModel(
            foldService: UnavailableFoldStateService(),
            sketch: DemoDrawings.spiral(),
            clock: { 100 },          // frozen clock
            sleep: { _ in }          // no real wait
        )
        model.beginShakeClear()
        XCTAssertTrue(model.clearController.isShaking)
        await model.shakeTask?.value
        XCTAssertFalse(model.clearController.isShaking, "board is stuck shaking")
        XCTAssertTrue(model.sketch.isEmpty)

        model.canvasSize = CanvasSize(width: 240, height: 240)
        model.turn(.horizontal, by: 90)
        XCTAssertFalse(model.sketch.isEmpty, "dials work again after the clear")
    }

    /// A finger resting on the middle of a dial must not draw. Before the dead
    /// zone, a 1 pt wobble across the centre moved the pen 60 pt.
    func testWobbleOnDialCentreDoesNotDraw() {
        let model = SketchViewModel(foldService: UnavailableFoldStateService())
        model.canvasSize = CanvasSize(width: 240, height: 240)
        model.beginTurn(.horizontal)
        model.touch(.horizontal, x: 0.5, y: 0, radius: 46)
        model.touch(.horizontal, x: -0.5, y: 0, radius: 46)
        model.touch(.horizontal, x: 0.5, y: 0, radius: 46)
        model.endTurn(.horizontal)
        XCTAssertTrue(model.sketch.isEmpty)
        XCTAssertEqual(model.sketch.pen, .centre)
    }
}
