import Foundation

/// The colours of one frame theme, as hex strings. The app turns these into
/// SwiftUI colours; keeping them here lets the contrast rules run on Linux.
///
/// Every palette is original: no red, and no grey drawing surface.
public struct FramePalette: Sendable, Equatable, Identifiable {
    public enum ID: String, Sendable, CaseIterable, Codable {
        case eucalyptus, ocean, ochre
    }

    public let id: ID
    public let name: String
    public let body: String
    public let bodyShade: String
    public let bodyHighlight: String
    /// The drawing surface.
    public let surface: String
    public let ink: String
    /// The dials, a gradient from `dial` to `dialShade`.
    public let dial: String
    public let dialShade: String
    /// Pointer and arrow engraved on the dials.
    public let dialMark: String
    /// The wordmark on the body.
    public let label: String

    public static let eucalyptus = FramePalette(
        id: .eucalyptus, name: "Eucalyptus",
        body: "#2F5D50", bodyShade: "#23463C", bodyHighlight: "#4A7A6B",
        surface: "#EFE3C8", ink: "#2B2B2B",
        dial: "#C69447", dialShade: "#8C6A2F", dialMark: "#142A24",
        label: "#EFE3C8"
    )

    /// Deep blue-teal body, pale sand surface and silver dials.
    public static let ocean = FramePalette(
        id: .ocean, name: "Ocean",
        body: "#1F4F66", bodyShade: "#163B4D", bodyHighlight: "#3B6F87",
        surface: "#F2EAD8", ink: "#2B2B2B",
        dial: "#C3CCD1", dialShade: "#7D8B94", dialMark: "#13232D",
        label: "#F2EAD8"
    )

    /// Burnt ochre body, cream surface and dark bronze dials.
    public static let ochre = FramePalette(
        id: .ochre, name: "Ochre",
        body: "#8A4A1C", bodyShade: "#6A3612", bodyHighlight: "#A9632E",
        surface: "#F6ECD4", ink: "#2B2B2B",
        dial: "#B98F55", dialShade: "#80633A", dialMark: "#1C130A",
        label: "#F6ECD4"
    )

    public static let all: [FramePalette] = [.eucalyptus, .ocean, .ochre]

    public static func palette(_ id: ID) -> FramePalette {
        all.first { $0.id == id } ?? .eucalyptus
    }

    /// Red, green and blue from 0 to 1 for a `#RRGGBB` string. Black when the
    /// string isn't one.
    public static func components(_ hex: String) -> (red: Double, green: Double, blue: Double) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return (0, 0, 0) }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    /// WCAG relative luminance.
    public static func luminance(_ hex: String) -> Double {
        func linear(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let c = components(hex)
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    /// WCAG contrast ratio between two colours, from 1 to 21.
    public static func contrast(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// True for a saturated colour with a red hue (within 15 degrees of pure red).
    public static func isRed(_ hex: String) -> Bool {
        let c = components(hex)
        let high = max(c.red, c.green, c.blue), low = min(c.red, c.green, c.blue)
        let lightness = (high + low) / 2
        guard high > low else { return false }
        let saturation = (high - low) / (1 - abs(2 * lightness - 1))
        guard saturation > 0.35, high == c.red else { return false }
        var hue = 60 * (c.green - c.blue) / (high - low)
        if hue < 0 { hue += 360 }
        return hue < 15 || hue > 345
    }

    /// Every colour in the palette.
    public var colours: [String] {
        [body, bodyShade, bodyHighlight, surface, ink, dial, dialShade, dialMark, label]
    }
}
