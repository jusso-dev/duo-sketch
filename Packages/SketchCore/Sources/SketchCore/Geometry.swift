/// A point in normalised canvas space: x and y run from 0 to 1, origin top left.
/// Storing normalised points keeps a drawing intact when the canvas changes size,
/// for example when iPhone Duo moves between the outer and inner display.
public struct Point: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let centre = Point(x: 0.5, y: 0.5)
}

/// Canvas size in points.
public struct CanvasSize: Sendable, Hashable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }
}

extension CanvasSize {
    /// The same aspect ratio, scaled so the longer side is `longSide`.
    /// Used for exports, so a drawing made on a tall or wide canvas isn't stretched.
    public func scaled(toLongSide longSide: Double) -> CanvasSize {
        let scale = longSide / max(width, height)
        return CanvasSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }

    public var aspectRatio: Double { width / height }
}
