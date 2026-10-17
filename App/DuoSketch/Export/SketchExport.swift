import SwiftUI
import UniformTypeIdentifiers
import SketchCore

/// Shareable drawing. Offers a framed PNG first and an SVG second.
/// Both keep the canvas's aspect ratio, with the longer side `longSide` pixels.
struct SketchExport: Transferable {
    let sketch: Sketch
    /// The on-screen canvas the drawing was made on. Points are fractions of it.
    var canvasSize = CanvasSize(width: 1, height: 1)
    var longSide: Double = 1080

    /// PNG render scale. The card is laid out in points at `longSide / scale`.
    static let scale: Double = 3
    static let cardPadding: Double = 18

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await MainActor.run { try item.pngData() }
        }
        .suggestedFileName("Duo Sketch.png")
        DataRepresentation(exportedContentType: .svg) { item in
            Data(item.svgString().utf8)
        }
        .suggestedFileName("Duo Sketch.svg")
    }

    enum ExportError: Error {
        case renderFailed
    }

    /// SVG document size: the canvas aspect ratio at `longSide`.
    var svgSize: CanvasSize { canvasSize.scaled(toLongSide: longSide) }

    /// Size of the drawing inside the PNG card, in points. The card adds
    /// `cardPadding` on every side, so the whole card's long side is `longSide / scale`.
    var cardCanvasSize: CanvasSize {
        canvasSize.scaled(toLongSide: longSide / SketchExport.scale - 2 * SketchExport.cardPadding)
    }

    func svgString() -> String {
        let size = svgSize
        return SVGExporter.svg(
            sketch,
            width: size.width,
            height: size.height,
            lineWidth: 3,
            ink: Theme.inkHex,
            background: Theme.surfaceHex
        )
    }

    @MainActor
    func pngData() throws -> Data {
        let inner = cardCanvasSize
        let renderer = ImageRenderer(content: ExportCard(
            sketch: sketch,
            canvas: CGSize(width: inner.width, height: inner.height),
            padding: SketchExport.cardPadding
        ))
        renderer.scale = SketchExport.scale
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ExportError.renderFailed
        }
        return data
    }
}

/// The framed card used for PNG export.
private struct ExportCard: View {
    let sketch: Sketch
    let canvas: CGSize
    let padding: CGFloat

    var body: some View {
        CanvasView(sketch: sketch, showsPen: false)
            .frame(width: canvas.width, height: canvas.height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
            .padding(padding)
            .background(Theme.body)
    }
}
