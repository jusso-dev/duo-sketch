import SwiftUI
import Observation
import SketchCore

enum DialAxis {
    case horizontal
    case vertical
}

@MainActor
@Observable
final class SketchViewModel {
    var sketch = Sketch()
    var canvasSize = CanvasSize(width: 320, height: 320)
    private(set) var horizontalDial = Dial()
    private(set) var verticalDial = Dial()
    private(set) var posture: FoldPosture = .unavailable
    private(set) var clearController = ClearController()
    /// Bumped each time a shake clear starts; drives the board animation.
    private(set) var shakeTrigger = 0

    var hapticsEnabled: Bool {
        get { haptics.isEnabled }
        set { haptics.isEnabled = newValue }
    }

    @ObservationIgnored let foldService: any FoldStateService
    @ObservationIgnored private let haptics = Haptics()
    @ObservationIgnored private var throttle = HapticThrottle()
    @ObservationIgnored private var foldPolicy = FoldClearPolicy()
    /// Seconds on one monotonic clock, used for fold timing and haptic throttling.
    @ObservationIgnored private let clock: @MainActor () -> Double
    /// Waits out the shake animation. Injected so tests don't sleep for real.
    @ObservationIgnored private let sleep: @Sendable (Double) async -> Void
    /// The task that finishes the current shake clear. Tests await it.
    @ObservationIgnored private(set) var shakeTask: Task<Void, Never>?

    init(
        foldService: any FoldStateService,
        sketch: Sketch = Sketch(),
        clock: (@MainActor () -> Double)? = nil,
        sleep: (@Sendable (Double) async -> Void)? = nil
    ) {
        self.foldService = foldService
        self.sketch = sketch
        self.posture = foldService.current
        self.clock = clock ?? SketchViewModel.continuousSeconds()
        self.sleep = sleep ?? { seconds in _ = try? await Task.sleep(for: .seconds(seconds)) }
    }

    private var now: Double { clock() }

    /// Seconds since this model was made, on `ContinuousClock`: the same clock
    /// `Task.sleep` uses, so the shake timer and the fold timer agree.
    private static func continuousSeconds() -> @MainActor () -> Double {
        let origin = ContinuousClock.now
        return {
            let c = (ContinuousClock.now - origin).components
            return Double(c.seconds) + Double(c.attoseconds) * 1e-18
        }
    }

    // MARK: Fold

    /// Runs for the life of the view (`.task`).
    func observeFold() async {
        for await posture in foldService.updates {
            handle(posture)
        }
    }

    func handle(_ posture: FoldPosture) {
        self.posture = posture
        if foldPolicy.handle(posture, at: now) {
            beginShakeClear()
        }
    }

    // MARK: Dials

    func dial(_ axis: DialAxis) -> Dial {
        axis == .horizontal ? horizontalDial : verticalDial
    }

    func beginTurn(_ axis: DialAxis) {
        haptics.prepare()
        switch axis {
        case .horizontal: horizontalDial.end()
        case .vertical: verticalDial.end()
        }
    }

    /// A finger at `x`, `y` relative to the dial centre, on a dial of `radius`.
    /// Touches near the centre are ignored (see `Dial.deadZoneFraction`).
    func touch(_ axis: DialAxis, x: Double, y: Double, radius: Double) {
        let step: DialStep
        switch axis {
        case .horizontal: step = horizontalDial.drag(touchX: x, y: y, radius: radius)
        case .vertical: step = verticalDial.drag(touchX: x, y: y, radius: radius)
        }
        apply(step, axis: axis)
    }

    func endTurn(_ axis: DialAxis) {
        switch axis {
        case .horizontal: horizontalDial.end()
        case .vertical: verticalDial.end()
        }
    }

    /// Relative turn, used by VoiceOver adjustable actions and tests.
    func turn(_ axis: DialAxis, by degrees: Double) {
        let step: DialStep
        switch axis {
        case .horizontal: step = horizontalDial.rotate(by: degrees)
        case .vertical: step = verticalDial.rotate(by: degrees)
        }
        apply(step, axis: axis)
    }

    private func apply(_ step: DialStep, axis: DialAxis) {
        guard step != .none, !clearController.isShaking else { return }
        let move = axis == .horizontal
            ? sketch.movePen(dx: step.distance, dy: 0, in: canvasSize)
            : sketch.movePen(dx: 0, dy: step.distance, in: canvasSize)
        if move.bumpedEdge {
            haptics.bump()
        } else if step.detentsCrossed > 0, throttle.shouldFire(at: now) {
            haptics.tick()
        }
    }

    // MARK: Clearing

    func beginShakeClear() {
        guard !sketch.isEmpty, clearController.beginShakeClear(at: now) else { return }
        shakeTrigger += 1
        haptics.shake()
        let sleep = self.sleep
        shakeTask = Task { @MainActor in
            await sleep(ClearController.shakeDuration)
            // Finish unconditionally. Re-checking the time here used to leave the
            // board stuck in `.shaking` whenever the clock lagged the sleep.
            withAnimation(.easeOut(duration: 0.25)) {
                _ = clearController.finishShakeClear(sketch: &sketch)
            }
        }
    }

    /// Device shake. This is the clear gesture on phones without a hinge
    /// (`.unavailable`), and it works on iPhone Duo too.
    func deviceShaken() {
        withAnimation(.easeOut(duration: 0.3)) {
            _ = clearController.deviceShaken(sketch: &sketch)
        }
        haptics.bump()
    }
}
