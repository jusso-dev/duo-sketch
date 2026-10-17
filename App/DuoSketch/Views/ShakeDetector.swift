import SwiftUI
import SketchCore

#if canImport(UIKit)
import UIKit

/// Catches device shakes in a small view controller that becomes first
/// responder, instead of overriding `UIWindow.motionEnded` in an extension.
/// That override replaced UIKit's own method for every window, including
/// system ones such as the share sheet, which Swift doesn't support.
///
/// Because this controller is only first responder while the board is in
/// front, shaking with the share sheet open no longer fades the drawing.
final class ShakeResponderController: UIViewController {
    var onShake: () -> Void = {}
    var clock: () -> Double
    private var debounce = ShakeDebounce()

    init(clock: @escaping () -> Double = ShakeResponderController.continuousSeconds()) {
        self.clock = clock
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        claimFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        claimFirstResponder()
    }

    /// Takes first responder back, unless something else (a presented sheet,
    /// a text field) has it.
    func claimFirstResponder() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil else { return }
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        if debounce.accept(at: clock()) { onShake() }
    }

    static func continuousSeconds() -> () -> Double {
        let origin = ContinuousClock.now
        return {
            let c = (ContinuousClock.now - origin).components
            return Double(c.seconds) + Double(c.attoseconds) * 1e-18
        }
    }
}

private struct ShakeReader: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeResponderController {
        let controller = ShakeResponderController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ controller: ShakeResponderController, context: Context) {
        controller.onShake = onShake
        controller.claimFirstResponder()
    }
}

extension View {
    /// Calls `action` when the user shakes the phone, at most once every 0.5 s.
    func onDeviceShake(perform action: @escaping () -> Void) -> some View {
        background(
            ShakeReader(onShake: action)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}
#else
extension View {
    func onDeviceShake(perform action: @escaping () -> Void) -> some View { self }
}
#endif
