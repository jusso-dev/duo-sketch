/// Limits how often detent ticks fire so fast spins don't flood the Taptic Engine.
public struct HapticThrottle: Sendable, Equatable {
    /// Between 1 and `ceiling`. Infinity gave a zero interval, and zero used to make the interval infinite (one tick, then
    /// silence), and negative or NaN values let every tick through.
    public var maxPerSecond: Double {
        didSet { maxPerSecond = HapticThrottle.clamped(maxPerSecond) }
    }
    private var lastFire: Double?

    public init(maxPerSecond: Double = 30) {
        self.maxPerSecond = HapticThrottle.clamped(maxPerSecond)
    }

    /// The fastest the Taptic Engine is ever asked to tick.
    public static let ceiling = 1000.0

    static func clamped(_ value: Double) -> Double {
        value.isNaN ? 1 : min(max(value, 1), ceiling)
    }

    /// Returns true if a tick may fire at `time` (seconds), and records it.
    public mutating func shouldFire(at time: Double) -> Bool {
        let interval = 1 / maxPerSecond
        if let last = lastFire, time - last < interval { return false }
        lastFire = time
        return true
    }
}
