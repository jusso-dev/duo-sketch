import XCTest
#if canImport(FoundationXML)
import FoundationXML
#endif
@testable import SketchCore

final class BoardLayoutTests: XCTestCase {
    func testLayoutChoices() {
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .unavailable), .portrait)
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .compact, fold: .unavailable), .landscape)
        XCTAssertEqual(BoardLayout.choose(horizontal: .regular, vertical: .compact, fold: .unavailable), .landscape)
        XCTAssertEqual(BoardLayout.choose(horizontal: .regular, vertical: .regular, fold: .open), .wide)
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .closed), .portrait)
    }

    func testHalfOpenAlwaysEasel() {
        for h in [SizeClass.compact, .regular] {
            for v in [SizeClass.compact, .regular] {
                XCTAssertEqual(BoardLayout.choose(horizontal: h, vertical: v, fold: .partiallyOpen(angleDegrees: 100)), .easel)
            }
        }
    }
}

final class HapticThrottleTests: XCTestCase {
    func testLimitsRate() {
        var t = HapticThrottle(maxPerSecond: 30)
        var fired = 0
        for i in 0..<1000 where t.shouldFire(at: Double(i) / 1000) { fired += 1 }
        XCTAssertEqual(fired, 30, accuracy: 1)
    }
}

final class SVGExporterTests: XCTestCase {
    func testEmptySketch() {
        let svg = SVGExporter.svg(Sketch(), width: 100, height: 50)
        XCTAssertTrue(svg.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"50\""))
        XCTAssertFalse(svg.contains("polyline"))
        XCTAssertTrue(svg.contains("<rect"))
    }

    func testStrokesAreScaledAndEscaped() {
        var s = Sketch()
        s.movePen(dx: 25, dy: 0, in: CanvasSize(width: 100, height: 100))
        s.fade(by: 0.5)
        s.movePen(dx: 0, dy: 25, in: CanvasSize(width: 100, height: 100))
        let svg = SVGExporter.svg(s, width: 200, height: 200, ink: "a\"b", background: nil)
        XCTAssertEqual(svg.components(separatedBy: "<polyline").count - 1, 2)
        XCTAssertTrue(svg.contains("points=\"100,100 150,100\""))
        XCTAssertTrue(svg.contains("stroke-opacity=\"0.5\""))
        XCTAssertTrue(svg.contains("a&quot;b"))
        XCTAssertFalse(svg.contains("<rect"))
    }

    func testIsWellFormedXML() throws {
        let svg = SVGExporter.svg(DemoDrawings.hills(), width: 300, height: 300)
        #if canImport(FoundationXML)
        let parser = FoundationXML.XMLParser(data: Data(svg.utf8))
        #else
        let parser = XMLParser(data: Data(svg.utf8))
        #endif
        XCTAssertTrue(parser.parse())
    }
}

final class DemoDrawingsTests: XCTestCase {
    func testDemosAreDeterministicAndNonEmpty() {
        XCTAssertEqual(DemoDrawings.spiral(), DemoDrawings.spiral())
        XCTAssertFalse(DemoDrawings.spiral().isEmpty)
        XCTAssertFalse(DemoDrawings.hills().isEmpty)
    }
}
