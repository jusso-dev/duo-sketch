import SwiftUI
import SketchCore

/// A brass dial with engraved ticks. Drag in a circle to turn it.
struct DialView: View {
    let axis: DialAxis
    let model: SketchViewModel
    var diameter: CGFloat = 92

    @State private var isTurning = false

    var body: some View {
        let dial = model.dial(axis)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.brass.opacity(0.95), Theme.brassDark],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: diameter * 0.7
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: isTurning ? 2 : 5, y: isTurning ? 1 : 3)
            ticks
                .rotationEffect(.degrees(dial.capAngle))
            Capsule()
                .fill(Theme.bodyShade)
                .frame(width: 4, height: diameter * 0.22)
                .offset(y: -diameter * 0.3)
                .rotationEffect(.degrees(dial.capAngle))
            Image(systemName: axis == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down")
                .font(.system(size: diameter * 0.16, weight: .semibold))
                .foregroundStyle(Theme.bodyShade.opacity(0.8))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(turnGesture)
        .accessibilityElement()
        .accessibilityLabel(axis == .horizontal ? "Across dial" : "Up and down dial")
        .accessibilityHint("Swipe up or down to draw")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.turn(axis, by: 30)
            case .decrement: model.turn(axis, by: -30)
            @unknown default: break
            }
        }
    }

    private var ticks: some View {
        let count = model.dial(axis).config.detentsPerTurn
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(Theme.brassDark.opacity(0.9))
                    .frame(width: 1.5, height: diameter * 0.07)
                    .offset(y: -diameter * 0.43)
                    .rotationEffect(.degrees(Double(i) / Double(count) * 360))
            }
        }
    }

    private var turnGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let angle = angleOf(value.location)
                if !isTurning {
                    isTurning = true
                    model.beginTurn(axis, at: angle)
                } else {
                    model.drag(axis, to: angle)
                }
            }
            .onEnded { _ in
                isTurning = false
                model.endTurn(axis)
            }
    }

    /// Screen angle in degrees, clockwise positive, 0 at three o'clock.
    private func angleOf(_ location: CGPoint) -> Double {
        let dx = location.x - diameter / 2
        let dy = location.y - diameter / 2
        return atan2(dy, dx) * 180 / .pi
    }
}
