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
