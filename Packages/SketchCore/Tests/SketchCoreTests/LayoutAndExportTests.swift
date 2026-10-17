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

final class EaselBandTests: XCTestCase {
    func testHingeSettleAfterClosingKeepsTheOuterLayout() {
        // A shut phone reporting 1 to 2 degrees must not flip into easel.
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .partiallyOpen(angleDegrees: 1)), .portrait)
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .partiallyOpen(angleDegrees: 19.9)), .portrait)
    }

    func testEaselOnlyInsideTheBand() {
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .partiallyOpen(angleDegrees: 20)), .easel)
        XCTAssertEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .partiallyOpen(angleDegrees: 160)), .easel)
        XCTAssertEqual(BoardLayout.choose(horizontal: .regular, vertical: .regular, fold: .partiallyOpen(angleDegrees: 175)), .wide, "nearly flat")
        XCTAssertNotEqual(BoardLayout.choose(horizontal: .compact, vertical: .regular, fold: .partiallyOpen(angleDegrees: .nan)), .easel)
    }

    func testLayoutAndClearPolicyShareTheThreshold() {
        XCTAssertEqual(BoardLayout.easelAngles.lowerBound, FoldClearPolicy().reopenAngleDegrees)
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

final class ExportSizeTests: XCTestCase {
    func testKeepsAspectRatioWithLongSide() {
        XCTAssertEqual(CanvasSize(width: 300, height: 450).scaled(toLongSide: 1080), CanvasSize(width: 720, height: 1080))
        XCTAssertEqual(CanvasSize(width: 640, height: 360).scaled(toLongSide: 1080), CanvasSize(width: 1080, height: 608))
        XCTAssertEqual(CanvasSize(width: 320, height: 320).scaled(toLongSide: 1080), CanvasSize(width: 1080, height: 1080))
    }

    func testSvgOfAScaledSizeIsNotSquare() {
        var sketch = Sketch()
        sketch.movePen(dx: 10, dy: 10, in: CanvasSize(width: 300, height: 450))
        let size = CanvasSize(width: 300, height: 450).scaled(toLongSide: 1080)
        let svg = SVGExporter.svg(sketch, width: size.width, height: size.height)
        XCTAssertTrue(svg.contains("width=\"720\" height=\"1080\" viewBox=\"0 0 720 1080\""))
    }

    func testExtremeAspectStaysAtLeastOnePoint() {
        let s = CanvasSize(width: 100_000, height: 1).scaled(toLongSide: 1080)
        XCTAssertEqual(s.width, 1080)
        XCTAssertEqual(s.height, 1)
    }
}
