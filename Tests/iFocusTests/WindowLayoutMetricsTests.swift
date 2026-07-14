import XCTest
@testable import iFocus

final class WindowLayoutMetricsTests: XCTestCase {
    func testMinIsTighterThanReference() {
        let min = WindowLayoutMetrics(
            width: WindowLayoutMetrics.minimum.width,
            height: WindowLayoutMetrics.minimum.height
        )
        let ref = WindowLayoutMetrics(
            width: WindowLayoutMetrics.reference.width,
            height: WindowLayoutMetrics.reference.height
        )
        XCTAssertLessThan(min.scale, ref.scale)
        XCTAssertLessThan(min.ringPreferred, ref.ringPreferred)
        XCTAssertLessThan(min.sectionSpacing, ref.sectionSpacing)
        XCTAssertLessThan(min.controlMainSize, ref.controlMainSize)
        XCTAssertEqual(min.fluid, 0, accuracy: 0.02)
        XCTAssertEqual(ref.fluid, 1, accuracy: 0.05)
    }

    func testContinuousGrowthBetweenSizes() {
        let a = WindowLayoutMetrics(width: 1100, height: 740)
        let b = WindowLayoutMetrics(width: 1200, height: 800)
        let c = WindowLayoutMetrics(width: 1400, height: 920)
        XCTAssertLessThan(a.scale, b.scale)
        XCTAssertLessThan(b.scale, c.scale)
        XCTAssertLessThan(a.ringPreferred, b.ringPreferred)
        XCTAssertLessThan(b.ringPreferred, c.ringPreferred)
    }

    func testHintsAppearAsHeightGrows() {
        let short = WindowLayoutMetrics(width: 1024, height: 700)
        let mid = WindowLayoutMetrics(width: 1100, height: 730)
        let tall = WindowLayoutMetrics(width: 1280, height: 860)
        XCTAssertFalse(short.showSessionHint)
        XCTAssertTrue(tall.showSessionHint)
        XCTAssertFalse(short.showControlLabels)
        XCTAssertTrue(mid.showControlLabels || tall.showControlLabels)
        XCTAssertTrue(tall.showControlLabels)
    }

    func testDensityScaleMultiplies() {
        let base = WindowLayoutMetrics(width: 1280, height: 860, densityScale: 1)
        let compact = WindowLayoutMetrics(width: 1280, height: 860, densityScale: 0.88)
        XCTAssertLessThan(compact.scale, base.scale)
        XCTAssertLessThan(compact.horizontalPadding, base.horizontalPadding)
    }
}
