import Foundation

/// Settings for a dial.
public struct DialConfig: Sendable, Equatable {
    /// How far the pen travels, in canvas points, for one full turn.
    public var pointsPerTurn: Double
    /// Haptic detents per full turn.
    public var detentsPerTurn: Int

    public init(pointsPerTurn: Double = 120, detentsPerTurn: Int = 24) {
        self.pointsPerTurn = pointsPerTurn
        self.detentsPerTurn = max(detentsPerTurn, 1)
    }

    public static let standard = DialConfig()
}

/// The result of turning a dial a little.
public struct DialStep: Sendable, Equatable {
    /// Rotation in degrees. Positive is clockwise.
    public var degrees: Double
    /// Pen travel in canvas points. Positive for clockwise.
    public var distance: Double
    /// Detents crossed during this step, regardless of direction.
    public var detentsCrossed: Int

    public static let none = DialStep(degrees: 0, distance: 0, detentsCrossed: 0)
}

/// A rotary control. Feed it absolute finger angles from a drag gesture
/// (`drag(to:)`) or relative rotation (`rotate(by:)`) and it reports pen travel
/// and detent crossings.
public struct Dial: Sendable, Equatable {
    public var config: DialConfig
    /// Total rotation since creation, in degrees. Positive is clockwise.
    public private(set) var totalDegrees: Double = 0
    private var lastAngle: Double?
    /// Last touch position fed to `drag(touchX:y:radius:)`, relative to the centre.
    private var lastTouch: Point?

    public init(config: DialConfig = .standard) {
        self.config = config
    }

    /// Visual rotation of the dial cap, 0 to 360.
    public var capAngle: Double {
        let a = totalDegrees.truncatingRemainder(dividingBy: 360)
        return a < 0 ? a + 360 : a
    }

    /// Sets the starting angle for `drag(to:)`. Internal: the app starts turns
    /// with `drag(touchX:y:radius:)`, which handles the dead zone.
    mutating func begin(at angleDegrees: Double) {
        lastAngle = angleDegrees
    }

    /// Absolute finger angle in degrees (screen convention, clockwise positive).
    /// Handles the jump across 0/360 by taking the shortest path.
    mutating func drag(to angleDegrees: Double) -> DialStep {
        guard let last = lastAngle else {
            lastAngle = angleDegrees
            return .none
        }
        lastAngle = angleDegrees
        return rotate(by: Dial.shortestDelta(from: last, to: angleDegrees))
    }

    /// Touches closer to the centre than this fraction of the dial's radius are
    /// ignored. Near the centre a 1 pt wobble can swing the finger angle by up to
    /// 180 degrees, which would jump the pen by half a turn.
    public static let deadZoneFraction = 0.36

    /// Feeds a touch at `x`, `y` relative to the dial centre (screen points, y
    /// down) on a dial of `radius`. Inside the dead zone the touch is ignored and
    /// the dial lets go of its last angle, so leaving the dead zone starts a fresh
    /// turn from wherever the finger comes out instead of jumping to it.
    public mutating func drag(touchX x: Double, y: Double, radius: Double) -> DialStep {
        guard x.isFinite, y.isFinite, radius > 0 else { return .none }
        defer { lastTouch = Point(x: x, y: y) }
        guard (x * x + y * y).squareRoot() >= radius * Dial.deadZoneFraction else {
            lastAngle = nil
            return .none
        }
        // A real drag moves a little between samples. A touch that lands more
        // than a radius away from the last one is a new touch whose start we
        // missed (the old drag was cancelled without an end), so start afresh
        // instead of jumping the pen by up to half a turn.
        if let last = lastTouch {
            let dx = x - last.x, dy = y - last.y
            if (dx * dx + dy * dy).squareRoot() > radius {
                lastAngle = nil
            }
        }
        return drag(to: atan2(y, x) * 180 / .pi)
    }

    public mutating func end() {
        lastAngle = nil
        lastTouch = nil
    }

    public mutating func rotate(by degrees: Double) -> DialStep {
        guard degrees.isFinite, degrees != 0 else { return .none }
        let step = 360 / Double(config.detentsPerTurn)
        let before = (totalDegrees / step).rounded(.down)
        totalDegrees += degrees
        let after = (totalDegrees / step).rounded(.down)
        return DialStep(
            degrees: degrees,
            distance: degrees / 360 * config.pointsPerTurn,
            detentsCrossed: Int(abs(after - before))
        )
    }

    static func shortestDelta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
