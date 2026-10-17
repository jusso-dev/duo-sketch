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

    init(foldService: any FoldStateService, sketch: Sketch = Sketch()) {
        self.foldService = foldService
        self.sketch = sketch
        self.posture = foldService.current
    }

    private var now: Double { ProcessInfo.processInfo.systemUptime }

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

    func beginTurn(_ axis: DialAxis, at angle: Double) {
        haptics.prepare()
        switch axis {
        case .horizontal: horizontalDial.begin(at: angle)
        case .vertical: verticalDial.begin(at: angle)
        }
    }

    func drag(_ axis: DialAxis, to angle: Double) {
        let step: DialStep
        switch axis {
        case .horizontal: step = horizontalDial.drag(to: angle)
        case .vertical: step = verticalDial.drag(to: angle)
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
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(ClearController.shakeDuration))
            withAnimation(.easeOut(duration: 0.25)) {
                _ = clearController.tick(at: now, sketch: &sketch)
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
