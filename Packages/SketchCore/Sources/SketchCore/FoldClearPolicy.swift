/// Decides when a fold gesture should clear the board.
///
/// Rule: the phone was closed for at least `minimumClosedDuration` seconds and is
/// now fully open. Passing through half open on the way is normal. Half open to
/// open without closing does nothing, and a quick wobble shut does nothing.
public struct FoldClearPolicy: Sendable, Equatable {
    public var minimumClosedDuration: Double
    private var closedAt: Double?
    private var leftClosedAt: Double?
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
            if !last.isClosed {
                closedAt = time
                leftClosedAt = nil
            }
            return false
        case .partiallyOpen:
            if last.isClosed { leftClosedAt = time }
            return false
        case .open:
            guard let start = closedAt else { return false }
            let end = leftClosedAt ?? time
            closedAt = nil
            leftClosedAt = nil
            return end - start >= minimumClosedDuration
        case .unavailable:
            closedAt = nil
            leftClosedAt = nil
            return false
        }
    }
}
