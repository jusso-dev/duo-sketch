import XCTest

/// The `-foldDebug` overlay used to check poses on the iPhone Duo simulator.
/// `-foldPosture` fixes the pose here, so this runs on any simulator; on the
/// Duo simulator, drop `-foldPosture` and use the fold controls instead.
@MainActor
final class FoldDebugTests: XCTestCase {
    func testOverlayShowsPostureAndAngle() {
        for (posture, expected) in [("easel", "partiallyOpen(100°)"), ("closed", "closed"), ("open", "open")] {
            let app = XCUIApplication()
            app.launchArguments = ["-demoDrawing", "spiral", "-foldPosture", posture, "-foldDebug"]
            app.launch()
            let overlay = app.staticTexts["foldDebug"]
            XCTAssertTrue(overlay.waitForExistence(timeout: 10), posture)
            XCTAssertEqual(overlay.label, "Fold: \(expected)")
            app.terminate()
        }
    }

    func testOverlayIsOffByDefault() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoDrawing", "spiral"]
        app.launch()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["foldDebug"].exists)
    }
}
