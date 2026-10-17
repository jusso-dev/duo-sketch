import XCTest
import UIKit
import SwiftUI
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

    // These used to sleep 450 ms and 800 ms of real time against 0.4 s and
    // 0.6 s thresholds, which could flake on a busy hosted runner. They now
    // use an injected clock and sleep, so they don't wait at all.

    func testCloseAndReopenStartsShakeClear() async {
        var now = 0.0
        let model = SketchViewModel(
            foldService: MockFoldStateService(initial: .open),
            sketch: DemoDrawings.spiral(),
            clock: { now },
            sleep: { _ in }
        )
        model.handle(.closed)
        now = 0.45
        model.handle(.open)
        XCTAssertEqual(model.shakeTrigger, 1)
        await model.shakeTask?.value
        XCTAssertTrue(model.sketch.isEmpty)
    }

    func testQuickCloseAndReopenDoesNotClear() {
        var now = 0.0
        let model = SketchViewModel(
            foldService: MockFoldStateService(initial: .open),
            sketch: DemoDrawings.spiral(),
            clock: { now },
            sleep: { _ in }
        )
        model.handle(.closed)
        now = 0.3
        model.handle(.open)
        XCTAssertEqual(model.shakeTrigger, 0, "closed for under 0.4 s")
        XCTAssertFalse(model.sketch.isEmpty)
    }

    /// End to end through the fold service, as the app runs it.
    func testFoldServiceUpdatesDriveTheClear() async {
        let mock = MockFoldStateService(initial: .open)
        var now = 0.0
        let model = SketchViewModel(
            foldService: mock,
            sketch: DemoDrawings.spiral(),
            clock: { now += 0.5; return now },
            sleep: { _ in }
        )
        let observing = Task { await model.observeFold() }
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(mock.subscriberCount, 1)
        mock.send(.closed)
        mock.send(.open)
        mock.finish()
        await observing.value
        XCTAssertEqual(model.posture, .open)
        XCTAssertEqual(model.shakeTrigger, 1)
        await model.shakeTask?.value
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

    /// "Share drawing only" is the drawing on its own: no eucalyptus card, so
    /// the image is exactly the drawing's shape at `longSide`.
    func testPlainExportHasNoFrame() throws {
        let tall = CanvasSize(width: 300, height: 450)
        let export = SketchExport(sketch: DemoDrawings.spiral(size: tall), canvasSize: tall, framed: false)
        XCTAssertEqual(export.padding, 0)
        let image = try XCTUnwrap(UIImage(data: try export.pngData()))
        XCTAssertEqual(image.size.width * image.scale, 720, accuracy: 1)
        XCTAssertEqual(image.size.height * image.scale, 1080, accuracy: 1)
        // The SVG offered alongside is the same either way.
        XCTAssertEqual(export.svgString(), SketchExport(sketch: export.sketch, canvasSize: tall).svgString())
    }

    /// Text and ink on the fixed palette stay readable in light and dark
    /// appearance (4.5:1), and the dial arrow stays visible (3:1).
    func testPaletteContrastInLightAndDark() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            func ratio(_ a: Color, _ b: Color) -> Double {
                Self.contrast(UIColor(a).resolvedColor(with: traits), UIColor(b).resolvedColor(with: traits))
            }
            XCTAssertGreaterThanOrEqual(ratio(Theme.ink, Theme.surface), 4.5, "ink on sand, \(style)")
            XCTAssertGreaterThanOrEqual(ratio(Theme.label, Theme.body), 4.5, "wordmark on body, \(style)")
            XCTAssertGreaterThanOrEqual(ratio(Theme.label, Theme.bodyShade), 4.5, "wordmark on shade, \(style)")
            // The dial is a gradient from brass to dark brass; check the darkest end.
            XCTAssertGreaterThanOrEqual(ratio(Theme.dialMark, Theme.brass), 3, "dial arrow on brass, \(style)")
            XCTAssertGreaterThanOrEqual(ratio(Theme.dialMark, Theme.brassDark), 3, "dial arrow on dark brass, \(style)")
        }
    }

    private static func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        func luminance(_ c: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            c.getRed(&r, green: &g, blue: &bl, alpha: &al)
            func lin(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(bl)
        }
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Each device shake takes a third of the ink's opacity.
    func testDeviceShakeFadesByAThirdEachTime() throws {
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), sketch: DemoDrawings.hills())
        var spoken: [String] = []
        model.announce = { spoken.append($0) }
        model.deviceShaken()
        XCTAssertEqual(try XCTUnwrap(model.sketch.strokes.first).opacity, 2.0 / 3, accuracy: 0.01)
        model.deviceShaken()
        XCTAssertEqual(try XCTUnwrap(model.sketch.strokes.first).opacity, 1.0 / 3, accuracy: 0.01)
        model.deviceShaken()
        XCTAssertTrue(model.sketch.isEmpty)
        XCTAssertEqual(spoken, ["Drawing faded", "Drawing faded", "Board cleared"])
        // Shaking an empty board says nothing.
        model.deviceShaken()
        XCTAssertEqual(spoken.count, 3)
    }

    /// The settled ink layer must compare equal across ordinary pen moves, so
    /// SwiftUI keeps it instead of redrawing every point on every move.
    func testSettledInkLayerIsStableAcrossSmallMoves() {
        var sketch = DemoDrawings.spiral()
        let canvas = CanvasSize(width: 360, height: 360)
        let before = SettledInkLayer(sketch: sketch, split: sketch.inkSplit())
        sketch.movePen(dx: 3, dy: 0, in: canvas)
        sketch.movePen(dx: 0, dy: 3, in: canvas)
        let after = SettledInkLayer(sketch: sketch, split: sketch.inkSplit())
        XCTAssertEqual(before, after)
        sketch.fade(by: 0.2)
        XCTAssertNotEqual(after, SettledInkLayer(sketch: sketch, split: sketch.inkSplit()))
    }

    /// The app has one model for the whole process, so it must not allow a
    /// second scene: two boards would share one drawing, fade twice per shake
    /// and fight over the canvas size.
    func testInfoPlistDisallowsMultipleScenes() throws {
        let manifest = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)
    }

    /// Shakes are caught by a first-responder view controller, debounced to
    /// one per 0.5 s.
    func testAppHasAnIcon() throws {
        let icons = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                                  "No CFBundleIcons, so the asset catalogue produced no app icon")
        let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
        XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIcon")
    }

    func testShakeResponderDebouncesShakes() {
        var now = 0.0
        var shakes = 0
        let controller = ShakeResponderController(clock: { now })
        controller.onShake = { shakes += 1 }
        XCTAssertTrue(controller.canBecomeFirstResponder)
        controller.motionEnded(.motionShake, with: nil)
        now = 0.2
        controller.motionEnded(.motionShake, with: nil)
        XCTAssertEqual(shakes, 1, "a second event from the same shake is dropped")
        now = 0.8
        controller.motionEnded(.motionShake, with: nil)
        XCTAssertEqual(shakes, 2)
        controller.motionEnded(.remoteControlPlay, with: nil)
        XCTAssertEqual(shakes, 2, "other motions are ignored")
    }

    /// The old code added `motionEnded` to every `UIWindow` in an extension.
    func testWindowsKeepUIKitsOwnMotionHandling() {
        let notPosted = XCTNSNotificationExpectation(name: Notification.Name("DuoSketch.deviceDidShake"))
        notPosted.isInverted = true
        UIWindow().motionEnded(.motionShake, with: nil)
        wait(for: [notPosted], timeout: 0.2)
    }

    // MARK: VoiceOver (SK-10)

    func testDialsReportThePenPosition() {
        let model = SketchViewModel(foldService: UnavailableFoldStateService())
        model.canvasSize = CanvasSize(width: 300, height: 300)
        XCTAssertEqual(model.accessibilityValue(for: .horizontal), "Pen 50 percent across")
        model.turn(.horizontal, by: 90)   // 30 pt right, a tenth of the width
        model.turn(.vertical, by: -180)   // 60 pt down
        XCTAssertEqual(model.accessibilityValue(for: .horizontal), "Pen 60 percent across")
        XCTAssertEqual(model.accessibilityValue(for: .vertical), "Pen 70 percent down")
    }

    func testCanvasValueDescribesTheDrawingNotAPointCount() {
        XCTAssertEqual(CanvasView.accessibilityValue(for: Sketch()), "Empty, pen 50 percent across, 50 percent down")
        let value = CanvasView.accessibilityValue(for: DemoDrawings.spiral())
        XCTAssertTrue(value.hasPrefix("Drawing with 1 line, pen "), value)
        XCTAssertFalse(value.contains("points"))
    }

    func testClearsAreAnnounced() async {
        var spoken: [String] = []
        let model = SketchViewModel(
            foldService: UnavailableFoldStateService(),
            sketch: DemoDrawings.hills(),
            clock: { 0 },
            sleep: { _ in }
        )
        model.announce = { spoken.append($0) }
        model.deviceShaken()
        XCTAssertEqual(spoken, ["Drawing faded"])
        model.beginShakeClear()
        await model.shakeTask?.value
        XCTAssertEqual(spoken, ["Drawing faded", "Board cleared"])
        model.deviceShaken()
        XCTAssertEqual(spoken.count, 2, "nothing to announce on an empty board")
    }

    // MARK: Undo clear (SK-11)

    func testAccidentalCloseAndReopenCanBeUndone() async {
        let original = DemoDrawings.spiral()
        var now = 0.0
        let model = SketchViewModel(
            foldService: MockFoldStateService(initial: .open),
            sketch: original,
            clock: { now },
            sleep: { seconds in if seconds == SketchViewModel.undoWindow { try? await Task.sleep(for: .seconds(3600)) } }
        )
        model.handle(.closed)
        now = 0.5
        model.handle(.open)
        await model.shakeTask?.value
        XCTAssertTrue(model.sketch.isEmpty)
        XCTAssertTrue(model.canUndoClear)
        model.undoClear()
        XCTAssertEqual(model.sketch, original)
        XCTAssertFalse(model.canUndoClear)
    }

    func testUndoExpires() async {
        let gate = SleepGate()
        let model = SketchViewModel(
            foldService: UnavailableFoldStateService(),
            sketch: DemoDrawings.spiral(),
            clock: { 0 },
            sleep: { seconds in if seconds == SketchViewModel.undoWindow { await gate.wait() } }
        )
        model.beginShakeClear()
        await model.shakeTask?.value
        XCTAssertTrue(model.canUndoClear)
        while gate.count == 0 { await Task.yield() }
        gate.openAll()
        await model.undoExpiryTask?.value
        XCTAssertFalse(model.canUndoClear)
        model.undoClear()
        XCTAssertTrue(model.sketch.isEmpty, "too late to undo")
    }

    func testDrawingAfterAClearDropsUndo() async {
        let model = SketchViewModel(
            foldService: UnavailableFoldStateService(),
            sketch: DemoDrawings.spiral(),
            clock: { 0 },
            sleep: { seconds in if seconds == SketchViewModel.undoWindow { try? await Task.sleep(for: .seconds(3600)) } }
        )
        model.canvasSize = CanvasSize(width: 300, height: 300)
        model.beginShakeClear()
        await model.shakeTask?.value
        model.turn(.horizontal, by: 90)
        XCTAssertFalse(model.canUndoClear, "a new drawing is never replaced by an undo")
    }

    // MARK: Saving when the scene leaves the foreground

    func testLeavingTheForegroundSavesTheDrawing() async {
        let store = MemorySketchStore()
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), store: store, clock: { 0 }, sleep: { _ in })
        model.canvasSize = CanvasSize(width: 300, height: 300)
        model.turn(.horizontal, by: 180)
        model.scenePhaseChanged(to: .active)
        XCTAssertNil(model.saveTask, "nothing is saved while the app is in use")
        model.scenePhaseChanged(to: .inactive)
        await model.saveTask?.value
        XCTAssertEqual(store.saves.map(\.sketch), [model.sketch])
        model.scenePhaseChanged(to: .background)
        await model.saveTask?.value
        XCTAssertEqual(store.saves.count, 1, "an unchanged drawing isn't written twice")
        model.turn(.vertical, by: 90)
        model.scenePhaseChanged(to: .background)
        await model.saveTask?.value
        XCTAssertEqual(store.saves.last?.sketch, model.sketch)
    }

    func testAClearWithUndoOnOfferIsSavedWithTheDrawingItRemoved() async {
        let original = DemoDrawings.spiral()
        let store = MemorySketchStore()
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), sketch: original, store: store, clock: { 0 }, sleep: waitForever)
        model.beginShakeClear()
        await model.shakeTask?.value
        model.scenePhaseChanged(to: .background)
        await model.saveTask?.value
        XCTAssertEqual(store.saves.last?.sketch.isEmpty, true)
        XCTAssertEqual(store.saves.last?.undoSketch, original)
    }

    func testTheDrawingComesBackOnTheNextLaunch() async {
        let store = MemorySketchStore()
        let first = SketchViewModel(foldService: UnavailableFoldStateService(), sketch: DemoDrawings.hills(), store: store, clock: { 0 }, sleep: { _ in })
        first.scenePhaseChanged(to: .background)
        await first.saveTask?.value

        let next = SketchViewModel(foldService: UnavailableFoldStateService(), store: store, clock: { 0 }, sleep: { _ in })
        await next.restore()
        XCTAssertEqual(next.sketch, DemoDrawings.hills())
        XCTAssertFalse(next.canUndoClear)
    }

    func testUndoIsOfferedAgainAfterRelaunch() async {
        let original = DemoDrawings.spiral()
        var cleared = original
        cleared.clear()
        let store = MemorySketchStore(initial: SketchArchive(sketch: cleared, undoSketch: original))
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), store: store, clock: { 0 }, sleep: waitForever)
        await model.restore()
        XCTAssertTrue(model.canUndoClear)
        model.undoClear()
        XCTAssertEqual(model.sketch, original)
    }

    func testRestoreDoesNotReplaceANewDrawing() async {
        let store = MemorySketchStore(initial: SketchArchive(sketch: DemoDrawings.spiral()))
        let model = SketchViewModel(foldService: UnavailableFoldStateService(), store: store, clock: { 0 }, sleep: { _ in })
        model.canvasSize = CanvasSize(width: 300, height: 300)
        model.turn(.horizontal, by: 180)
        let drawn = model.sketch
        await model.restore()
        XCTAssertEqual(model.sketch, drawn)
    }
}

/// A sleep that never ends for the Undo window, so Undo stays on offer.
let waitForever: @Sendable (Double) async -> Void = { seconds in
    if seconds == SketchViewModel.undoWindow { try? await Task.sleep(for: .seconds(3600)) }
}

/// Keeps archives in memory, in the order they were saved.
final class MemorySketchStore: SketchStore, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [SketchArchive] = []
    private let initial: SketchArchive?
    init(initial: SketchArchive? = nil) { self.initial = initial }
    func save(_ archive: SketchArchive) throws { lock.withLock { saved.append(archive) } }
    func load() -> SketchArchive? { lock.withLock { saved.last ?? initial } }
    var saves: [SketchArchive] { lock.withLock { saved } }
}

/// A sleep that only returns when the test lets it.
final class SleepGate: @unchecked Sendable {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let lock = NSLock()
    func wait() async {
        await withCheckedContinuation { c in lock.withLock { waiters.append(c) } }
    }
    func openAll() {
        let all = lock.withLock { defer { waiters = [] }; return waiters }
        all.forEach { $0.resume() }
    }
    var count: Int { lock.withLock { waiters.count } }
}
