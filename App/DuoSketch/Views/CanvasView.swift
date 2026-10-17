import SwiftUI
import SketchCore

/// Draws the sketch on the sand surface.
///
/// The ink is drawn in two layers so a pen move doesn't redraw the whole
/// drawing. `SettledInkLayer` holds everything except the end of the stroke
/// being drawn, and only redraws when `Sketch.inkSplit()` changes (every 256
/// points, or on a clear, fade or thinning). `LiveInkLayer` draws the short
/// live tail and the pen on every move.
struct CanvasView: View {
    let sketch: Sketch
    var showsPen = true

    var body: some View {
        let split = sketch.inkSplit()
        ZStack {
            SettledInkLayer(sketch: sketch, split: split)
                .equatable()
            LiveInkLayer(sketch: sketch, split: split, showsPen: showsPen)
        }
        .background(Theme.surface)
        .accessibilityElement()
        .accessibilityLabel("Drawing")
        .accessibilityValue(CanvasView.accessibilityValue(for: sketch))
    }

    /// What VoiceOver reads for the canvas: whether there is a drawing, how
    /// many lines it has and where the pen is. A raw point count meant nothing.
    static func accessibilityValue(for sketch: Sketch) -> String {
        let pen = "pen \(percent(sketch.pen.x)) percent across, \(percent(sketch.pen.y)) percent down"
        let lines = sketch.strokes.filter { $0.points.count > 1 }.count
        switch lines {
        case 0: return "Empty, \(pen)"
        case 1: return "Drawing with 1 line, \(pen)"
        default: return "Drawing with \(lines) lines, \(pen)"
        }
    }

    private static func percent(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }
}

/// Every stroke, except the live tail of the last one. Equal while the split
/// and the drawing's shape are unchanged, so SwiftUI keeps the drawn layer.
struct SettledInkLayer: View, Equatable {
    let sketch: Sketch
    let split: InkSplit

    nonisolated static func == (a: SettledInkLayer, b: SettledInkLayer) -> Bool {
        a.split == b.split && a.sketch.aspectRatio == b.sketch.aspectRatio
    }

    var body: some View {
        Canvas { context, size in
            let frame = sketch.frame(in: CanvasSize(width: size.width, height: size.height))
            let lastIndex = sketch.strokes.count - 1
            for (i, stroke) in sketch.strokes.enumerated() {
                let count = (split.hasLiveStroke && i == lastIndex) ? split.settledPoints : stroke.points.count
                InkPainter.stroke(stroke.points.prefix(count), opacity: stroke.opacity, frame: frame, in: &context)
            }
        }
    }
}

/// The end of the stroke being drawn (at most 257 points) and the pen.
struct LiveInkLayer: View {
    let sketch: Sketch
    let split: InkSplit
    let showsPen: Bool

    var body: some View {
        Canvas { context, size in
            let frame = sketch.frame(in: CanvasSize(width: size.width, height: size.height))
            if split.hasLiveStroke, let last = sketch.strokes.last {
                let start = max(split.settledPoints - 1, 0)
                InkPainter.stroke(last.points[start...], opacity: last.opacity, frame: frame, in: &context)
            }
            if showsPen {
                let pen = InkPainter.position(sketch.pen, in: frame)
                let dot = CGRect(x: pen.x - 2.5, y: pen.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(Theme.ink))
            }
        }
    }
}

enum InkPainter {
    /// Maps a drawing point into the drawing's letterboxed frame, so the
    /// drawing keeps its proportions when the canvas changes shape.
    static func position(_ p: Point, in frame: DrawingFrame) -> CGPoint {
        let position = frame.position(of: p)
        return CGPoint(x: position.x, y: position.y)
    }

    static func stroke(_ points: ArraySlice<Point>, opacity: Double, frame: DrawingFrame, in context: inout GraphicsContext) {
        guard points.count > 1, let first = points.first else { return }
        var path = Path()
        path.move(to: position(first, in: frame))
        for p in points.dropFirst() {
            path.addLine(to: position(p, in: frame))
        }
        context.stroke(
            path,
            with: .color(Theme.ink.opacity(opacity)),
            style: StrokeStyle(lineWidth: Theme.lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}
