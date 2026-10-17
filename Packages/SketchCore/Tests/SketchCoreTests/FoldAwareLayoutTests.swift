import XCTest
@testable import SketchCore

final class FoldAwareLayoutTests: XCTestCase {
    let inner = LayoutRect(x: 0, y: 0, width: 700, height: 800)

    func testFoldAcrossPutsCanvasOnTopAndDialsOnTheTableHalf() throws {
        let fold = LayoutRect(x: 0, y: 380, width: 700, height: 40)
        let split = try XCTUnwrap(FoldAwareLayout.split(inner, around: fold))
        XCTAssertEqual(split.axis, .vertical)
        XCTAssertEqual(split.canvas, LayoutRect(x: 0, y: 0, width: 700, height: 380))
        XCTAssertEqual(split.controls, LayoutRect(x: 0, y: 420, width: 700, height: 380))
        XCTAssertFalse(split.canvas.intersects(fold))
        XCTAssertFalse(split.controls.intersects(fold), "no dial sits in the fold")
    }

    func testFoldDownTheMiddlePutsDialsOnTheTrailingSide() throws {
        let fold = LayoutRect(x: 330, y: 0, width: 40, height: 800)
        let split = try XCTUnwrap(FoldAwareLayout.split(inner, around: fold))
        XCTAssertEqual(split.axis, .horizontal)
        XCTAssertEqual(split.canvas.maxX, 330)
        XCTAssertEqual(split.controls.minX, 370)
        XCTAssertEqual(split.controls.maxX, 700)
    }

    func testFoldOutsideOrTooCloseToAnEdgeIsIgnored() {
        XCTAssertNil(FoldAwareLayout.split(inner, around: LayoutRect(x: 0, y: 900, width: 700, height: 40)))
        XCTAssertNil(FoldAwareLayout.split(inner, around: LayoutRect(x: 0, y: 30, width: 700, height: 40)),
                     "a 30 pt canvas isn't worth having")
    }

    func testOcclusionIsCutOffAlongTheCheapestEdge() {
        // A camera near the top centre: losing the top 60 pt costs least.
        let camera = LayoutRect(x: 320, y: 0, width: 60, height: 60)
        XCTAssertEqual(FoldAwareLayout.avoiding(inner, occlusions: [camera]), LayoutRect(x: 0, y: 60, width: 700, height: 740))
        // A camera on the side: trim that side.
        let side = LayoutRect(x: 660, y: 360, width: 40, height: 60)
        let trimmed = FoldAwareLayout.avoiding(inner, occlusions: [side])
        XCTAssertEqual(trimmed, LayoutRect(x: 0, y: 0, width: 660, height: 800))
        XCTAssertFalse(trimmed.intersects(side))
        // Nothing to avoid.
        XCTAssertEqual(FoldAwareLayout.avoiding(inner, occlusions: []), inner)
        XCTAssertEqual(FoldAwareLayout.avoiding(inner, occlusions: [LayoutRect(x: 800, y: 0, width: 10, height: 10)]), inner)
    }

    func testDialsScaleWithTheSpaceButStayTouchable() {
        XCTAssertEqual(FoldAwareLayout.dialDiameter(width: 320, height: 600), 88, "never below 88 pt")
        XCTAssertEqual(FoldAwareLayout.dialDiameter(width: 700, height: 800), 132, "capped on the inner display")
        let mid = FoldAwareLayout.dialDiameter(width: 420, height: 420)
        XCTAssertGreaterThan(mid, 88)
        XCTAssertLessThan(mid, 132)
        let split = FoldAwareLayout.Split(
            canvas: LayoutRect(x: 0, y: 0, width: 700, height: 380),
            controls: LayoutRect(x: 0, y: 420, width: 700, height: 120),
            axis: .vertical
        )
        XCTAssertEqual(FoldAwareLayout.dialDiameter(for: split), 96, accuracy: 1e-9, "80% of a 120 pt tall controls area")
    }
}
