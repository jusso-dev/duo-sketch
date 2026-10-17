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
    /// Keeps the drawing between launches. Nil for demo launches and previews.
    @ObservationIgnored private let store: (any SketchStore)?

    init(
        foldService: any FoldStateService,
        sketch: Sketch = Sketch(),
        store: (any SketchStore)? = nil,
        clock: (@MainActor () -> Double)? = nil,
        sleep: (@Sendable (Double) async -> Void)? = nil
    ) {
        self.foldService = foldService
        self.sketch = sketch
        self.store = store
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
        // Drawing something new ends the chance to undo the last clear.
        if move.moved, canUndoClear { dropUndo() }
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
            let before = sketch
            let cleared = withAnimation(.easeOut(duration: 0.25)) {
                clearController.finishShakeClear(sketch: &sketch)
            }
            if cleared {
                announce("Board cleared")
                offerUndo(of: before)
            }
        }
    }

    /// Device shake. This is the clear gesture on phones without a hinge
    /// (`.unavailable`), and it works on iPhone Duo too.
    func deviceShaken() {
        let hadInk = !sketch.isEmpty
        let empty = withAnimation(.easeOut(duration: 0.3)) {
            clearController.deviceShaken(sketch: &sketch)
        }
        if hadInk, !clearController.isShaking { announce(empty ? "Board cleared" : "Drawing faded") }
        haptics.bump()
    }

    // MARK: Undo clear

    /// How long Undo stays available after a full clear, in seconds.
    nonisolated static let undoWindow = 6.0

    /// True for a few seconds after a full clear (fold or Clear button), until
    /// the pen draws again. Shutting the phone briefly to check something and
    /// reopening it no longer loses the drawing for good.
    private(set) var canUndoClear = false
    @ObservationIgnored private var clearedSketch: Sketch?
    @ObservationIgnored private(set) var undoExpiryTask: Task<Void, Never>?

    private func offerUndo(of previous: Sketch) {
        clearedSketch = previous
        canUndoClear = true
        undoExpiryTask?.cancel()
        let sleep = self.sleep
        undoExpiryTask = Task { @MainActor [weak self] in
            await sleep(SketchViewModel.undoWindow)
            guard !Task.isCancelled else { return }
            self?.dropUndo()
        }
    }

    private func dropUndo() {
        undoExpiryTask?.cancel()
        undoExpiryTask = nil
        clearedSketch = nil
        if canUndoClear { canUndoClear = false }
    }

    /// Puts back the drawing the last full clear removed.
    func undoClear() {
        guard canUndoClear, let previous = clearedSketch, !clearController.isShaking else { return }
        withAnimation(.easeOut(duration: 0.25)) { sketch = previous }
        dropUndo()
        announce("Drawing restored")
    }

    // MARK: Saving

    /// The last save, or the restore it chains after. Tests await it.
    @ObservationIgnored private(set) var saveTask: Task<Void, Never>?
    @ObservationIgnored private var lastSaved: SketchArchive?

    /// Saves when the scene leaves the foreground. iOS can end a backgrounded
    /// app at any time without telling it, so this is the last safe moment.
    func scenePhaseChanged(to phase: ScenePhase) {
        guard phase != .active else { return }
        save()
    }

    /// Takes a copy of the drawing (copy on write, so this is cheap) and
    /// encodes and writes it off the main actor. Saves run one after another,
    /// so a slow earlier save can't overwrite a newer one.
    func save() {
        guard let store else { return }
        let archive = SketchArchive(sketch: sketch, undoSketch: canUndoClear ? clearedSketch : nil)
        guard archive != lastSaved else { return }
        lastSaved = archive
        let previous = saveTask
        saveTask = Task.detached(priority: .utility) {
            await previous?.value
            try? store.save(archive)
        }
    }

    /// Puts back the drawing saved last time, unless the pen has already drawn
    /// something since launch. A clear that still had Undo on offer when the
    /// app left the foreground offers it again.
    func restore() async {
        guard let store else { return }
        let archive = await Task.detached(priority: .userInitiated) { store.load() }.value
        guard let archive, sketch.isEmpty, !canUndoClear else { return }
        sketch = archive.sketch
        lastSaved = archive
        if let undo = archive.undoSketch, !undo.isEmpty { offerUndo(of: undo) }
    }

    // MARK: Accessibility

    /// Spoken by VoiceOver when the board clears or fades. Injected for tests.
    @ObservationIgnored var announce: @MainActor (String) -> Void = { message in
        AccessibilityNotification.Announcement(message).post()
    }

    /// The pen's position along one dial's axis, for VoiceOver.
    func accessibilityValue(for axis: DialAxis) -> String {
        switch axis {
        case .horizontal: return "Pen \(Self.percent(sketch.pen.x)) percent across"
        case .vertical: return "Pen \(Self.percent(sketch.pen.y)) percent down"
        }
    }

    private static func percent(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }
}
