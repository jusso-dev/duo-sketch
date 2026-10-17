/// Deterministic drawings for previews, UI tests and screenshots.
/// All original artwork made only with the two dials.
public enum DemoDrawings {
    /// A squared spiral drawn outwards from the centre.
    public static func spiral(size: CanvasSize = CanvasSize(width: 360, height: 360)) -> Sketch {
        var sketch = Sketch()
        var length = 8.0
        let dirs: [(Double, Double)] = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        for i in 0..<40 {
            let (dx, dy) = dirs[i % 4]
            sketch.movePen(dx: dx * length, dy: dy * length, in: size)
            length += 8
        }
        return sketch
    }

    /// A row of hills, using both dials together for the slopes.
    public static func hills(size: CanvasSize = CanvasSize(width: 360, height: 360)) -> Sketch {
        var sketch = Sketch(pen: Point(x: 0, y: 0.75))
        for _ in 0..<4 {
            for _ in 0..<12 { sketch.movePen(dx: 4, dy: 4, in: size) }
            for _ in 0..<12 { sketch.movePen(dx: 4, dy: -4, in: size) }
        }
        return sketch
    }

    /// A city skyline along the bottom third, drawn with straight dial moves only.
    public static func skyline(size: CanvasSize = CanvasSize(width: 360, height: 360)) -> Sketch {
        var sketch = Sketch(pen: Point(x: 0, y: 0.85))
        // (height, width) of each building, in canvas points.
        let buildings: [(Double, Double)] = [
            (60, 30), (110, 24), (80, 36), (170, 20), (140, 30),
            (90, 28), (200, 16), (120, 34), (70, 40), (100, 30),
        ]
        sketch.movePen(dx: 12, dy: 0, in: size)
        for (height, width) in buildings {
            // Positive dy moves the pen up.
            sketch.movePen(dx: 0, dy: height, in: size)
            sketch.movePen(dx: width, dy: 0, in: size)
            sketch.movePen(dx: 0, dy: -height, in: size)
            sketch.movePen(dx: 4, dy: 0, in: size)
        }
        return sketch
    }
}
