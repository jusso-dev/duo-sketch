import XCTest
import SketchCore

final class DuoSketchTests: XCTestCase {
    func testCoreLinks() {
        XCTAssertFalse(SketchCore.version.isEmpty)
    }
}
