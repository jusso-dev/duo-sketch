/// A rectangle in a view's coordinate space, in points. SketchCore's own type
/// so the layout rules below can be tested without UIKit.
public struct LayoutRect: Sendable, Equatable, CustomStringConvertible {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = max(width, 0)
        self.height = max(height, 0)
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var area: Double { width * height }

    /// True when the two overlap by more than an edge.
    public func intersects(_ other: LayoutRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    public var description: String { "(\(x), \(y), \(width) x \(height))" }
}

/// Keeps the board clear of the parts of the display that hardware reserves on
/// iPhone Duo, following Apple's guidance for the fold and the cameras:
///
/// - A *division* is the fold when the phone is partly open. Interactive
///   controls stay out of it. With the fold across the display (seated like a
///   laptop) the canvas goes on the upright top half and the dials on the half
///   resting on the table. With the fold down the middle (held like a book) the
///   canvas goes on the leading side and the dials on the trailing side, where
///   the right thumb is.
/// - An *occlusion* is a camera covering part of the display. Nothing the board
///   draws goes under it.
///
/// The app reads these regions with `GeometryProxy.reservedRegions(kind:)`
/// (iOS 27.1) and passes their frames in.
public enum FoldAwareLayout {
    public enum Axis: Sendable, Equatable {
        /// Canvas above, dials below (the fold runs across the display).
        case vertical
        /// Canvas leading, dials trailing (the fold runs down the display).
        case horizontal
    }

    public struct Split: Sendable, Equatable {
        public var canvas: LayoutRect
        public var controls: LayoutRect
        public var axis: Axis
    }

    /// The smallest part either side of the fold that is worth using. Below
    /// this the board ignores the fold rather than squash a dial.
    public static let minimumSide = 88.0

    /// Splits `bounds` around an active division. Nil when the division misses
    /// the bounds or would leave a side too small to use.
    public static func split(_ bounds: LayoutRect, around division: LayoutRect) -> Split? {
        guard bounds.intersects(division) else { return nil }
        if division.width >= division.height {
            let canvas = LayoutRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: division.minY - bounds.minY)
            let controls = LayoutRect(x: bounds.minX, y: division.maxY, width: bounds.width, height: bounds.maxY - division.maxY)
            guard canvas.height >= minimumSide, controls.height >= minimumSide else { return nil }
            return Split(canvas: canvas, controls: controls, axis: .vertical)
        } else {
            let canvas = LayoutRect(x: bounds.minX, y: bounds.minY, width: division.minX - bounds.minX, height: bounds.height)
            let controls = LayoutRect(x: division.maxX, y: bounds.minY, width: bounds.maxX - division.maxX, height: bounds.height)
            guard canvas.width >= minimumSide, controls.width >= minimumSide else { return nil }
            return Split(canvas: canvas, controls: controls, axis: .horizontal)
        }
    }

    /// `bounds` trimmed so it no longer overlaps any occlusion. Each occlusion is
    /// cut off along whichever edge keeps the most area.
    public static func avoiding(_ bounds: LayoutRect, occlusions: [LayoutRect]) -> LayoutRect {
        var rect = bounds
        for occlusion in occlusions where rect.intersects(occlusion) {
            let options = [
                LayoutRect(x: rect.minX, y: occlusion.maxY, width: rect.width, height: rect.maxY - occlusion.maxY),
                LayoutRect(x: rect.minX, y: rect.minY, width: rect.width, height: occlusion.minY - rect.minY),
                LayoutRect(x: occlusion.maxX, y: rect.minY, width: rect.maxX - occlusion.maxX, height: rect.height),
                LayoutRect(x: rect.minX, y: rect.minY, width: occlusion.minX - rect.minX, height: rect.height),
            ]
            rect = options.max { $0.area < $1.area } ?? rect
        }
        return rect
    }

    /// Dial size for a space, relative to it rather than to any one screen.
    /// Never below 88 pt, well over the 44 pt minimum touch target, and never
    /// so big that two dials and the wordmark don't fit side by side.
    public static func dialDiameter(width: Double, height: Double) -> Double {
        let preferred = min(width, height) * 0.25
        let fitsTwo = width / 2.6
        return min(max(min(preferred, fitsTwo), 88), 132)
    }

    /// Dial size for the controls side of a split.
    public static func dialDiameter(for split: Split) -> Double {
        let c = split.controls
        let across = split.axis == .vertical ? c.height * 0.8 : c.width * 0.8
        let along = split.axis == .vertical ? c.width / 2.6 : c.height / 2.6
        return min(max(min(across, along), 88), 140)
    }
}
