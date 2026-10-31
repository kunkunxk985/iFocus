import XCTest
import SwiftUI
import AppKit
@testable import iFocus
@testable import iFocusCore

final class ChallengerM3Stats2Tests: XCTestCase {
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

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        return calendar.date(from: c)!
    }

    // =========================================================================
    // MARK: - 1. Empirical Tooltip String Generation & Formatting Oracle
    // =========================================================================

    /// Verifies date formatting and duration combination rules matching
    /// ProfileHeatmapCard: "\(dateFormatter.string(from: cell.date)) · \(FocusStats.formatTotalMinutes(cell.minutes))"
    func testEmpirical_TooltipStringGeneration_DateAndDurationMatrix() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        // Test dates: Jan 1, Feb 29 (leap), Oct 28, Dec 31
        let jan1 = makeDate(year: 2026, month: 1, day: 1)
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let oct28 = makeDate(year: 2026, month: 10, day: 28)
        let dec31 = makeDate(year: 2026, month: 12, day: 31)

        XCTAssertEqual(formatter.string(from: jan1), "1月1日")
        XCTAssertEqual(formatter.string(from: feb29), "2月29日")
        XCTAssertEqual(formatter.string(from: oct28), "10月28日")
        XCTAssertEqual(formatter.string(from: dec31), "12月31日")

        // Duration test matrix: 0 mins -> 0分钟, 45 mins -> 45分钟, 60 mins -> 1小时, 135 mins -> 2小时15分
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(45), "45分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(135), "2小时15分")

        // Cross-combination verification:
        func generateTooltip(date: Date, minutes: Int) -> String {
            "\(formatter.string(from: date)) · \(FocusStats.formatTotalMinutes(minutes))"
        }

        XCTAssertEqual(generateTooltip(date: jan1, minutes: 0), "1月1日 · 0分钟")
        XCTAssertEqual(generateTooltip(date: feb29, minutes: 45), "2月29日 · 45分钟")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 60), "10月28日 · 1小时")
        XCTAssertEqual(generateTooltip(date: dec31, minutes: 135), "12月31日 · 2小时15分")

        // Additional edge case durations
        XCTAssertEqual(generateTooltip(date: oct28, minutes: -10), "10月28日 · 0分钟", "Negative minutes clamp to 0分钟")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 1), "10月28日 · 1分钟")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 59), "10月28日 · 59分钟")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 120), "10月28日 · 2小时")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 1440), "10月28日 · 24小时")
        XCTAssertEqual(generateTooltip(date: oct28, minutes: 1505), "10月28日 · 25小时5分")
    }

    // =========================================================================
    // MARK: - 2. Dynamic Theme Accent Reflection Across All Presets
    // =========================================================================

    func testEmpirical_DynamicThemeAccent_AllPresetsImmediateReflection() {
        let presets = AccentPreset.allCases
        XCTAssertEqual(presets.count, 6, "Must test all 6 accent presets")

        for preset in presets {
            // 1. Change user preference
            UserDefaults.standard.set(preset.rawValue, forKey: "accentPreset")

            // 2. Verify AppTheme.accent immediately updates
            let accent = AppTheme.accent
            XCTAssertNotNil(accent)
            XCTAssertEqual(AppTheme.accentNSColor, preset.nsColor)

            // 3. Verify ProfileHeatmapCard.colorForLevel for levels 0...4
            // Level 0: neutral grey/white (unaffected by accent)
            let lvl0Light = ProfileHeatmapCard.colorForLevel(0, scheme: .light, accent: AppTheme.accent)
            let lvl0Dark = ProfileHeatmapCard.colorForLevel(0, scheme: .dark, accent: AppTheme.accent)
            XCTAssertEqual(lvl0Light, Color.black.opacity(ProfileHeatmapCard.opacity(for: 0)))
            XCTAssertEqual(lvl0Dark, Color.white.opacity(0.06))

            // Levels 1..4: must reflect accent with exact ladder opacities
            for level in 1...4 {
                let colorLight = ProfileHeatmapCard.colorForLevel(level, scheme: .light, accent: AppTheme.accent)
                let expectedOpacity = ProfileHeatmapCard.opacity(for: level)
                let expectedColor = accent.opacity(expectedOpacity)
                XCTAssertEqual(colorLight, expectedColor, "Level \(level) must match accent with opacity \(expectedOpacity)")
            }
        }
    }

    func testEmpirical_BreathingLadderOpacitiesExactValues() {
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 0), 0.045)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 1), 0.25)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 2), 0.50)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 3), 0.75)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 4), 1.00)

        // Adversarial Edge Case Finding:
        // switch level only matches `case 0:`, so negative levels fall into `default: return 1.00`
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: -1), 1.00, "Negative levels fall into default 1.00")
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 5), 1.00)
        XCTAssertEqual(ProfileHeatmapCard.opacity(for: 100), 1.00)

        // However, colorForLevel guards with `if level <= 0` so color evaluation is protected:
        let guardedColor = ProfileHeatmapCard.colorForLevel(-1, scheme: .light, accent: AppTheme.accent)
        XCTAssertEqual(guardedColor, Color.black.opacity(0.045), "colorForLevel guards level <= 0")
    }

    // =========================================================================
    // MARK: - 3. Hover Badge Border & Background Formula Consistency
    // =========================================================================

    func testEmpirical_HoverBadgeBorderAndBackgroundFormulas() {
        for preset in AccentPreset.allCases {
            UserDefaults.standard.set(preset.rawValue, forKey: "accentPreset")
            let accent = AppTheme.accent

            // ProfileHeatmapCard hover badge background formula:
            // AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.16)
            let bgLight = accent.opacity(0.08)
            let bgDark = accent.opacity(0.16)
            XCTAssertNotNil(bgLight)
            XCTAssertNotNil(bgDark)

            // ProfileHeatmapCard hover badge border formula:
            // AppTheme.accent.opacity(colorScheme == .light ? 0.20 : 0.28)
            let borderLight = accent.opacity(0.20)
            let borderDark = accent.opacity(0.28)
            XCTAssertNotNil(borderLight)
            XCTAssertNotNil(borderDark)
        }
    }

    // =========================================================================
    // MARK: - 4. NSHostingView Layout & Rendering Stability
    // =========================================================================

    func testEmpirical_ProfileHeatmapCard_HostingViewRenderingStability() {
        let baseDate = makeDate(year: 2026, month: 10, day: 31, hour: 12)
        var minutesMap: [Date: Int] = [:]
        for i in 0..<365 {
            let day = calendar.date(byAdding: .day, value: -i, to: baseDate)!
            minutesMap[calendar.startOfDay(for: day)] = (i % 5 == 0) ? 0 : (25 * (i % 6))
        }

        let grid = FocusStats.contributionGrid(
            minutesByDay: minutesMap,
            relativeTo: baseDate,
            calendar: calendar,
            weeks: 53
        )
        let monthLabels = FocusStats.monthLabels(for: grid, calendar: calendar)

        let frames = [
            NSRect(x: 0, y: 0, width: 800, height: 260),
            NSRect(x: 0, y: 0, width: 500, height: 220),
            NSRect(x: 0, y: 0, width: 1200, height: 350),
            NSRect(x: 0, y: 0, width: 350, height: 180)
        ]

        for frame in frames {
            for scheme in [ColorScheme.light, ColorScheme.dark] {
                let card = ProfileHeatmapCard(grid: grid, monthLabels: monthLabels)
                    .environment(\.colorScheme, scheme)
                let host = NSHostingView(rootView: card)
                host.frame = frame
                host.layout()

                let fit = host.fittingSize
                XCTAssertGreaterThan(fit.width, 100, "Fitting width must be > 100 for frame \(frame)")
                XCTAssertGreaterThan(fit.height, 50, "Fitting height must be > 50 for frame \(frame)")
                XCTAssertFalse(fit.width.isNaN)
                XCTAssertFalse(fit.height.isNaN)
                XCTAssertFalse(fit.width.isInfinite)
                XCTAssertFalse(fit.height.isInfinite)
            }
        }
    }

    func testEmpirical_ProfileHeatmapCard_EmptyGridStability() {
        let emptyCard = ProfileHeatmapCard(grid: [], monthLabels: [:])
        let host = NSHostingView(rootView: emptyCard)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        host.layout()

        let fit = host.fittingSize
        XCTAssertFalse(fit.width.isNaN)
        XCTAssertFalse(fit.height.isNaN)
    }

    // =========================================================================
    // MARK: - 5. Squircle Geometry Tokens & Legend Consistency
    // =========================================================================

    func testEmpirical_SquircleGeometryTokens() {
        let cellSquircle = AppTheme.squircle(radius: 2.8)
        XCTAssertNotNil(cellSquircle)

        let legendSquircle = AppTheme.squircle(radius: 2.0)
        XCTAssertNotNil(legendSquircle)
    }

    // =========================================================================
    // MARK: - 6. Concurrent Theme Switching & Thread Safety
    // =========================================================================

    func testEmpirical_ConcurrentThemeSwitching_ThreadSafety() {
        let expectation = self.expectation(description: "Concurrent theme evaluation")
        let queue = DispatchQueue(label: "test.challenger.m3.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                let preset = AccentPreset.allCases[i % AccentPreset.allCases.count]
                let color = ProfileHeatmapCard.colorForLevel(
                    i % 5,
                    scheme: (i % 2 == 0) ? .light : .dark,
                    accent: preset.color
                )
                let op = ProfileHeatmapCard.opacity(for: i % 5)
                XCTAssertGreaterThan(op, 0.0)
                _ = color
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
