/// Limits how often detent ticks fire so fast spins don't flood the Taptic Engine.
public struct HapticThrottle: Sendable, Equatable {
    /// At least 1. Zero used to make the interval infinite (one tick, then
    /// silence), and negative or NaN values let every tick through.
    public var maxPerSecond: Double {
        didSet { maxPerSecond = HapticThrottle.clamped(maxPerSecond) }
    }
    private var lastFire: Double?

    public init(maxPerSecond: Double = 30) {
        self.maxPerSecond = HapticThrottle.clamped(maxPerSecond)
    }

    static func clamped(_ value: Double) -> Double {
        value.isNaN ? 1 : max(value, 1)
    }

    /// Returns true if a tick may fire at `time` (seconds), and records it.
    public mutating func shouldFire(at time: Double) -> Bool {
        let interval = 1 / maxPerSecond
        if let last = lastFire, time - last < interval { return false }
        lastFire = time
        return true
    }
}
