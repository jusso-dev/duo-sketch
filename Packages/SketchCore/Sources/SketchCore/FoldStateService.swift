// Fold state seam for Duo Sketch.
//
// Everything about the hinge lives in this one file. The shape matches the
// shared Duo app contract used by jusso-dev/duo-fortune-ball and
// jusso-dev/duo-pocket-pet: FoldPosture, FoldStateService with `current` and
// `updates` (current first, then changes), UnavailableFoldStateService, and
// MockFoldStateService(initial:) with send/play/history/openingScript.
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

import Synchronization

/// The pose of the device, as far as the app cares.
public enum FoldPosture: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// Folded shut. The app is on the outer display.
    case closed
    /// Partly open. Hinge angle in degrees, 0 closed to 180 flat.
    case partiallyOpen(angleDegrees: Double)
    /// Open as far as the device allows. The app is on the inner display.
    case open
    /// No hinge (any other iPhone, or iOS earlier than 27.1). Use the standard layout.
    case unavailable

    /// True when the device reports a hinge at all.
    public var hasHinge: Bool { self != .unavailable }

    /// How far open the device is, from 0 (closed) to 1 (open).
    public func openFraction(fullOpenDegrees: Double = 180) -> Double {
        switch self {
        case .closed:
            return 0
        case .open, .unavailable:
            return 1
        case .partiallyOpen(let degrees):
            guard fullOpenDegrees > 0, degrees.isFinite else { return 0 }
            return min(max(degrees / fullOpenDegrees, 0), 1)
        }
    }

    /// Below this partial angle a phone that has just closed still counts as
    /// closed. Shared by `FoldClearPolicy` and `BoardLayout`.
    public static let reopenAngleDegrees = 20.0

    public var isClosed: Bool { self == .closed }
    public var isOpen: Bool { self == .open }
    public var isPartiallyOpen: Bool {
        if case .partiallyOpen = self { return true }
        return false
    }

    /// Hinge angle in degrees when there is a hinge.
    public var angleDegrees: Double? {
        switch self {
        case .closed: return 0
        case .partiallyOpen(let angle): return angle
        case .open: return 180
        case .unavailable: return nil
        }
    }

    public var description: String {
        switch self {
        case .closed: return "closed"
        case .partiallyOpen(let angle): return "partiallyOpen(\(Int(angle.rounded()))°)"
        case .open: return "open"
        case .unavailable: return "unavailable"
        }
    }
}

/// Mirrors `DeviceHinge.Status` from SwiftUI.
public enum HingeStatus: Sendable, Equatable {
    case closed
    case partiallyOpen
    case fullyOpen
}

/// A platform-free copy of one hinge reading.
public struct HingeReading: Sendable, Equatable {
    public var status: HingeStatus
    /// Hinge angle in degrees.
    public var angleDegrees: Double

    public init(status: HingeStatus, angleDegrees: Double) {
        self.status = status
        self.angleDegrees = angleDegrees
    }
}

extension FoldPosture {
    /// Maps a hinge reading to a posture. `nil` means the device has no hinge.
    /// The system decides the status from angle and orientation, so the status
    /// wins. The angle is clamped to 0...180.
    public init(reading: HingeReading?) {
        guard let reading else {
            self = .unavailable
            return
        }
        switch reading.status {
        case .closed:
            self = .closed
        case .fullyOpen:
            self = .open
        case .partiallyOpen:
            let angle = reading.angleDegrees.isFinite ? reading.angleDegrees : 90
            self = .partiallyOpen(angleDegrees: min(max(angle, 0), 180))
        }
    }
}

/// Source of fold posture.
///
/// `updates` returns a new stream on every access. It yields `current` first,
/// then every change. Duplicate postures are never delivered.
public protocol FoldStateService: AnyObject, Sendable {
    var current: FoldPosture { get }
    var updates: AsyncStream<FoldPosture> { get }
}

extension FoldStateService {
    /// False on devices without a hinge.
    public var isHingeAvailable: Bool { current != .unavailable }
}

/// Thread safe fan-out used by every service below.
public final class FoldBroadcaster: Sendable {
    private struct State {
        var current: FoldPosture
        var continuations: [Int: AsyncStream<FoldPosture>.Continuation] = [:]
        var nextID = 0
    }

    private let state: Mutex<State>

    public init(initial: FoldPosture) {
        state = Mutex(State(current: initial))
    }

    public var current: FoldPosture {
        state.withLock { $0.current }
    }

    public var subscriberCount: Int {
        state.withLock { $0.continuations.count }
    }

