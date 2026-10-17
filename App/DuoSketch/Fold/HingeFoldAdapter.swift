import SwiftUI
import SketchCore

// Bridges Apple's public SwiftUI hinge API (iOS 27.1) to SketchCore's
// `HingeFoldStateService`. This is the only file that touches the hinge API.
//
// - https://developer.apple.com/documentation/swiftui/devicehinge
// - https://developer.apple.com/documentation/swiftui/devicehingecontext
// - https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)

@available(iOS 27.1, *)
extension HingeReading {
    init(_ hinge: DeviceHinge) {
        let status: HingeStatus
        if hinge.status == .closed {
            status = .closed
        } else if hinge.status == .fullyOpen {
            status = .fullyOpen
        } else {
            status = .partiallyOpen
        }
        self.init(status: status, angleDegrees: hinge.angle.degrees)
    }
}

@available(iOS 27.1, *)
private struct HingeFeed: ViewModifier {
    let service: HingeFoldStateService

    func body(content: Content) -> some View {
        content.onHingeChange { _, context in
            service.update(reading: context.hinge.map(HingeReading.init))
        }
    }
}

extension View {
    /// Feeds hinge changes into `service` on iOS 27.1 and later.
    /// On earlier systems there is no hinge, so the service stays `.unavailable`.
    @ViewBuilder
    func feedingHinge(into service: HingeFoldStateService) -> some View {
        if #available(iOS 27.1, *) {
            modifier(HingeFeed(service: service))
        } else {
            self
        }
    }
}
