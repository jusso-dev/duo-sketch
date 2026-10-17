/// Plays a drawing back in the order it was drawn.
///
/// A sketch already keeps its strokes and their points in order, so replay
/// needs no recording: progress from 0 to 1 reveals a prefix of the points.
/// Replay always lasts `duration`, so a long drawing speeds up instead of
/// dragging on. Faded strokes replay at their current opacity, and thinned
/// strokes replay as they are stored.
public struct ReplayTimeline: Sendable, Equatable {
    /// Seconds a replay takes, whatever the drawing's length.
    public static let duration = 8.0

    public let sketch: Sketch
    /// Points in strokes that draw something (two points or more).
    public let totalPoints: Int

    public init(_ sketch: Sketch) {
        self.sketch = sketch
        totalPoints = sketch.strokes.lazy.filter { $0.points.count > 1 }.reduce(0) { $0 + $1.points.count }
    }

    /// Progress (0 to 1) at `elapsed` seconds into the replay.
    public static func progress(atElapsed elapsed: Double, duration: Double = ReplayTimeline.duration) -> Double {
        guard elapsed.isFinite, duration > 0 else { return 1 }
        return min(max(elapsed / duration, 0), 1)
    }

    /// The drawing as it stood `progress` (0 to 1) of the way through. The pen
    /// sits on the last point revealed. Progress 1 is the whole sketch.
    public func frame(at progress: Double) -> Sketch {
        let progress = progress.isNaN ? 0 : min(max(progress, 0), 1)
        guard progress < 1, totalPoints > 0 else { return sketch }
        var remaining = Int((progress * Double(totalPoints)).rounded(.down))
        var strokes: [Stroke] = []
        var pen = sketch.strokes.first { $0.points.count > 1 }?.points.first ?? sketch.pen
        for stroke in sketch.strokes where stroke.points.count > 1 {
            guard remaining > 0 else { break }
            let shown = min(remaining, stroke.points.count)
            strokes.append(Stroke(points: Array(stroke.points.prefix(shown)), opacity: stroke.opacity))
            pen = stroke.points[shown - 1]
            remaining -= shown
        }
        return Sketch(replaying: strokes, pen: pen, aspectRatio: sketch.aspectRatio)
    }
}
