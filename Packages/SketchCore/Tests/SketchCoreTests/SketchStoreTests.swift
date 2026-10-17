import XCTest
@testable import SketchCore

final class SketchStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SketchStoreTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func drawn() -> Sketch {
        var s = Sketch()
        let size = CanvasSize(width: 300, height: 200)
        s.movePen(dx: 40, dy: 0, in: size)
        s.movePen(dx: 0, dy: 30, in: size)
        s.movePen(dx: -500, dy: 0, in: size) // ends touching the left edge
        return s
    }

    func testSaveThenLoadGivesBackTheSameDrawing() throws {
        let store = FileSketchStore(url: dir.appendingPathComponent("nested/Sketch.json"))
        let archive = SketchArchive(sketch: drawn())
        try store.save(archive)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded, archive)
        XCTAssertEqual(loaded.sketch.pen, archive.sketch.pen)
        XCTAssertEqual(loaded.sketch.aspectRatio, 1.5)
        XCTAssertNil(loaded.undoSketch)
    }

    func testPendingUndoIsSavedToo() throws {
        let store = FileSketchStore(url: dir.appendingPathComponent("Sketch.json"))
        var cleared = drawn()
        cleared.clear()
        try store.save(SketchArchive(sketch: cleared, undoSketch: drawn()))
        let loaded = try XCTUnwrap(store.load())
        XCTAssertTrue(loaded.sketch.isEmpty)
        XCTAssertEqual(loaded.undoSketch, drawn())
    }

    func testALaterSaveReplacesTheEarlierOne() throws {
        let store = FileSketchStore(url: dir.appendingPathComponent("Sketch.json"))
        try store.save(SketchArchive(sketch: Sketch()))
        try store.save(SketchArchive(sketch: drawn()))
        XCTAssertEqual(store.load()?.sketch, drawn())
    }

    func testMissingOrUnreadableFilesLoadAsNothing() throws {
        let url = dir.appendingPathComponent("Sketch.json")
        let store = FileSketchStore(url: url)
        XCTAssertNil(store.load())
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertNil(store.load())
    }

    func testOtherVersionsAreIgnored() throws {
        var archive = SketchArchive(sketch: drawn())
        archive.version = SketchArchive.currentVersion + 1
        XCTAssertNil(SketchArchive.decoded(from: try archive.encoded()))
    }

    func testAFullSketchSavesQuickly() throws {
        var s = Sketch()
        let size = CanvasSize(width: 400, height: 400)
        for i in 0..<Sketch.maximumPoints {
            s.movePen(dx: i % 2 == 0 ? 3 : -2, dy: i % 3 == 0 ? 2 : -1, in: size)
        }
        let store = FileSketchStore(url: dir.appendingPathComponent("Sketch.json"))
        let start = Date()
        try store.save(SketchArchive(sketch: s))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "this runs off the main actor, but should still be quick")
        XCTAssertEqual(store.load()?.sketch, s)
    }
}
