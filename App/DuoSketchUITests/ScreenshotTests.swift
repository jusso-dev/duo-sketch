import XCTest

/// App Store screenshots. Each test launches the app on a fixed demo drawing
/// and attaches a screenshot to the test result, kept even when tests pass.
/// `scripts/screenshots.sh` runs these on each device and exports the images
/// into `Screenshots/`. See docs/screenshots.md.
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1BlankBoard() {
        let app = launch(drawing: "blank")
        snap(app, "1-blank-board")
    }

    func test2FinishedDrawing() {
        let app = launch(drawing: "skyline")
        snap(app, "2-finished-drawing")
    }

    func test3EaselMode() {
        let app = launch(drawing: "spiral", posture: "easel")
        snap(app, "3-easel-mode")
    }

    func test4ShakeClear() {
        // -holdShake freezes the board mid swing with the drawing still on it,
        // so the shot doesn't race the 0.6 s animation.
        let app = launch(drawing: "hills", extra: ["-holdShake"])
        let clear = app.buttons["Clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        // While the shake is held the board is still drawn, so Clear stays put
        // and Undo clear never appears.
        XCTAssertFalse(app.buttons["Undo clear"].waitForExistence(timeout: 2))
        snap(app, "4-shake-clear")
    }

    func test5ShareSheet() {
        let app = launch(drawing: "skyline")
        let share = app.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        let framed = app.buttons["Share with frame"]
        XCTAssertTrue(framed.waitForExistence(timeout: 5))
        framed.tap()
        // Fail rather than save a picture of the board as the share sheet.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10), "share sheet did not appear")
        // Let the PNG preview render before the shot.
        sleep(2)
        snap(app, "5-share-sheet")
    }

    private func launch(drawing: String, posture: String = "open", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoDrawing", drawing, "-foldPosture", posture] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10))
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
