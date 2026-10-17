import SwiftUI
import SketchCore

@main
struct DuoSketchApp: App {
    @State private var hinge = HingeFoldStateService()
    @State private var model: SketchViewModel?

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
                    model = SketchViewModel(foldService: hinge, sketch: LaunchOptions.demoSketch ?? Sketch())
                }
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
