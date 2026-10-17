import SwiftUI

/// Shape and size metrics shared by every frame theme. Colours live in
/// `FrameTheme`, read from the environment.
enum Theme {
    static let frameCorner: CGFloat = 36
    static let surfaceCorner: CGFloat = 18
    static let lineWidth: CGFloat = 2

    /// The board's outline. On iOS 26 and later it is concentric with the
    /// display corners, so the frame follows the iPhone Duo screen shapes, and
    /// never gets tighter than `frameCorner`. Earlier systems get a rounded
    /// rectangle.
    static var frameShape: AnyShape {
        if #available(iOS 26.0, *) {
            return AnyShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(frameCorner)), isUniform: true))
        }
        return AnyShape(RoundedRectangle(cornerRadius: frameCorner, style: .continuous))
    }
}
