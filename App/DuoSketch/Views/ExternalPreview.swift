import SwiftUI
import SketchCore

// A live, read-only preview of the drawing for someone watching on a TV or
// monitor, through Apple's scene accessory API (iOS 27):
// - View.sceneAccessory(content:):
//   https://developer.apple.com/documentation/swiftui/view/sceneaccessory(content:)
// - ExternalNonInteractiveAccessory, presented when an external display is
//   connected or over AirPlay:
//   https://developer.apple.com/documentation/swiftui/externalnoninteractiveaccessory
//
// The system decides when to show it, and the app works the same without it.
// iPhone Duo's own outer display isn't offered to apps through this API: the
// only other accessory, CameraCaptureAccessory, is for an active camera
// capture session.

extension View {
    /// Registers the external display preview on iOS 27 and later.
    @ViewBuilder
    func externalDisplayPreview(model: SketchViewModel, isEnabled: Binding<Bool>) -> some View {
        if #available(iOS 27.0, *) {
            modifier(ExternalPreviewAccessory(model: model, isEnabled: isEnabled))
        } else {
            self
        }
    }
}

@available(iOS 27.0, *)
private struct ExternalPreviewAccessory: ViewModifier {
    let model: SketchViewModel
    @Binding var isEnabled: Bool
    @Environment(\.frameTheme) private var theme

    func body(content: Content) -> some View {
        content.sceneAccessory {
            ExternalNonInteractiveAccessory(isEnabled: $isEnabled) {
                ExternalPreviewView(model: model)
                    .environment(\.frameTheme, theme)
            }
        }
    }
}

/// The preview itself: the canvas on the frame colour, with no dials, toolbar,
/// shake or fold handling. It copies the drawing at most 30 times a second, so
/// fast dial turns don't redraw the second display on every pen move.
struct ExternalPreviewView: View {
    let model: SketchViewModel
    @State private var shown = Sketch()
    @Environment(\.frameTheme) private var theme

    static let refreshInterval = 1.0 / 30

    var body: some View {
        CanvasView(sketch: shown)
            .aspectRatio(shown.aspectRatio ?? 4.0 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.surfaceCorner, style: .continuous))
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bodyShade)
            .task {
                while !Task.isCancelled {
                    let latest = model.isReplaying ? shown : model.sketch
                    if latest != shown { shown = latest }
                    try? await Task.sleep(for: .seconds(ExternalPreviewView.refreshInterval))
                }
            }
    }
}
