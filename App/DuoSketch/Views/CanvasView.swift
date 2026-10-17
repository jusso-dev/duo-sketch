import SwiftUI
import SketchCore

/// Draws the sketch on the sand surface.
struct CanvasView: View {
    let sketch: Sketch
    var showsPen = true

    var body: some View {
        Canvas { context, size in
            for stroke in sketch.strokes where stroke.points.count > 1 {
                var path = Path()
                path.move(to: point(stroke.points[0], in: size))
                for p in stroke.points.dropFirst() {
                    path.addLine(to: point(p, in: size))
                }
                context.stroke(
                    path,
                    with: .color(Theme.ink.opacity(stroke.opacity)),
                    style: StrokeStyle(lineWidth: Theme.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
            if showsPen {
                let pen = point(sketch.pen, in: size)
                let dot = CGRect(x: pen.x - 2.5, y: pen.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(Theme.ink))
            }
        }
        .background(Theme.surface)
        .accessibilityElement()
        .accessibilityLabel("Drawing")
        .accessibilityValue(sketch.isEmpty ? "Empty" : "\(sketch.pointCount) points")
    }

    private func point(_ p: SketchCore.Point, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
}
