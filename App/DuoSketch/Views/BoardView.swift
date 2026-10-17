import SwiftUI
import SketchCore

/// The whole toy: frame, drawing surface and two dials, arranged for the
/// current size class and fold posture.
struct BoardView: View {
    @Bindable var model: SketchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: BoardLayout {
        BoardLayout.choose(
            horizontal: horizontalSizeClass == .regular ? .regular : .compact,
            vertical: verticalSizeClass == .regular ? .regular : .compact,
            fold: model.posture
        )
    }

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

    @ViewBuilder
    private var arranged: some View {
        switch layout {
        case .portrait:
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
        case .wide:
            VStack(spacing: 24) {
                surface
                HStack {
                    DialView(axis: .horizontal, model: model, diameter: 124)
                    Spacer()
                    brand
                    Spacer()
                    DialView(axis: .vertical, model: model, diameter: 124)
                }
            }
        case .landscape:
            HStack(spacing: 16) {
                DialView(axis: .horizontal, model: model)
                surface
                DialView(axis: .vertical, model: model)
            }
        case .easel:
            VStack(spacing: 0) {
                surface
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 20)
                HStack {
                    DialView(axis: .horizontal, model: model, diameter: 110)
                    Spacer()
                    brand
                    Spacer()
                    DialView(axis: .vertical, model: model, diameter: 110)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 20)
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

#Preview("Easel") {
    BoardView(model: SketchViewModel(
        foldService: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 100)),
        sketch: DemoDrawings.spiral()
    ))
}
