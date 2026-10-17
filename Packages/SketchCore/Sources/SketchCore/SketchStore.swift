import Foundation

/// What is saved when the app leaves the foreground: the drawing, and the
/// drawing a full clear just removed while Undo is still on offer.
public struct SketchArchive: Sendable, Equatable, Codable {
    /// Bumped when the format changes. Older or newer files are ignored rather
    /// than half read.
    public static let currentVersion = 1

    public var version: Int
    public var sketch: Sketch
    /// The drawing before the last full clear, while Undo is available.
    public var undoSketch: Sketch?

    public init(sketch: Sketch, undoSketch: Sketch? = nil) {
        self.version = Self.currentVersion
        self.sketch = sketch
        self.undoSketch = undoSketch
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Nil for data that isn't a readable archive of the current version.
    public static func decoded(from data: Data) -> SketchArchive? {
        guard let archive = try? JSONDecoder().decode(SketchArchive.self, from: data),
              archive.version == currentVersion else { return nil }
        return archive
    }
}

/// Where the drawing is kept between launches. Both calls may be slow (they
/// encode and touch the disk), so callers run them off the main actor.
public protocol SketchStore: Sendable {
    func save(_ archive: SketchArchive) throws
    func load() -> SketchArchive?
}

/// Keeps the archive in one JSON file, replaced atomically on each save so a
/// crash mid-write leaves the previous drawing in place.
public struct FileSketchStore: SketchStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `Application Support/Sketch.json` in the app's container.
    public static func applicationSupport() -> FileSketchStore {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return FileSketchStore(url: dir.appendingPathComponent("Sketch.json"))
    }

    public func save(_ archive: SketchArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try archive.encoded().write(to: url, options: .atomic)
    }

    public func load() -> SketchArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SketchArchive.decoded(from: data)
    }
}
