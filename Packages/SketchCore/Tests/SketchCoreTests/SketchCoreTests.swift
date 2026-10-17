import XCTest
@testable import SketchCore

final class SketchCoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(SketchCore.version.isEmpty)
    }
}
