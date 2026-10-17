import SwiftUI
import UniformTypeIdentifiers
import SketchCore

/// Shareable drawing. Offers a PNG first and an SVG second. The PNG is the
/// framed card, or just the drawing when `framed` is false.
/// Both keep the drawing's aspect ratio, with the longer side `longSide` pixels.
struct SketchExport: Transferable {
    let sketch: Sketch
    /// The on-screen canvas the drawing was made on. Points are fractions of it.
    var canvasSize = CanvasSize(width: 1, height: 1)
    var longSide: Double = 1080
    /// True for the eucalyptus card around the drawing, false for the drawing alone.
    var framed = true

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

    /// The shape the drawing was made at. This stays the same when the canvas
    /// changes shape later, so the export is never stretched.
    var drawingShape: CanvasSize { sketch.frame(in: canvasSize).size }

    /// SVG document size: the drawing's aspect ratio at `longSide`.
    var svgSize: CanvasSize { drawingShape.scaled(toLongSide: longSide) }

    /// Frame width around the drawing in the PNG, in points. Zero when plain.
    var padding: Double { framed ? SketchExport.cardPadding : 0 }

    /// Size of the drawing inside the PNG, in points. The card adds `padding`
    /// on every side, so the whole image's long side is `longSide / scale`.
    var cardCanvasSize: CanvasSize {
        drawingShape.scaled(toLongSide: longSide / SketchExport.scale - 2 * padding)
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
            framed: framed
        ))
        renderer.scale = SketchExport.scale
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ExportError.renderFailed
        }
        return data
    }
}

/// The image used for PNG export: the drawing on its frame, or on its own.
private struct ExportCard: View {
    let sketch: Sketch
    let canvas: CGSize
    let framed: Bool

    var body: some View {
        let drawing = CanvasView(sketch: sketch, showsPen: false)
            .frame(width: canvas.width, height: canvas.height)
        if framed {
            drawing
                .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
                .padding(SketchExport.cardPadding)
                .background(Theme.body)
        } else {
            drawing
        }
    }
}
