import SwiftUI
import SketchCore

@main
struct DuoSketchApp: App {
    @State private var hinge = HingeFoldStateService()
    @State private var model: SketchViewModel?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model {
                    BoardView(model: model)
                } else {
                    Theme.bodyShade.ignoresSafeArea()
                }
            }
            .feedingHinge(into: hinge)
            .onAppear {
                if model == nil {
                    let demo = LaunchOptions.demoSketch
                    // Demo launches don't touch the saved drawing.
                    let model = SketchViewModel(
                        foldService: LaunchOptions.foldService ?? hinge,
                        sketch: demo ?? Sketch(),
                        store: demo == nil ? FileSketchStore.applicationSupport() : nil,
                        sleep: LaunchOptions.holdShake ? { _ in await LaunchOptions.waitForever() } : nil
                    )
                    self.model = model
                    Task { await model.restore() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                model?.scenePhaseChanged(to: phase)
            }
        }
    }
}

/// Launch arguments for UI tests and screenshots.
/// - `-demoDrawing spiral`, `hills`, `skyline` or `blank`. Demo launches don't
///   read or write the saved drawing.
/// - `-foldPosture easel`, `open` or `closed` fixes the fold posture instead of
///   reading the hinge, so easel mode can be shown on any simulator.
/// - `-holdShake` freezes a shake clear mid swing and never finishes it, so a
///   screenshot of the shake doesn't depend on timing.
enum LaunchOptions {
    static let holdShake = ProcessInfo.processInfo.arguments.contains("-holdShake")

    /// Board offset shown while a held shake is on screen.
    static let heldShakeOffset = 12.0

    static func waitForever() async {
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
    }

    static var demoSketch: Sketch? {
        switch value(after: "-demoDrawing") {
        case "spiral": return DemoDrawings.spiral()
        case "hills": return DemoDrawings.hills()
        case "skyline": return DemoDrawings.skyline()
        case "blank": return Sketch()
        default: return nil
        }
    }

    static var foldService: (any FoldStateService)? {
        switch value(after: "-foldPosture") {
        case "easel": return StaticFoldStateService(.partiallyOpen(angleDegrees: 100))
        case "open": return StaticFoldStateService(.open)
        case "closed": return StaticFoldStateService(.closed)
        default: return nil
        }
    }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
