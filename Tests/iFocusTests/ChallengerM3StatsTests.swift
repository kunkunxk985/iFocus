import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

final class ChallengerM3StatsTests: XCTestCase {
    private var calendar: Calendar!
    private var baseDate: Date!

    override func setUpWithError() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1
        calendar = cal
        // Deterministic baseline: 2026-10-31 12:00:00 UTC
        baseDate = Date(timeIntervalSince1970: 1793448000)
    }

    // =========================================================================
    // MARK: - 1. Opacity Ladder Across All Levels & Boundary/Negative Levels
    // =========================================================================

    func testOpacityLadder_AllLevels() {
        // Standard 5-tier breathing ladder
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 0), 0.045, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 2), 0.50, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 3), 0.75, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 4), 1.00, accuracy: 0.0001)
    }

    func testOpacityLadder_BoundaryAndNegativeLevels() {
        // Boundary upper levels: 5, 100, Int.max clamp to default 1.00
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 5), 1.00, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 100), 1.00, accuracy: 0.0001)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: Int.max), 1.00, accuracy: 0.0001)

        // Boundary negative levels:
        // In ProfileHeatmapCard.opacity(for:), switch level handles 0, 1, 2, 3 explicitly,
        // and falls through to default: return 1.00 for level -1.
        let opacityNeg1 = ProfileHeatmapCard.opacity(for: -1)
        XCTAssertEqual(opacityNeg1, 1.00, accuracy: 0.0001, "Empirical observation: opacity(for: -1) falls through switch default to 1.00")
    }

    func testColorForLevel_ShieldingNegativeLevels() {
        // Empirical verification: colorForLevel guards with `if level <= 0`
        // which ensures level -1 and negative levels are visually shielded and treated as level 0
        let lightNeg1 = ProfileHeatmapCard.colorForLevel(-1, scheme: .light)
        let light0 = ProfileHeatmapCard.colorForLevel(0, scheme: .light)
        XCTAssertEqual(lightNeg1, light0, "colorForLevel must shield negative level by treating it as level 0")

        let darkNeg1 = ProfileHeatmapCard.colorForLevel(-1, scheme: .dark)
        let dark0 = ProfileHeatmapCard.colorForLevel(0, scheme: .dark)
        XCTAssertEqual(darkNeg1, dark0, "Dark mode colorForLevel must also shield negative levels")

        // In light mode, level 0 uses black.opacity(0.045)
        XCTAssertEqual(light0, Color.black.opacity(0.045))

        // In dark mode, level 0 uses white.opacity(0.06)
        XCTAssertEqual(dark0, Color.white.opacity(0.06))

        // Levels 1..4 use AppTheme.accent.opacity(opacity(for: level))
        XCTAssertEqual(ProfileHeatmapCard.colorForLevel(1, scheme: .light), AppTheme.accent.opacity(0.25))
        XCTAssertEqual(ProfileHeatmapCard.colorForLevel(2, scheme: .light), AppTheme.accent.opacity(0.50))
        XCTAssertEqual(ProfileHeatmapCard.colorForLevel(3, scheme: .light), AppTheme.accent.opacity(0.75))
        XCTAssertEqual(ProfileHeatmapCard.colorForLevel(4, scheme: .light), AppTheme.accent.opacity(1.00))
    }

    // =========================================================================
    // MARK: - 2. Heatmap Grid Structure Invariants (53 cols × 7 rows = 371 cells)
    // =========================================================================

    func testGridStructure_53Cols7Rows371Cells() {
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: baseDate,
            calendar: calendar,
            weeks: 53
        )

        // Column count must be exactly 53
        XCTAssertEqual(grid.count, 53, "Annual heatmap grid must have exactly 53 columns")

        var totalCells = 0
        for (colIdx, column) in grid.enumerated() {
            XCTAssertEqual(column.count, 7, "Column \(colIdx) must contain exactly 7 rows/cells")
            totalCells += column.count
        }

        // Total cell count must be exactly 371
        XCTAssertEqual(totalCells, 371, "Total cells in annual heatmap grid must be exactly 53 * 7 = 371")
    }

    func testGridStructure_ChronologicalContinuityAcrossAll371Cells() {
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: baseDate,
            calendar: calendar,
            weeks: 53
        )

        // Flatten the grid column by column
        let allCells = grid.flatMap { $0 }
        XCTAssertEqual(allCells.count, 371)

        // Verify that every consecutive cell is exactly 1 calendar day apart
        for i in 1..<allCells.count {
            let prevDate = allCells[i - 1].date
            let currDate = allCells[i].date
            let diffDays = calendar.dateComponents([.day], from: prevDate, to: currDate).day
            XCTAssertEqual(diffDays, 1, "Cell index \(i) must be exactly 1 day after cell \(i - 1)")
        }

        // The final cell in the last column must correspond to the end of the current week
        let lastCellDate = allCells.last!.date
        let today = calendar.startOfDay(for: baseDate)
        let currentWeekday = calendar.component(.weekday, from: today)
        let expectedLastOffset = 7 - currentWeekday
        let expectedLastDate = calendar.date(byAdding: .day, value: expectedLastOffset, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: lastCellDate), calendar.startOfDay(for: expectedLastDate))
    }

    // =========================================================================
    // MARK: - 3. Leap Year, Year Boundary & DST Robustness
    // =========================================================================

    func testGridStructure_LeapYearHandling() {
        // 2024 is a leap year (February has 29 days)
        let leapDate = Date(timeIntervalSince1970: 1709211600) // 2024-02-29 13:00:00 UTC
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: leapDate,
            calendar: calendar,
            weeks: 53
        )
        XCTAssertEqual(grid.count, 53)
        XCTAssertEqual(grid.flatMap { $0 }.count, 371)

        // Verify Feb 29, 2024 exists in the cells
        let hasFeb29 = grid.flatMap { $0 }.contains { cell in
            let comp = calendar.dateComponents([.year, .month, .day], from: cell.date)
            return comp.year == 2024 && comp.month == 2 && comp.day == 29
        }
        XCTAssertTrue(hasFeb29, "Leap year grid must contain February 29th")
    }

    func testGridStructure_YearBoundaryHandling() {
        // Test exactly at New Year: 2027-01-01 00:00:00 UTC
        let newYear = Date(timeIntervalSince1970: 1798761600)
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: newYear,
            calendar: calendar,
            weeks: 53
        )
        XCTAssertEqual(grid.count, 53)
        XCTAssertEqual(grid.flatMap { $0 }.count, 371)
    }

    // =========================================================================
    // MARK: - 4. Intensity Level Mapping Oracles & Edge Cases
    // =========================================================================

    func testIntensityLevel_ComprehensivePartitioning() {
        // Level 0: <= 0 minutes
        XCTAssertEqual(FocusStats.intensityLevel(minutes: Int.min), 0)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: -1000), 0)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: -1), 0)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 0), 0)

        // Level 1: 1...25 minutes
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 1), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 12), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 25), 1)

        // Level 2: 26...50 minutes
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 26), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 38), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 50), 2)

        // Level 3: 51...100 minutes
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 51), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 75), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 100), 3)

        // Level 4: > 100 minutes
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 101), 4)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 120), 4)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 10000), 4)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: Int.max), 4)
    }

    // =========================================================================
    // MARK: - 5. Tooltip Duration Formatting Fidelity
    // =========================================================================

    func testTooltipDurationFormatting() {
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(15), "15分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(59), "59分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(135), "2小时15分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(1440), "24小时")
    }

    // =========================================================================
    // MARK: - 6. Month Labels & Active Days Invariants
    // =========================================================================

    func testMonthLabels_AlignmentWithColumnIndices() {
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: baseDate,
            calendar: calendar,
            weeks: 53
        )
        let labels = FocusStats.monthLabels(for: grid, calendar: calendar)

        // All keys in monthLabels must be valid column indices within 0..<53
        for colIdx in labels.keys {
            XCTAssertTrue((0..<53).contains(colIdx), "Month label column index \(colIdx) must be in 0..<53")
            XCTAssertFalse(labels[colIdx]!.isEmpty, "Month label must not be empty string")
            XCTAssertTrue(labels[colIdx]!.hasSuffix("月"), "Month label should end with '月'")
        }
    }

    // =========================================================================
    // MARK: - 7. SwiftUI View Instantiation & Squircle Tokens
    // =========================================================================

    func testProfileHeatmapCard_ViewInstantiation() {
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: baseDate,
            calendar: calendar,
            weeks: 53
        )
        let labels = FocusStats.monthLabels(for: grid, calendar: calendar)
        let card = ProfileHeatmapCard(grid: grid, monthLabels: labels)
        XCTAssertNotNil(card.body)
    }
}
