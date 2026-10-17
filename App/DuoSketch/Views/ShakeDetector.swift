import SwiftUI

#if canImport(UIKit)
import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("DuoSketch.deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    /// Calls `action` when the user shakes the phone.
    func onDeviceShake(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}
#else
extension View {
    func onDeviceShake(perform action: @escaping () -> Void) -> some View { self }
}
#endif
