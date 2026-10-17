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
                        foldService: hinge,
                        sketch: demo ?? Sketch(),
                        store: demo == nil ? FileSketchStore.applicationSupport() : nil
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
/// `-demoDrawing spiral` or `-demoDrawing hills`.
enum LaunchOptions {
    static var demoSketch: Sketch? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoDrawing"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "spiral": return DemoDrawings.spiral()
        case "hills": return DemoDrawings.hills()
        default: return nil
        }
    }
}
