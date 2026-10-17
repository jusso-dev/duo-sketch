import SwiftUI
import SketchCore

/// SwiftUI colours for one of SketchCore's `FramePalette`s. The colours are
/// fixed, so the toy looks the same in light and dark appearance, like a real
/// object would. Contrast rules for every palette are tested in SketchCore.
struct FrameTheme: Equatable, Sendable {
    let palette: FramePalette

    init(_ id: FramePalette.ID) {
        palette = FramePalette.palette(id)
    }

    static let eucalyptus = FrameTheme(.eucalyptus)

    var body: Color { Color(hex: palette.body) }
    var bodyShade: Color { Color(hex: palette.bodyShade) }
    var bodyHighlight: Color { Color(hex: palette.bodyHighlight) }
    var surface: Color { Color(hex: palette.surface) }
    var ink: Color { Color(hex: palette.ink) }
    var dial: Color { Color(hex: palette.dial) }
    var dialShade: Color { Color(hex: palette.dialShade) }
    var dialMark: Color { Color(hex: palette.dialMark) }
    var label: Color { Color(hex: palette.label) }
}

extension Color {
    /// A colour from a `#RRGGBB` string, in sRGB.
    init(hex: String) {
        let c = FramePalette.components(hex)
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue)
    }
}

extension EnvironmentValues {
    /// The frame theme chosen in settings. Set once at the root of the app.
    @Entry var frameTheme = FrameTheme.eucalyptus
}

enum SettingsKeys {
    static let hapticsEnabled = "hapticsEnabled"
    static let frameTheme = "frameTheme"
    static let externalPreview = "externalPreview"
}
