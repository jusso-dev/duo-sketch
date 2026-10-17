import SwiftUI
import SketchCore

/// The whole toy: frame, drawing surface and two dials, arranged for the
/// current size class and fold posture.
struct BoardView: View {
    @Bindable var model: SketchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Only the portrait arrangement for now; size class layouts come with #7.
    private let layout: BoardLayout = .portrait

    var body: some View {
        NavigationStack {
            frame
                .padding(layout == .wide ? 28 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bodyShade.ignoresSafeArea())
                .toolbar { toolbar }
                .toolbarBackground(Theme.bodyShade, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { await model.observeFold() }
        .onDeviceShake { model.deviceShaken() }
    }

    private var frame: some View {
        arranged
            .padding(layout == .wide ? 24 : 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.frameCorner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.bodyHighlight, Theme.body, Theme.bodyShade],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            )
            .keyframeAnimator(initialValue: 0.0, trigger: model.shakeTrigger) { content, offset in
                content.offset(x: reduceMotion ? 0 : offset)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(14, duration: 0.08)
                    CubicKeyframe(-12, duration: 0.1)
                    CubicKeyframe(10, duration: 0.1)
                    CubicKeyframe(-7, duration: 0.1)
                    CubicKeyframe(4, duration: 0.1)
                    CubicKeyframe(0, duration: 0.12)
                }
            }
    }

    private var arranged: some View {
        VStack(spacing: 16) {
            surface
            HStack {
                DialView(axis: .horizontal, model: model)
                Spacer()
                brand
                Spacer()
                DialView(axis: .vertical, model: model)
            }
        }
    }

    private var surface: some View {
        CanvasView(sketch: model.sketch)
            .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous)
                    .strokeBorder(Theme.bodyShade.opacity(0.6), lineWidth: 3)
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                model.canvasSize = CanvasSize(width: size.width, height: size.height)
            }
    }

    private var brand: some View {
        Text("Duo Sketch")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.label.opacity(0.85))
            .accessibilityHidden(true)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.beginShakeClear()
            } label: {
                Label("Clear", systemImage: "eraser")
            }
            .disabled(model.sketch.isEmpty)
        }
    }
}

#Preview("Portrait, no hinge") {
    BoardView(model: SketchViewModel(foldService: UnavailableFoldStateService(), sketch: DemoDrawings.hills()))
}

