/// Decides when a fold gesture should clear the board.
///
/// Rule: a transition through `.closed` back to `.open`, or to `.partiallyOpen`
/// at `reopenAngleDegrees` or more, clears the board, provided the phone stayed
/// closed for at least `minimumClosedDuration` seconds. Partly open to open
/// without closing does nothing, and a quick wobble shut does nothing.
///
/// Hysteresis: once closed, a small partial angle (below `reopenAngleDegrees`)
/// still counts as closed. A hinge settling after it shuts, or a phone squeezed
/// in a pocket, reports a degree or two without anyone opening it.
public struct FoldClearPolicy: Sendable, Equatable {
    public var minimumClosedDuration: Double
    /// Below this partial angle a closed phone is still treated as closed.
    public var reopenAngleDegrees: Double
    private var closedAt: Double?
    private var isShut = false

    public init(minimumClosedDuration: Double = 0.4, reopenAngleDegrees: Double = FoldPosture.reopenAngleDegrees) {
        self.minimumClosedDuration = minimumClosedDuration
        self.reopenAngleDegrees = reopenAngleDegrees
    }

    /// Feed every fold change with a monotonic timestamp in seconds.
    /// Returns true when the board should shake and clear.
    public mutating func handle(_ state: FoldPosture, at time: Double) -> Bool {
        switch state {
        case .closed:
            if !isShut {
                isShut = true
                closedAt = time
            }
            return false
        case .partiallyOpen(let angle) where isShut && !(angle >= reopenAngleDegrees):
            // Still closed for this rule (also covers a NaN angle).
            return false
        case .partiallyOpen, .open:
            guard isShut, let start = closedAt else { return false }
            isShut = false
            closedAt = nil
            // Allow for floating point error, so exactly the minimum counts.
            return time - start >= minimumClosedDuration - 1e-9
        case .unavailable:
            isShut = false
            closedAt = nil
            return false
        }
    }
}
