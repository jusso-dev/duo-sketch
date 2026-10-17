/// Decides when a fold gesture should clear the board.
///
/// Rule: a transition through `.closed` back to `.partiallyOpen` or `.open`
/// clears the board, provided the phone stayed closed for at least
/// `minimumClosedDuration` seconds. Partly open to open without closing does
/// nothing, and a quick wobble shut does nothing.
public struct FoldClearPolicy: Sendable, Equatable {
    public var minimumClosedDuration: Double
    private var closedAt: Double?
    private var last: FoldPosture = .unavailable

    public init(minimumClosedDuration: Double = 0.4) {
        self.minimumClosedDuration = minimumClosedDuration
    }

    /// Feed every fold change with a monotonic timestamp in seconds.
    /// Returns true when the board should shake and clear.
    public mutating func handle(_ state: FoldPosture, at time: Double) -> Bool {
        defer { last = state }
        switch state {
        case .closed:
            if !last.isClosed { closedAt = time }
            return false
        case .partiallyOpen, .open:
            guard last.isClosed, let start = closedAt else { return false }
            closedAt = nil
            return time - start >= minimumClosedDuration
        case .unavailable:
            closedAt = nil
            return false
        }
    }
}
