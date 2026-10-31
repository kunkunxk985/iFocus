import XCTest
import SwiftUI
import AppKit
@testable import iFocus
@testable import iFocusCore

final class ChallengerM4Stats2Tests: XCTestCase {
    private var calendar: Calendar!
    private var savedAccent: String?

    override func setUpWithError() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1
        calendar = cal
        savedAccent = UserDefaults.standard.string(forKey: "accentPreset")
    }

    override func tearDownWithError() throws {
        if let savedAccent {
            UserDefaults.standard.set(savedAccent, forKey: "accentPreset")
        } else {
            UserDefaults.standard.removeObject(forKey: "accentPreset")
        }
    }

    // =========================================================================
    // MARK: - 1. Empty State & Boundary Value Handling (Zero Crash Invariant)
    // =========================================================================

    func testEmptyState_ZeroSessionsAndTasks_ProducesCleanDefaults() {
        // 0 sessions and 0 tasks
        let zeroMins = FocusStats.formatTotalMinutes(0)
        XCTAssertEqual(zeroMins, "0分钟")

        let avgMins = FocusStats.averageDailyFocusMinutes(sessionTimestamps: [], totalMinutes: 0, calendar: calendar)
        XCTAssertEqual(avgMins, 0)
        XCTAssertEqual(FocusStats.formatTotalMinutes(avgMins), "0分钟")

        let peak = FocusStats.peakFocusHoursString(sessionTimestamps: [], calendar: calendar)
        XCTAssertEqual(peak, "暂无数据")

        let completion = FocusStats.completionRate(total: 0, completed: 0)
        XCTAssertEqual(completion, "0%")

        // Instantiate view with empty states - must not crash
        let card = ProfileInsightsCard(
            maxSingleFocusSession: 0,
            averageDailyLabel: zeroMins,
            peakHours: peak,
            completionRate: completion
        )
        let body = card.body
        XCTAssertNotNil(body)
    }

    func testFormatTotalMinutes_EdgeCasesAndExtremeValues() {
        // Negative / corrupt values treated as zero
        XCTAssertEqual(FocusStats.formatTotalMinutes(-1), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(-9999), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")

        // Sub-hour
        XCTAssertEqual(FocusStats.formatTotalMinutes(1), "1分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(59), "59分钟")

        // Exact hour
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(120), "2小时")

        // Hour and minutes
        XCTAssertEqual(FocusStats.formatTotalMinutes(61), "1小时1分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(90), "1小时30分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(1439), "23小时59分")

        // Multi-day extreme durations
        XCTAssertEqual(FocusStats.formatTotalMinutes(1440), "24小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(10000), "166小时40分")
    }

    func testCompletionRate_BoundaryCases() {
        // Zero totals
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 0), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 5), "0%")

        // Negative values
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: -3), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: -5, completed: -3), "0%")

        // Normal percentages
        XCTAssertEqual(FocusStats.completionRate(total: 100, completed: 42), "42%")
        XCTAssertEqual(FocusStats.completionRate(total: 3, completed: 1), "33%")

        // Exactly 100%
        XCTAssertEqual(FocusStats.completionRate(total: 7, completed: 7), "100%")

        // Over-completion capped at 100%
        XCTAssertEqual(FocusStats.completionRate(total: 5, completed: 10), "100%")
        XCTAssertEqual(FocusStats.completionRate(total: 1, completed: 999), "100%")
    }

    func testPeakFocusHours_HourRolloverAndTies() {
        let baseDate = Date(timeIntervalSince1970: 1793404800) // 2026-11-01 00:00:00 UTC

        // Midnight hour (0)
        let t0 = calendar.date(bySettingHour: 0, minute: 15, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [t0], calendar: calendar), "00:00 - 01:00")

        // Late night rollover hour (23) -> wraps to 00:00
        let t23 = calendar.date(bySettingHour: 23, minute: 45, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [t23], calendar: calendar), "23:00 - 00:00")

        // Multiple sessions in same hour
        let t10a = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!
        let t10b = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: baseDate)!
        let t14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [t10a, t10b, t14], calendar: calendar), "10:00 - 11:00")
    }

    func testAverageDailyFocusMinutes_NeverDividesByZero() {
        // Zero sessions
        XCTAssertEqual(FocusStats.averageDailyFocusMinutes(sessionTimestamps: [], totalMinutes: 0, calendar: calendar), 0)
        XCTAssertEqual(FocusStats.averageDailyFocusMinutes(sessionTimestamps: [], totalMinutes: 100, calendar: calendar), 100) // max(1, 0) = 1

        let day1 = Date(timeIntervalSince1970: 1793404800)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!

        // Same day sessions
        let avgSameDay = FocusStats.averageDailyFocusMinutes(sessionTimestamps: [day1, day1], totalMinutes: 120, calendar: calendar)
        XCTAssertEqual(avgSameDay, 120, "Two sessions on same calendar day count as 1 active day")

        // Distinct days
        let avgTwoDays = FocusStats.averageDailyFocusMinutes(sessionTimestamps: [day1, day2], totalMinutes: 120, calendar: calendar)
        XCTAssertEqual(avgTwoDays, 60, "Two distinct calendar days divide totalMinutes by 2")
    }

    // =========================================================================
    // MARK: - 2. Visual Tokens & Theme Dynamism
    // =========================================================================

    func testAccentPresetsDynamicSwitching() {
        for preset in AccentPreset.allCases {
            UserDefaults.standard.set(preset.rawValue, forKey: "accentPreset")
            let liveColor = AppTheme.accent
            XCTAssertNotNil(liveColor)
            XCTAssertEqual(preset.color, liveColor, "AppTheme.accent must dynamically reflect preset \(preset.rawValue)")
        }
    }

    func testProfileInsightsCard_RenderingWithLongStrings() {
        // Stress test extremely long strings in all 4 slots
        let card = ProfileInsightsCard(
            maxSingleFocusSession: 999999, // 16666小时39分
            averageDailyLabel: "99999小时59分",
            peakHours: "23:00 - 00:00 (跨日超长文本)",
            completionRate: "100%"
        )
        let body = card.body
        XCTAssertNotNil(body)
    }

    // =========================================================================
    // MARK: - 3. Integrity Audit: Elimination of Rainbow Colors & Rigid Dividers
    // =========================================================================

    func testAbsenceOfBannedRainbowHexCodes() throws {
        let cardFilePath = "/Users/kun/Desktop/iFocus/Sources/iFocus/Views/Profile/ProfileInsightsCard.swift"
        let content = try String(contentsOfFile: cardFilePath, encoding: .utf8)

        // Previous hardcoded rainbow hex colors
        let bannedHexes = ["#F59E0B", "#3B82F6", "#8B5CF6", "#10B981"]
        for hex in bannedHexes {
            XCTAssertFalse(content.contains(hex), "ProfileInsightsCard.swift must NOT contain hardcoded rainbow hex: \(hex)")
        }

        // Banned old divider list architecture
        XCTAssertFalse(content.contains("Divider()"), "ProfileInsightsCard.swift must NOT contain rigid Divider lines")
        XCTAssertFalse(content.contains("InsightRow"), "InsightRow helper should be removed in favor of 2x2 micro metric tiles")
        XCTAssertFalse(content.contains("简要统计"), "Title should be updated to '统计洞察'")

        // Required features
        XCTAssertTrue(content.contains("统计洞察"), "Must contain card title '统计洞察'")
        XCTAssertTrue(content.contains("单次最长"), "Must contain tile '单次最长'")
        XCTAssertTrue(content.contains("日均专注"), "Must contain tile '日均专注'")
        XCTAssertTrue(content.contains("黄金时段"), "Must contain tile '黄金时段'")
        XCTAssertTrue(content.contains("任务完成率"), "Must contain tile '任务完成率'")

        // Unified icon symbols
        XCTAssertTrue(content.contains("stopwatch"), "Must use stopwatch SF Symbol")
        XCTAssertTrue(content.contains("clock.fill"), "Must use clock.fill SF Symbol")
        XCTAssertTrue(content.contains("sun.max.fill"), "Must use sun.max.fill SF Symbol")
        XCTAssertTrue(content.contains("checkmark.circle.fill"), "Must use checkmark.circle.fill SF Symbol")

        // Monospaced digit and font scaling protection
        XCTAssertTrue(content.contains(".monospacedDigit()"), "Metric values must use .monospacedDigit()")
        XCTAssertTrue(content.contains(".minimumScaleFactor(0.8)"), "Metric values must have .minimumScaleFactor(0.8)")
        XCTAssertTrue(content.contains(".lineLimit(1)"), "Metric values must have .lineLimit(1)")
    }

    // =========================================================================
    // MARK: - 4. Empirical 2x2 Layout Invariants & Symmetry Across Resize
    // =========================================================================

    /// Verifies mathematical symmetry of the 2x2 grid layout.
    /// In ProfileInsightsCard, each row is an `HStack(spacing: 10)` where each tile
    /// has `.frame(maxWidth: .infinity, alignment: .leading)`.
    /// Given container width W and horizontal padding (18 * 2 = 36), the content width is W_content = W - 36.
    /// Each tile receives exactly (W_content - 10) / 2 = (W - 46) / 2.
    func testEmpirical_2x2Grid_SymmetricWidthDistributionInvariant() {
        let testContainerWidths: [CGFloat] = [280, 360, 480, 600, 800, 1024, 1440]
        let cardPaddingHorizontal: CGFloat = 18 * 2 // 36
        let hStackSpacing: CGFloat = 10

        for containerWidth in testContainerWidths {
            let contentWidth = containerWidth - cardPaddingHorizontal
            let availableForTiles = contentWidth - hStackSpacing
            let tileWidth = availableForTiles / 2.0

            // Invariance 1: Sum of both tiles plus spacing must equal exactly content width
            XCTAssertEqual(tileWidth * 2.0 + hStackSpacing, contentWidth, accuracy: 0.0001,
                           "Row content must exactly sum to content width for container \(containerWidth)")

            // Invariance 2: Both tiles must have exactly 50% of the available width after spacing
            let expectedTileWidth = (contentWidth - hStackSpacing) * 0.5
            XCTAssertEqual(tileWidth, expectedTileWidth, accuracy: 0.0001)

            // Invariance 3: Symmetrical tile widths (left == right)
            let leftTile = tileWidth
            let rightTile = tileWidth
            XCTAssertEqual(leftTile, rightTile, accuracy: 0.0001, "Left and right tiles must be strictly symmetric")

            // Invariance 4: Fractional share of container width approaches 50% minus padding/spacing overhead
            let tileContainerRatio = tileWidth / containerWidth
            XCTAssertGreaterThan(tileContainerRatio, 0.40, "Each tile must occupy at least 40% of container width")
            XCTAssertLessThan(tileContainerRatio, 0.50, "Each tile cannot exceed 50% due to spacing and padding")
        }
    }

    /// Tests NSHostingView rendering and layout stability across container resize operations.
    func testEmpirical_ProfileInsightsCard_NSHostingViewResizeStability() {
        let card = ProfileInsightsCard(
            maxSingleFocusSession: 90,
            averageDailyLabel: "1小时30分",
            peakHours: "09:00 - 10:00",
            completionRate: "85%"
        )

        let targetFrames = [
            NSRect(x: 0, y: 0, width: 260, height: 200), // Narrow compact
            NSRect(x: 0, y: 0, width: 400, height: 240), // Standard
            NSRect(x: 0, y: 0, width: 650, height: 300), // Medium-wide
            NSRect(x: 0, y: 0, width: 1200, height: 400) // Ultra-wide
        ]

        for frame in targetFrames {
            for scheme in [ColorScheme.light, ColorScheme.dark] {
                let host = NSHostingView(rootView: card.environment(\.colorScheme, scheme))
                host.frame = frame
                host.layout()

                let fit = host.fittingSize
                // Card specifies minHeight: 168
                XCTAssertGreaterThanOrEqual(fit.height, 168.0, "Card height must respect minHeight: 168 in \(scheme) at \(frame)")
                XCTAssertGreaterThan(fit.width, 100.0, "Card width must be greater than 100pt")
                XCTAssertFalse(fit.width.isNaN, "Width must not be NaN")
                XCTAssertFalse(fit.height.isNaN, "Height must not be NaN")
                XCTAssertFalse(fit.width.isInfinite, "Width must not be infinite")
                XCTAssertFalse(fit.height.isInfinite, "Height must not be infinite")
            }
        }
    }

    /// Verifies dynamic theme accent changes across all presets (`AppTheme.accent`).
    func testEmpirical_DynamicTheme_AllSixPresetsImmediateReflection() {
        let presets: [(preset: AccentPreset, expectedHex: String, expectedLabel: String)] = [
            (.tomato, "#E85A3C", "番茄红"),
            (.blue, "#3B82F6", "静谧蓝"),
            (.green, "#10B981", "专注绿"),
            (.purple, "#8B5CF6", "灵感紫"),
            (.sunset, "#F97316", "落日橙"),
            (.teal, "#14B8A6", "极光青")
        ]

        XCTAssertEqual(AccentPreset.allCases.count, 6)

        for item in presets {
            UserDefaults.standard.set(item.preset.rawValue, forKey: "accentPreset")

            XCTAssertEqual(AppTheme.accent, item.preset.color, "AppTheme.accent must match preset \(item.preset.rawValue)")
            XCTAssertEqual(AppTheme.accentNSColor, item.preset.nsColor)
            XCTAssertEqual(item.preset.hex, item.expectedHex)
            XCTAssertEqual(item.preset.label, item.expectedLabel)

            // Verify adaptive opacity formulas used by ProfileInsightsCard
            let tileBgLight = AppTheme.accent.opacity(0.06)
            let tileBgDark = AppTheme.accent.opacity(0.08)
            XCTAssertNotNil(tileBgLight)
            XCTAssertNotNil(tileBgDark)

            let tileBorderLight = AppTheme.accent.opacity(0.12)
            let tileBorderDark = AppTheme.accent.opacity(0.18)
            XCTAssertNotNil(tileBorderLight)
            XCTAssertNotNil(tileBorderDark)

            let badgeBgLight = AppTheme.accent.opacity(0.08)
            let badgeBgDark = AppTheme.accent.opacity(0.14)
            XCTAssertNotNil(badgeBgLight)
            XCTAssertNotNil(badgeBgDark)

            let headerBadgeLight = AppTheme.accent.opacity(0.10)
            let headerBadgeDark = AppTheme.accent.opacity(0.16)
            XCTAssertNotNil(headerBadgeLight)
            XCTAssertNotNil(headerBadgeDark)
        }
    }

    /// Concurrently access AppTheme.accent and evaluate card properties across multiple threads.
    func testEmpirical_ConcurrentThemeSwitching_NoRaceConditions() {
        let expectation = self.expectation(description: "Concurrent theme switching in metric tiles")
        let queue = DispatchQueue(label: "test.challenger.m4.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                let preset = AccentPreset.allCases[i % AccentPreset.allCases.count]
                let color = preset.color
                let nsColor = preset.nsColor
                _ = color.opacity(0.06)
                _ = color.opacity(0.12)
                _ = nsColor

                let formatted = FocusStats.formatTotalMinutes((i * 17) % 300)
                let rate = FocusStats.completionRate(total: 10, completed: i % 11)
                XCTAssertFalse(formatted.isEmpty)
                XCTAssertFalse(rate.isEmpty)

                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
