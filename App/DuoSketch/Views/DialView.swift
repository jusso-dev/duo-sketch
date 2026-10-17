import SwiftUI
import SketchCore

/// A brass dial with engraved ticks. Drag in a circle to turn it.
struct DialView: View {
    let axis: DialAxis
    let model: SketchViewModel
    var diameter: CGFloat = 92

    static let accessibilityStepDegrees = 90.0

    @State private var isTurning = false
    /// True while a finger is down. Unlike `onEnded`, this also resets when the
    /// system cancels the gesture (Notification Centre, a call, an edge swipe).
    @GestureState private var isTouching = false

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
                .foregroundStyle(Theme.bodyShade) // 3.8:1 on brass
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(turnGesture)
        .onChange(of: isTouching) { _, touching in
            if !touching, isTurning {
                isTurning = false
                model.endTurn(axis)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(axis == .horizontal ? "Across dial" : "Up and down dial")
        .accessibilityValue(model.accessibilityValue(for: axis))
        .accessibilityHint("Swipe up or down to draw")
        .accessibilityAdjustableAction { direction in
            // A quarter turn (30 pt) per swipe, so crossing the canvas takes a
            // handful of swipes rather than dozens.
            switch direction {
            case .increment: model.turn(axis, by: DialView.accessibilityStepDegrees)
            case .decrement: model.turn(axis, by: -DialView.accessibilityStepDegrees)
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
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if !isTurning {
                    isTurning = true
                    model.beginTurn(axis)
                }
                model.touch(
                    axis,
                    x: value.location.x - diameter / 2,
                    y: value.location.y - diameter / 2,
                    radius: diameter / 2
                )
            }
            .onEnded { _ in
                isTurning = false
                model.endTurn(axis)
            }
    }
}
