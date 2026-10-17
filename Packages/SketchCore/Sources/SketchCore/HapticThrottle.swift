/// Limits how often detent ticks fire so fast spins don't flood the Taptic Engine.
public struct HapticThrottle: Sendable, Equatable {
    public var maxPerSecond: Double
    private var lastFire: Double?

    public init(maxPerSecond: Double = 30) {
        self.maxPerSecond = maxPerSecond
    }

    /// Returns true if a tick may fire at `time` (seconds), and records it.
    public mutating func shouldFire(at time: Double) -> Bool {
        let interval = 1 / maxPerSecond
        if let last = lastFire, time - last < interval { return false }
        lastFire = time
        return true
    }
}
