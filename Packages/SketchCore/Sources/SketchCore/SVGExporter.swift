/// Exports a sketch as a standalone SVG document.
public enum SVGExporter {
    public static func svg(
        _ sketch: Sketch,
        width: Double,
        height: Double,
        lineWidth: Double = 2,
        ink: String = "#2B2B2B",
        background: String? = "#EFE3C8"
    ) -> String {
        var out = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(fmt(width))\" height=\"\(fmt(height))\" viewBox=\"0 0 \(fmt(width)) \(fmt(height))\">\n"
        if let background {
            out += "  <rect width=\"100%\" height=\"100%\" fill=\"\(escape(background))\"/>\n"
        }
        for stroke in sketch.strokes where stroke.points.count > 1 {
            let pts = stroke.points.map { "\(fmt($0.x * width)),\(fmt($0.y * height))" }.joined(separator: " ")
            out += "  <polyline fill=\"none\" stroke=\"\(escape(ink))\" stroke-opacity=\"\(fmt(stroke.opacity))\" stroke-width=\"\(fmt(lineWidth))\" stroke-linecap=\"round\" stroke-linejoin=\"round\" points=\"\(pts)\"/>\n"
        }
        out += "</svg>\n"
        return out
    }

    /// Two decimal places, and whole numbers without a decimal point.
    /// Non-finite values become 0 so the document stays valid SVG.
    static func fmt(_ v: Double) -> String {
        guard v.isFinite else { return "0" }
        let r = (v * 100).rounded() / 100
        guard r.isFinite else { return String(v) }
        if r == r.rounded(), let whole = Int(exactly: r) { return String(whole) }
        return String(r)
    }

    static func escape(_ s: String) -> String {
        var o = ""
        for c in s {
            switch c {
            case "&": o += "&amp;"
            case "<": o += "&lt;"
            case ">": o += "&gt;"
            case "\"": o += "&quot;"
            case "'": o += "&apos;"
            default: o.append(c)
            }
        }
        return o
    }
}
