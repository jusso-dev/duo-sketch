import Foundation

/// Drives the shake that clears the board.
///
/// - A fold clear (close and reopen) plays one full shake, then clears everything.
/// - A device shake fades the ink by a third. Three shakes clear it.
public struct ClearController: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        /// A full clear shake is playing.
        case shaking(startedAt: Double)
    }

    public static let shakeDuration = 0.6
    public static let fadePerShake = 1.0 / 3.0

    public private(set) var phase: Phase = .idle

    public init() {}

    public var isShaking: Bool { phase != .idle }

    /// Starts a full clear shake. Returns false if one is already playing.
    @discardableResult
    public mutating func beginShakeClear(at time: Double) -> Bool {
        guard phase == .idle else { return false }
        phase = .shaking(startedAt: time)
        return true
    }

    /// 0 to 1 through the shake, or nil when idle.
    public func progress(at time: Double) -> Double? {
        guard case .shaking(let start) = phase else { return nil }
        return min(max((time - start) / ClearController.shakeDuration, 0), 1)
    }

    /// Horizontal offset of the board during the shake, as a fraction of `amplitude`.
    /// A decaying wobble with three swings.
    public func shakeOffset(at time: Double, amplitude: Double = 14) -> Double {
        guard let p = progress(at: time) else { return 0 }
        return amplitude * (1 - p) * sin(p * 6 * .pi)
    }

    /// Advances the shake. When it finishes, the sketch is cleared and true is returned.
    @discardableResult
    public mutating func tick(at time: Double, sketch: inout Sketch) -> Bool {
        guard case .shaking(let start) = phase,
              time - start >= ClearController.shakeDuration - 1e-9 else { return false }
        sketch.clear()
        phase = .idle
        return true
    }

    /// Ends a full clear shake now, whatever the clock says: clears the sketch
    /// and returns to idle. Use this when the shake animation has finished, so a
    /// clock that lags behind the animation (for example one that pauses while
    /// the device sleeps) can never leave the board stuck in `.shaking`.
    /// Returns false when no shake was playing.
    @discardableResult
    public mutating func finishShakeClear(sketch: inout Sketch) -> Bool {
        guard isShaking else { return false }
        sketch.clear()
        phase = .idle
        return true
    }

    /// A device shake: fades the ink. Ignored while a full clear is playing.
    /// Returns true when the sketch is now empty.
    @discardableResult
    public func deviceShaken(sketch: inout Sketch) -> Bool {
        guard phase == .idle else { return sketch.isEmpty }
        return sketch.fade(by: ClearController.fadePerShake)
    }
}
