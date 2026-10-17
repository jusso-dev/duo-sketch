import SwiftUI
import SketchCore

/// The whole toy: frame, drawing surface and two dials, arranged for the
/// current size class and fold posture.
struct BoardView: View {
    @Bindable var model: SketchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.frameTheme) private var theme
    @AppStorage(SettingsKeys.externalPreview) private var externalPreview = true

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
                .background(theme.bodyShade.ignoresSafeArea())
                .toolbar { toolbar }
                .toolbarBackground(theme.bodyShade, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .bottomLeading) {
            if LaunchOptions.foldDebug { FoldDebugOverlay(model: model) }
        }
        .externalDisplayPreview(model: model, isEnabled: $externalPreview)
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
                            colors: [theme.bodyHighlight, theme.body, theme.bodyShade],
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
                    .strokeBorder(theme.bodyShade.opacity(0.6), lineWidth: 3)
            )
            .overlay {
                // Reduce Motion: the board doesn't shake. Instead the drawing
                // cross fades to a blank surface while it clears.
                theme.surface
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
            .foregroundStyle(theme.label) // 4.5:1 or better on the body, tested per palette
            .accessibilityHidden(true)
    }

    // The toolbar buttons and the canvas are separate views that read
    // `model.sketch` themselves, so a pen move re-runs only them and not the
    // whole board.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            ClearButton(model: model)
            ReplayButton(model: model)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            SettingsMenu(model: model)
            ShareButton(model: model)
        }
    }
}

/// The canvas, reading the sketch from the model in its own body. During a
/// replay it shows the replay frame for the current time instead, redrawn at
/// most 30 times a second.
private struct LiveCanvas: View {
    let model: SketchViewModel

    var body: some View {
        if let replay = model.replay, let start = model.replayStartedAt {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                CanvasView(sketch: replay.frame(at: ReplayTimeline.progress(atElapsed: elapsed)))
            }
            .accessibilityLabel("Drawing, replaying")
        } else {
            CanvasView(sketch: model.sketch)
        }
    }
}

/// Plays the drawing back. Tap again to stop.
private struct ReplayButton: View {
    let model: SketchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if model.isReplaying {
            Button {
                model.stopReplay()
            } label: {
                Label("Stop replay", systemImage: "stop.fill")
            }
        } else {
            Button {
                model.startReplay(reduceMotion: reduceMotion)
            } label: {
                Label("Replay", systemImage: "play.fill")
            }
            .disabled(model.sketch.isEmpty || reduceMotion)
        }
    }
}

/// Shows the fold posture and hinge angle, for checking poses on the iPhone
/// Duo simulator. Only with the `-foldDebug` launch argument.
private struct FoldDebugOverlay: View {
    let model: SketchViewModel

    var body: some View {
        Text("Fold: \(model.posture.description)")
            .font(.caption.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: Capsule())
            .foregroundStyle(.white)
            .padding()
            .accessibilityIdentifier("foldDebug")
            .allowsHitTesting(false)
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
    @Environment(\.frameTheme) private var theme

    var body: some View {
        Menu {
            shareLink(framed: true, title: "Share with frame", systemImage: "photo.artframe")
            shareLink(framed: false, title: "Share drawing only", systemImage: "scribble")
            ShareLink(
                item: ReplayMovie(sketch: model.sketch, canvasSize: model.canvasSize, theme: theme),
                preview: SharePreview("Duo Sketch replay", image: Image(systemName: "play.rectangle"))
            ) {
                Label("Share replay video", systemImage: "play.rectangle")
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(model.sketch.isEmpty)
    }

    /// Each option offers a PNG first and an SVG second.
    private func shareLink(framed: Bool, title: String, systemImage: String) -> some View {
        ShareLink(
            item: SketchExport(sketch: model.sketch, canvasSize: model.canvasSize, framed: framed, theme: theme),
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
    @AppStorage(SettingsKeys.frameTheme) private var frameTheme = FramePalette.ID.eucalyptus
    @AppStorage(SettingsKeys.externalPreview) private var externalPreview = true

    var body: some View {
        Menu {
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptics", systemImage: "hand.tap")
            }
            Picker(selection: $frameTheme) {
                ForEach(FramePalette.all) { palette in
                    Text(palette.name).tag(palette.id)
                }
            } label: {
                Label("Frame", systemImage: "paintpalette")
            }
            .pickerStyle(.menu)
            Toggle(isOn: $externalPreview) {
                Label("Preview on external display", systemImage: "tv")
            }
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .task(id: hapticsEnabled) { model.hapticsEnabled = hapticsEnabled }
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
