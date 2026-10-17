// Fold state seam for Duo Sketch.
//
// Everything about the hinge lives in this one file so it is easy to keep in
// line with sibling apps. Core logic only ever sees `FoldState` and the
// `FoldStateService` protocol.
//
// On device, the app feeds readings from Apple's public SwiftUI hinge API
// (iOS 27.1) into `HingeFoldStateService`:
// - DeviceHinge (angle, status):
//   https://developer.apple.com/documentation/swiftui/devicehinge
// - DeviceHinge.Status (.closed, .partiallyOpen, .fullyOpen):
//   https://developer.apple.com/documentation/swiftui/devicehinge/status-swift.struct
// - DeviceHingeContext.hinge (nil on devices without a hinge):
//   https://developer.apple.com/documentation/swiftui/devicehingecontext
// - View.onHingeChange(isEnabled:_:):
//   https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)
//
// This file does not import SwiftUI. `HingeStatus` mirrors `DeviceHinge.Status`
// so the mapping can be tested on Linux.

/// The pose of the device, as far as the app cares.
public enum FoldState: Sendable, Equatable, CustomStringConvertible {
    /// Folded shut. The app is on the outer display.
    case closed
    /// Partly open. `angle` is the hinge angle in degrees (0 closed, 180 flat).
    case halfOpen(angle: Double)
    /// Open as far as the device allows. The app is on the inner display.
    case open
    /// No hinge, or no reading yet. Treat as a normal iPhone.
    case unknown

    public var isClosed: Bool { self == .closed }
    public var isOpen: Bool { self == .open }
    public var isHalfOpen: Bool {
        if case .halfOpen = self { return true }
        return false
    }

    /// Hinge angle in degrees when known.
    public var angle: Double? {
        switch self {
        case .closed: return 0
        case .halfOpen(let angle): return angle
        case .open: return 180
        case .unknown: return nil
        }
    }

    public var description: String {
        switch self {
        case .closed: return "closed"
        case .halfOpen(let angle): return "halfOpen(\(Int(angle.rounded()))°)"
        case .open: return "open"
        case .unknown: return "unknown"
        }
    }
}

/// Mirrors `DeviceHinge.Status` from SwiftUI.
public enum HingeStatus: Sendable, Equatable {
    case closed
    case partiallyOpen
    case fullyOpen
}

/// A single reading from the hinge, in plain values.
public struct HingeReading: Sendable, Equatable {
    public var status: HingeStatus
    /// Hinge angle in degrees.
    public var angleDegrees: Double

    public init(status: HingeStatus, angleDegrees: Double) {
        self.status = status
        self.angleDegrees = angleDegrees
    }
}

extension FoldState {
    /// Maps a hinge reading to a fold state. `nil` means the device has no hinge.
    ///
    /// The system decides the status from angle and orientation, so the status
    /// wins. The angle is clamped to 0...180 and only kept for `halfOpen`.
    public init(reading: HingeReading?) {
        guard let reading else {
            self = .unknown
            return
        }
        switch reading.status {
        case .closed:
            self = .closed
        case .fullyOpen:
            self = .open
        case .partiallyOpen:
            let angle = reading.angleDegrees.isFinite ? reading.angleDegrees : 90
            self = .halfOpen(angle: min(max(angle, 0), 180))
        }
    }
}

/// Handle returned by `FoldStateService.observe`. Call `cancel()` or drop it to stop.
@MainActor
public final class FoldObservation {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    isolated deinit {
        cancel()
    }
}

/// Source of fold state. Implementations: `HingeFoldStateService` (real hinge,
/// fed by the app), `NoHingeFoldStateService` (other iPhones) and
/// `MockFoldStateService` (tests, previews and the simulator debug menu).
@MainActor
public protocol FoldStateService: AnyObject {
    /// The latest known state.
    var current: FoldState { get }
    /// False on devices without a hinge.
    var isHingeAvailable: Bool { get }
    /// Calls `handler` on every change (not with the current value).
    /// Keep the returned observation alive for as long as you want updates.
    func observe(_ handler: @escaping @MainActor (FoldState) -> Void) -> FoldObservation
}

/// Shared plumbing for services that push state changes.
@MainActor
open class BaseFoldStateService: FoldStateService {
    public private(set) var current: FoldState
    open var isHingeAvailable: Bool { true }

    private var handlers: [Int: @MainActor (FoldState) -> Void] = [:]
    private var nextID = 0

    public init(initial: FoldState) {
        self.current = initial
    }

    public func observe(_ handler: @escaping @MainActor (FoldState) -> Void) -> FoldObservation {
        let id = nextID
        nextID += 1
        handlers[id] = handler
        return FoldObservation { [weak self] in
            self?.handlers[id] = nil
        }
    }

    /// Publishes a new state. Repeated identical states are ignored.
    public func publish(_ state: FoldState) {
        guard state != current else { return }
        current = state
        for key in handlers.keys.sorted() {
            handlers[key]?(state)
        }
    }

    var observerCount: Int { handlers.count }
}

/// Real hinge. The app calls `update(reading:)` from `onHingeChange`.
@MainActor
public final class HingeFoldStateService: BaseFoldStateService {
    public private(set) var hasHinge: Bool = false
    public override var isHingeAvailable: Bool { hasHinge }

    public init() {
        super.init(initial: .unknown)
    }

    public func update(reading: HingeReading?) {
        hasHinge = reading != nil
        publish(FoldState(reading: reading))
    }
}

/// Fallback for every iPhone without a hinge. Always `.unknown`.
@MainActor
public final class NoHingeFoldStateService: BaseFoldStateService {
    public override var isHingeAvailable: Bool { false }

    public init() {
        super.init(initial: .unknown)
    }
}

/// Scriptable service for tests, SwiftUI previews and the simulator debug menu.
@MainActor
public final class MockFoldStateService: BaseFoldStateService {
    public var hingeAvailable: Bool
    public override var isHingeAvailable: Bool { hingeAvailable }

    public init(initial: FoldState = .open, hingeAvailable: Bool = true) {
        self.hingeAvailable = hingeAvailable
        super.init(initial: initial)
    }

    /// Sets the state now.
    public func send(_ state: FoldState) {
        publish(state)
    }

    /// Sets the state from a hinge reading, as the real service would.
    public func send(reading: HingeReading?) {
        hingeAvailable = reading != nil
        publish(FoldState(reading: reading))
    }

    /// Plays a sequence of states in order, synchronously.
    public func play(_ states: [FoldState]) {
        states.forEach(publish)
    }

    /// Common gesture: close the phone and open it again.
    public func closeAndReopen() {
        play([.halfOpen(angle: 60), .closed, .halfOpen(angle: 60), .open])
    }
}
