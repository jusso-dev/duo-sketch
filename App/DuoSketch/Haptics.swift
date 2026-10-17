#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over the system impact generators.
@MainActor
final class Haptics {
    var isEnabled = true

    #if canImport(UIKit)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    func prepare() {
        #if canImport(UIKit)
        light.prepare()
        medium.prepare()
        #endif
    }

    /// One dial detent.
    func tick() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        light.impactOccurred(intensity: 0.55)
        #endif
    }

    /// The pen has reached an edge.
    func bump() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        medium.impactOccurred()
        #endif
    }

    /// The board is shaking clear.
    func shake() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        rigid.impactOccurred(intensity: 1)
        Task { @MainActor in
            for intensity in [0.8, 0.6, 0.4] {
                try? await Task.sleep(for: .milliseconds(110))
                rigid.impactOccurred(intensity: intensity)
            }
        }
        #endif
    }
}
