import SwiftUI
import UniformTypeIdentifiers
import SketchCore

/// Shareable drawing. Offers a framed PNG first and an SVG second.
struct SketchExport: Transferable {
    let sketch: Sketch
    var size: CGFloat = 1080

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await MainActor.run { try item.pngData() }
        }
        .suggestedFileName("Duo Sketch.png")
        DataRepresentation(exportedContentType: .svg) { item in
            Data(SVGExporter.svg(
                item.sketch,
                width: Double(item.size),
                height: Double(item.size),
                lineWidth: 3,
                ink: Theme.inkHex,
                background: Theme.surfaceHex
            ).utf8)
        }
        .suggestedFileName("Duo Sketch.svg")
    }

    enum ExportError: Error {
        case renderFailed
    }

    @MainActor
    func pngData() throws -> Data {
        let renderer = ImageRenderer(content: ExportCard(sketch: sketch, side: size / 3))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ExportError.renderFailed
        }
        return data
    }
}

/// The framed card used for PNG export.
private struct ExportCard: View {
    let sketch: Sketch
    let side: CGFloat

    var body: some View {
        CanvasView(sketch: sketch, showsPen: false)
            .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
            .padding(18)
            .background(Theme.body)
            .frame(width: side, height: side)
    }
}
