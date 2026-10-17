import SwiftUI

/// Duo Sketch palette. An original scheme: eucalyptus body, sand drawing
/// surface, graphite ink and brass dials. No red anywhere.
///
/// The colours are fixed, so the toy looks the same in light and dark
/// appearance, like a real object would. Contrast is checked in both by
/// `DuoSketchTests.testPaletteContrastInLightAndDark`.
enum Theme {
    static let body = Color(red: 0.184, green: 0.365, blue: 0.314)        // #2F5D50 eucalyptus
    static let bodyShade = Color(red: 0.137, green: 0.275, blue: 0.235)   // #23463C
    static let bodyHighlight = Color(red: 0.290, green: 0.478, blue: 0.420) // #4A7A6B
    static let surface = Color(red: 0.937, green: 0.890, blue: 0.784)     // #EFE3C8 sand
    static let ink = Color(red: 0.169, green: 0.169, blue: 0.169)         // #2B2B2B graphite
    static let brass = Color(red: 0.776, green: 0.580, blue: 0.278)       // #C69447
    static let brassDark = Color(red: 0.549, green: 0.416, blue: 0.184)   // #8C6A2F
    /// Engraving on the dials. 3:1 or better across the whole brass gradient.
    static let dialMark = Color(red: 0.078, green: 0.165, blue: 0.141)    // #142A24
    static let label = Color(red: 0.937, green: 0.890, blue: 0.784)

    static let inkHex = "#2B2B2B"
    static let surfaceHex = "#EFE3C8"

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
