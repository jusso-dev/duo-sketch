import SwiftUI
import SketchCore

@main
struct DuoSketchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Duo Sketch \(SketchCore.version)")
        }
    }
}
