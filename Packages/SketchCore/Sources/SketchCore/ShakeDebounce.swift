/// Drops device shakes that arrive too soon after the last one. One rough
/// shake can deliver more than one motion event.
public struct ShakeDebounce: Sendable, Equatable {
    public var minimumInterval: Double
    private var lastAccepted: Double?

    public init(minimumInterval: Double = 0.5) {
        self.minimumInterval = max(minimumInterval, 0)
    }

    /// Returns true when a shake at `time` (seconds, monotonic) should count.
    public mutating func accept(at time: Double) -> Bool {
        guard time.isFinite else { return false }
        if let last = lastAccepted, time - last < minimumInterval, time >= last {
            return false
        }
        lastAccepted = time
        return true
    }
}
