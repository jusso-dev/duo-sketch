import XCTest
import UIKit
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

    /// Exports keep the canvas's aspect ratio. They used to be squashed into a
    /// 1080 square, so circles drawn on a tall canvas came out as ovals.
    func testExportsKeepCanvasAspectRatio() throws {
        let tall = CanvasSize(width: 300, height: 450)
        let export = SketchExport(sketch: DemoDrawings.spiral(size: tall), canvasSize: tall)

        let svg = export.svgString()
        XCTAssertTrue(svg.contains("width=\"720\" height=\"1080\""), "SVG header: \(svg.prefix(120))")

        let png = try export.pngData()
        let image = try XCTUnwrap(UIImage(data: png))
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        XCTAssertEqual(pixelHeight, 1080, accuracy: 1)
        XCTAssertLessThan(pixelWidth, pixelHeight, "PNG is no longer square")
        // Card = canvas (216 x 324 pt) + 18 pt padding each side, at 3x.
        XCTAssertEqual(pixelWidth, (216 + 36) * 3, accuracy: 1)
    }

    /// A drawing made on one canvas shape exports at that shape, even after the
    /// canvas changes (rotation, easel to open, inner to outer display).
    func testExportKeepsTheDrawingShapeAfterTheCanvasChanges() {
        let wide = CanvasSize(width: 800, height: 400)
        let export = SketchExport(sketch: DemoDrawings.spiral(size: wide), canvasSize: CanvasSize(width: 360, height: 500))
        XCTAssertEqual(export.svgSize, CanvasSize(width: 1080, height: 540))
    }
}
