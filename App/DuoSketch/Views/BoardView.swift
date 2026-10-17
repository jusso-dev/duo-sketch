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
                Theme.frameShape
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
                content.offset(x: reduceMotion ? 0 : shakeOffset(animated: offset))
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

    /// The animated offset, or a fixed one while a `-holdShake` launch holds
    /// the shake for a screenshot.
    private func shakeOffset(animated: Double) -> Double {
        LaunchOptions.holdShake && model.clearController.isShaking ? LaunchOptions.heldShakeOffset : animated
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
        LiveCanvas(model: model)
            .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous)
                    .strokeBorder(Theme.bodyShade.opacity(0.6), lineWidth: 3)
            )
            .overlay {
                // Reduce Motion: the board doesn't shake. Instead the drawing
                // cross fades to a blank surface while it clears.
                Theme.surface
                    .keyframeAnimator(initialValue: 0.0, trigger: model.shakeTrigger) { content, opacity in
                        content.opacity(reduceMotion ? opacity : 0)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(1, duration: ClearController.shakeDuration)
                            LinearKeyframe(1, duration: 0.15)
                            LinearKeyframe(0, duration: 0.25)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                model.canvasSize = CanvasSize(width: size.width, height: size.height)
            }
    }

    private var brand: some View {
        Text("Duo Sketch")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.label) // 4.8:1 or better on the body gradient
            .accessibilityHidden(true)
    }

    // The toolbar buttons and the canvas are separate views that read
    // `model.sketch` themselves, so a pen move re-runs only them and not the
    // whole board.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ClearButton(model: model)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            SettingsMenu(model: model)
            ShareButton(model: model)
        }
    }
}

/// The canvas, reading the sketch from the model in its own body.
private struct LiveCanvas: View {
    let model: SketchViewModel

    var body: some View {
        CanvasView(sketch: model.sketch)
    }
}

private struct ClearButton: View {
    let model: SketchViewModel

    var body: some View {
        if model.canUndoClear {
            Button {
                model.undoClear()
            } label: {
                Label("Undo clear", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                model.beginShakeClear()
            } label: {
                Label("Clear", systemImage: "eraser")
            }
            .disabled(model.sketch.isEmpty)
        }
    }
}

private struct ShareButton: View {
    let model: SketchViewModel

    var body: some View {
        Menu {
            shareLink(framed: true, title: "Share with frame", systemImage: "photo.artframe")
            shareLink(framed: false, title: "Share drawing only", systemImage: "scribble")
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(model.sketch.isEmpty)
    }

    /// Each option offers a PNG first and an SVG second.
    private func shareLink(framed: Bool, title: String, systemImage: String) -> some View {
        ShareLink(
            item: SketchExport(sketch: model.sketch, canvasSize: model.canvasSize, framed: framed),
            preview: SharePreview("Duo Sketch drawing", image: Image(systemName: "scribble"))
        ) {
            Label(title, systemImage: systemImage)
        }
    }
}

/// In-app settings. The Haptics toggle covers every haptic in the app (dial
/// ticks, edge bumps and the clear pattern); they also follow the system setting.
private struct SettingsMenu: View {
    let model: SketchViewModel
    @AppStorage(SettingsKeys.hapticsEnabled) private var hapticsEnabled = true

    var body: some View {
        Menu {
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptics", systemImage: "hand.tap")
            }
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .task(id: hapticsEnabled) { model.hapticsEnabled = hapticsEnabled }
    }
}

enum SettingsKeys {
    static let hapticsEnabled = "hapticsEnabled"
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