    public func stream() -> AsyncStream<FoldPosture> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let id = state.withLock { s in
                let id = s.nextID
                s.nextID += 1
                s.continuations[id] = continuation
                continuation.yield(s.current)
                return id
            }
            continuation.onTermination = { [weak self] _ in
                _ = self?.state.withLock { $0.continuations.removeValue(forKey: id) }
            }
        }
    }

    /// Publishes a posture. Returns false if it equals the current one.
    @discardableResult
    public func publish(_ posture: FoldPosture) -> Bool {
        let targets: [AsyncStream<FoldPosture>.Continuation]? = state.withLock { s in
            guard s.current != posture else { return nil }
            s.current = posture
            return s.continuations.keys.sorted().compactMap { s.continuations[$0] }
        }
        guard let targets else { return false }
        targets.forEach { $0.yield(posture) }
        return true
    }

    /// Ends every open stream.
    public func finish() {
        let all = state.withLock { s in
            defer { s.continuations = [:] }
            return Array(s.continuations.values)
        }
        all.forEach { $0.finish() }
    }
}

/// Real hinge. The app calls `update(reading:)` from `onHingeChange`.
/// Partly open updates are only published when the angle moves by at least
/// `angleThreshold` degrees, so small wobbles do not flood the UI.
public final class HingeFoldStateService: FoldStateService {
    public let angleThreshold: Double
    private let broadcaster = FoldBroadcaster(initial: .unavailable)

    public init(angleThreshold: Double = 2) {
        self.angleThreshold = angleThreshold
    }

    public var current: FoldPosture { broadcaster.current }
    public var updates: AsyncStream<FoldPosture> { broadcaster.stream() }

    public func update(reading: HingeReading?) {
        let next = FoldPosture(reading: reading)
        if case .partiallyOpen(let newAngle) = next,
           case .partiallyOpen(let oldAngle) = current,
           abs(newAngle - oldAngle) < angleThreshold {
            return
        }
        broadcaster.publish(next)
    }
}

/// Fixed posture. Use `.unavailable` on every iPhone without a hinge, on iOS
/// earlier than 27.1, and in previews.
public final class StaticFoldStateService: FoldStateService {
    public let current: FoldPosture

    public init(_ posture: FoldPosture = .unavailable) {
        current = posture
    }

    public var updates: AsyncStream<FoldPosture> {
        let posture = current
        return AsyncStream { continuation in
            continuation.yield(posture)
            continuation.finish()
        }
    }
}

/// The fallback for iPhones without a hinge. Always `.unavailable`.
/// Same name as in the sibling apps.
public typealias UnavailableFoldStateService = StaticFoldStateService

/// Scriptable service for tests, SwiftUI previews and the simulator debug menu.
public final class MockFoldStateService: FoldStateService {
    private let broadcaster: FoldBroadcaster
    private let log: Mutex<[FoldPosture]>

    public init(initial: FoldPosture = .closed) {
        broadcaster = FoldBroadcaster(initial: initial)
        log = Mutex([initial])
    }

    /// Every posture sent, in order, including the initial one.
    public var history: [FoldPosture] { log.withLock { $0 } }

    /// A typical open gesture: closed, a few partial angles, then open.
    public static let openingScript: [FoldPosture] = [
        .closed,
        .partiallyOpen(angleDegrees: 30),
        .partiallyOpen(angleDegrees: 90),
        .partiallyOpen(angleDegrees: 150),
        .open
    ]

    public var current: FoldPosture { broadcaster.current }
    public var updates: AsyncStream<FoldPosture> { broadcaster.stream() }
    public var subscriberCount: Int { broadcaster.subscriberCount }

    /// Sets the posture now. Returns false when it equals the current one.
    @discardableResult
    public func send(_ posture: FoldPosture) -> Bool {
        let changed = broadcaster.publish(posture)
        if changed { log.withLock { $0.append(posture) } }
        return changed
    }

    /// Sets the posture from a hinge reading, as the real service would.
    public func send(reading: HingeReading?) {
        send(FoldPosture(reading: reading))
    }

    /// Plays a sequence of postures in order.
    public func play(_ postures: [FoldPosture]) {
        postures.forEach { send($0) }
    }

    /// Common gesture: close the phone and open it again.
    public func closeAndReopen() {
        play([.partiallyOpen(angleDegrees: 60), .closed, .partiallyOpen(angleDegrees: 60), .open])
    }

    /// Ends all open `updates` streams.
    public func finish() {
        broadcaster.finish()
    }
}
