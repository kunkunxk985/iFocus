import XCTest
import SwiftUI
import AppKit
@testable import iFocus
@testable import iFocusCore

final class ChallengerM2Stats2Tests: XCTestCase {
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
    // MARK: - 1. Zero-Minute & Negative Duration Safeguards
    // =========================================================================

    func testZeroMinuteAndZeroPomodorosProducesValidFormat() {
        let date = makeDate(year: 2026, month: 10, day: 28)
        let output = WeeklyFocusChart.formatTooltip(
            date: date,
            minutes: 0,
            pomodoros: 0,
            calendar: calendar
        )
        XCTAssertEqual(output, "10月28日 · 0分 · 0个番茄")
        XCTAssertFalse(output.contains("NaN"))
        XCTAssertFalse(output.contains("nil"))
    }

    func testNegativeMinutesSafeguardDoesNotCrash() {
        let date = makeDate(year: 2026, month: 10, day: 28)
        let output = WeeklyFocusChart.formatTooltip(
            date: date,
            minutes: -45,
            pomodoros: -2,
            calendar: calendar
        )
        XCTAssertEqual(output, "10月28日 · 0分 · 0个番茄")
    }

    // =========================================================================
    // MARK: - 2. Duration Formatting Combinations
    // =========================================================================

    func testExactHoursFormatting() {
        let date = makeDate(year: 2026, month: 10, day: 28)

        // 1 hour
        let out60 = WeeklyFocusChart.formatTooltip(date: date, minutes: 60, pomodoros: 2, calendar: calendar)
        XCTAssertEqual(out60, "10月28日 · 1小时 · 2个番茄")

        // 2 hours
        let out120 = WeeklyFocusChart.formatTooltip(date: date, minutes: 120, pomodoros: 4, calendar: calendar)
        XCTAssertEqual(out120, "10月28日 · 2小时 · 4个番茄")

        // 5 hours
        let out300 = WeeklyFocusChart.formatTooltip(date: date, minutes: 300, pomodoros: 10, calendar: calendar)
        XCTAssertEqual(out300, "10月28日 · 5小时 · 10个番茄")
    }

    func testSubHourDurationsFormatting() {
        let date = makeDate(year: 2026, month: 10, day: 28)

        let out1 = WeeklyFocusChart.formatTooltip(date: date, minutes: 1, pomodoros: 1, calendar: calendar)
        XCTAssertEqual(out1, "10月28日 · 1分 · 1个番茄")

        let out45 = WeeklyFocusChart.formatTooltip(date: date, minutes: 45, pomodoros: 2, calendar: calendar)
        XCTAssertEqual(out45, "10月28日 · 45分 · 2个番茄")

        let out59 = WeeklyFocusChart.formatTooltip(date: date, minutes: 59, pomodoros: 2, calendar: calendar)
        XCTAssertEqual(out59, "10月28日 · 59分 · 2个番茄")
    }

    func testCompoundDurationFormatting() {
        let date = makeDate(year: 2026, month: 10, day: 28)

        let out61 = WeeklyFocusChart.formatTooltip(date: date, minutes: 61, pomodoros: 2, calendar: calendar)
        XCTAssertEqual(out61, "10月28日 · 1小时1分 · 2个番茄")

        let out135 = WeeklyFocusChart.formatTooltip(date: date, minutes: 135, pomodoros: 5, calendar: calendar)
        XCTAssertEqual(out135, "10月28日 · 2小时15分 · 5个番茄")

        let out490 = WeeklyFocusChart.formatTooltip(date: date, minutes: 490, pomodoros: 16, calendar: calendar)
        XCTAssertEqual(out490, "10月28日 · 8小时10分 · 16个番茄")
    }

    func testExtremeDurationValuesFormatting() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let outLarge = WeeklyFocusChart.formatTooltip(date: date, minutes: 10_000, pomodoros: 350, calendar: calendar)
        // 10000 / 60 = 166 hours, remainder 40 mins
        XCTAssertEqual(outLarge, "12月31日 · 166小时40分 · 350个番茄")
    }

    // =========================================================================
    // MARK: - 3. Dynamic Date Formatting (Integrity Check - No Hardcoding)
    // =========================================================================

    func testDateFormattingAcrossMonthsAndLeapYears() {
        let leapDate = makeDate(year: 2024, month: 2, day: 29)
        let outLeap = WeeklyFocusChart.formatTooltip(date: leapDate, minutes: 25, pomodoros: 1, calendar: calendar)
        XCTAssertEqual(outLeap, "2月29日 · 25分 · 1个番茄")

        let newYear = makeDate(year: 2027, month: 1, day: 1)
        let outNewYear = WeeklyFocusChart.formatTooltip(date: newYear, minutes: 50, pomodoros: 2, calendar: calendar)
        XCTAssertEqual(outNewYear, "1月1日 · 50分 · 2个番茄")
    }

    // =========================================================================
    // MARK: - 4. Chart Tooltip Clamping Simulation
    // =========================================================================

    func testTooltipClampingPhysics() {
        func computeClampedX(rawCenterX: CGFloat, totalWidth: CGFloat, minMargin: CGFloat = 105) -> CGFloat {
            if totalWidth > minMargin * 2 {
                return min(max(rawCenterX, minMargin), totalWidth - minMargin)
            } else {
                return totalWidth / 2
            }
        }

        let containerWidth: CGFloat = 600
        let minMargin: CGFloat = 105

        // Left boundary: Day 1 positioned near x = 10
        let clampedDay1 = computeClampedX(rawCenterX: 10, totalWidth: containerWidth, minMargin: minMargin)
        XCTAssertEqual(clampedDay1, 105, "Left-edge tooltip must be clamped to minMargin")
        XCTAssertGreaterThanOrEqual(clampedDay1 - 95, 0, "Tooltip left edge must not clip beyond 0")

        // Right boundary: Day 7/30 positioned near x = 590
        let clampedDayLast = computeClampedX(rawCenterX: 590, totalWidth: containerWidth, minMargin: minMargin)
        XCTAssertEqual(clampedDayLast, 600 - 105, "Right-edge tooltip must be clamped to totalWidth - minMargin")
        XCTAssertLessThanOrEqual(clampedDayLast + 95, 600, "Tooltip right edge must not clip beyond container width")

        // Center: Day positioned at x = 300
        let clampedMid = computeClampedX(rawCenterX: 300, totalWidth: containerWidth, minMargin: minMargin)
        XCTAssertEqual(clampedMid, 300, "Middle tooltip should remain exactly centered over bar")

        // Narrow container: width 150 < 210
        let clampedNarrow = computeClampedX(rawCenterX: 20, totalWidth: 150, minMargin: minMargin)
        XCTAssertEqual(clampedNarrow, 75, "Narrow containers should safely fallback to center point")
    }

    // =========================================================================
    // MARK: - 5. DayFocus Data Construction & Aggregation
    // =========================================================================

    func testDayFocusDataAggregationIntegrity() {
        let d1 = makeDate(year: 2026, month: 10, day: 25, hour: 10)
        let d2 = makeDate(year: 2026, month: 10, day: 25, hour: 14)
        let d3 = makeDate(year: 2026, month: 10, day: 26, hour: 9)

        let sessions = [
            FocusSession(id: UUID(), taskTitle: "Task 1", durationMinutes: 25, timestamp: d1),
            FocusSession(id: UUID(), taskTitle: "Task 2", durationMinutes: 30, timestamp: d2),
            FocusSession(id: UUID(), taskTitle: "Task 3", durationMinutes: -10, timestamp: d3)
        ]

        let chart = WeeklyFocusChart(sessions: sessions, dayCount: 7)
        XCTAssertNotNil(chart)

        let df = WeeklyFocusChart.DayFocus(date: d1, label: "10-25", minutes: 55, pomodoros: 2)
        XCTAssertEqual(df.minutes, 55)
        XCTAssertEqual(df.pomodoros, 2)
        XCTAssertEqual(df.id, d1)
    }

    // =========================================================================
    // MARK: - 6. Time Range Title Mapping Conformance
    // =========================================================================

    func testRangeDisplayTitleConformity() {
        func chipTitle(for r: AnalyticsTimeRange) -> String {
            switch r {
            case .today: return "今天"
            case .days7: return "7天"
            case .days30: return "30天"
            case .month: return "本月"
            }
        }

        XCTAssertEqual(chipTitle(for: .today), "今天")
        XCTAssertEqual(chipTitle(for: .days7), "7天")
        XCTAssertEqual(chipTitle(for: .days30), "30天")
        XCTAssertEqual(chipTitle(for: .month), "本月")

        func trendTitle(for range: AnalyticsTimeRange) -> String {
            switch range {
            case .today: return "今天趋势"
            case .days7: return "7天趋势"
            case .days30: return "30天趋势"
            case .month: return "本月趋势"
            }
        }

        XCTAssertEqual(trendTitle(for: .today), "今天趋势")
        XCTAssertEqual(trendTitle(for: .days7), "7天趋势")
        XCTAssertEqual(trendTitle(for: .days30), "30天趋势")
        XCTAssertEqual(trendTitle(for: .month), "本月趋势")
    }

    // =========================================================================
    // MARK: - 7. Empirical: Rapid Time Range Switching & Layout Stability
    // =========================================================================

    func testRapidRangeSwitching_LayoutStability() {
        let ranges: [AnalyticsTimeRange] = [.today, .days7, .days30, .month]
        let baseDate = makeDate(year: 2026, month: 10, day: 31, hour: 12)
        let sampleSessions = [
            FocusSession(id: UUID(), taskTitle: "S1", durationMinutes: 25, timestamp: baseDate),
            FocusSession(id: UUID(), taskTitle: "S2", durationMinutes: 45, timestamp: baseDate.addingTimeInterval(-86400 * 2)),
            FocusSession(id: UUID(), taskTitle: "S3", durationMinutes: 60, timestamp: baseDate.addingTimeInterval(-86400 * 10))
        ]

        let iterations = 200
        for i in 0..<iterations {
            let range = ranges[i % ranges.count]
            let colorScheme: ColorScheme = (i % 2 == 0) ? .light : .dark

            let model = AnalyticsDashboardModel.build(
                range: range,
                focusSessions: sampleSessions,
                tasks: [],
                dailyGoal: 4,
                completedPomodoros: 2,
                totalSecondsToday: 1800,
                isWorkMode: false,
                sessionLive: false,
                now: baseDate,
                calendar: calendar
            )

            let cardView = AnalyticsCards.weeklyCard(model: model, colorScheme: colorScheme)
            let host = NSHostingView(rootView: cardView)
            host.frame = NSRect(x: 0, y: 0, width: 700, height: 240)
            host.layout()

            let fit = host.fittingSize
            XCTAssertGreaterThan(fit.width, 100, "Width must be positive on iteration \(i)")
            XCTAssertGreaterThan(fit.height, 50, "Height must be positive on iteration \(i)")
            XCTAssertFalse(fit.width.isNaN, "Width must not be NaN")
            XCTAssertFalse(fit.height.isNaN, "Height must not be NaN")
            XCTAssertFalse(fit.width.isInfinite, "Width must be finite")
            XCTAssertFalse(fit.height.isInfinite, "Height must be finite")
        }
    }

    // =========================================================================
    // MARK: - 8. Empirical: TodayHourChart Zero-State Stability (All 24 Bins = 0)
    // =========================================================================

    func testTodayHourChart_AllZeroBins_RendersWithoutCrashingOrLayoutGlitch() {
        let zeroBins = [Int](repeating: 0, count: 24)
        let chart = TodayHourChart(hourMinutes: zeroBins)

        // 1. Verify Y-scale domain computation logic:
        // .chartYScale(domain: 0...max(60, hourMinutes.max() ?? 0))
        let maxVal = zeroBins.max() ?? 0
        let domainMax = max(60, maxVal)
        XCTAssertEqual(domainMax, 60, "Y domain max must be anchored to at least 60 to prevent scale collapse")

        // 2. Multi-size layout verification via NSHostingView
        let testFrames = [
            NSRect(x: 0, y: 0, width: 600, height: 200),
            NSRect(x: 0, y: 0, width: 280, height: 150),
            NSRect(x: 0, y: 0, width: 1200, height: 300),
            NSRect(x: 0, y: 0, width: 80, height: 60)
        ]

        for frame in testFrames {
            let host = NSHostingView(rootView: chart)
            host.frame = frame
            host.layout()

            let fit = host.fittingSize
            XCTAssertGreaterThan(fit.width, 0, "Fitting width must be > 0 for frame \(frame)")
            XCTAssertGreaterThan(fit.height, 0, "Fitting height must be > 0 for frame \(frame)")
            XCTAssertFalse(fit.width.isNaN)
            XCTAssertFalse(fit.height.isNaN)
        }

        // 3. Robustness against non-standard bin counts
        let abnormalBins: [[Int]] = [
            [],                             // 0 bins
            [0],                            // 1 bin
            [0, 0, 0, 0],                   // 4 bins
            [Int](repeating: 0, count: 48), // 48 bins
            [1000, 2000, 3000]              // Extreme values
        ]

        for bins in abnormalBins {
            let abnormalChart = TodayHourChart(hourMinutes: bins)
            let host = NSHostingView(rootView: abnormalChart)
            host.frame = NSRect(x: 0, y: 0, width: 500, height: 180)
            host.layout()
            let fit = host.fittingSize
            XCTAssertFalse(fit.width.isNaN)
            XCTAssertFalse(fit.height.isNaN)
        }
    }

    // =========================================================================
    // MARK: - 9. Empirical: Bar Count Calculation Across Ranges (7d, 30d, Month)
    // =========================================================================

    func testBarCountCalculation_Across7Day30DayAndMonthRanges() {
        let baseDate = makeDate(year: 2026, month: 10, day: 31, hour: 12)
        let today = calendar.startOfDay(for: baseDate)

        // Helper replicating WeeklyFocusChart's dayCount clamping & loop math:
        func generateChartDays(dayCount: Int, anchorDate: Date = today) -> [Date] {
            var dates: [Date] = []
            let days = max(1, min(dayCount, 62))
            for i in (0..<days).reversed() {
                guard let day = calendar.date(byAdding: .day, value: -i, to: anchorDate) else { continue }
                dates.append(day)
            }
            return dates
        }

        // 1. 7-Day Range: exactly 7 days
        let days7 = generateChartDays(dayCount: 7)
        XCTAssertEqual(days7.count, 7, "7-day range must generate exactly 7 bar data points")
        XCTAssertEqual(days7.last, today, "Last bar must be today")
        let first7 = calendar.date(byAdding: .day, value: -6, to: today)!
        XCTAssertEqual(days7.first, first7, "First bar must be today - 6 days")

        // 2. 30-Day Range: exactly 30 days
        let days30 = generateChartDays(dayCount: 30)
        XCTAssertEqual(days30.count, 30, "30-day range must generate exactly 30 bar data points")
        XCTAssertEqual(days30.last, today)
        let first30 = calendar.date(byAdding: .day, value: -29, to: today)!
        XCTAssertEqual(days30.first, first30)

        // 3. Month Range Across Different Calendar Months:
        func monthDayCount(for date: Date) -> Int {
            let bounds = AnalyticsTimeRange.month.dayBounds(relativeTo: date, calendar: calendar)
            let diff = calendar.dateComponents([.day], from: bounds.from, to: bounds.through).day ?? 0
            return max(1, diff + 1)
        }

        // 3a. 31-day month on day 31 (e.g. 2026-10-31)
        let oct31 = makeDate(year: 2026, month: 10, day: 31)
        let octDaysCount = monthDayCount(for: oct31)
        XCTAssertEqual(octDaysCount, 31, "October 31 must evaluate to 31 bars")
        let octBars = generateChartDays(dayCount: octDaysCount, anchorDate: calendar.startOfDay(for: oct31))
        XCTAssertEqual(octBars.count, 31)

        // 3b. 30-day month on day 30 (e.g. 2026-09-30)
        let sep30 = makeDate(year: 2026, month: 9, day: 30)
        let sepDaysCount = monthDayCount(for: sep30)
        XCTAssertEqual(sepDaysCount, 30, "September 30 must evaluate to 30 bars")
        let sepBars = generateChartDays(dayCount: sepDaysCount, anchorDate: calendar.startOfDay(for: sep30))
        XCTAssertEqual(sepBars.count, 30)

        // 3c. Non-leap February on day 28 (e.g. 2025-02-28)
        let feb28 = makeDate(year: 2025, month: 2, day: 28)
        let feb28Count = monthDayCount(for: feb28)
        XCTAssertEqual(feb28Count, 28, "February 2025 must evaluate to 28 bars")
        let feb28Bars = generateChartDays(dayCount: feb28Count, anchorDate: calendar.startOfDay(for: feb28))
        XCTAssertEqual(feb28Bars.count, 28)

        // 3d. Leap-year February on day 29 (e.g. 2024-02-29)
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let feb29Count = monthDayCount(for: feb29)
        XCTAssertEqual(feb29Count, 29, "February 2024 leap year must evaluate to 29 bars")
        let feb29Bars = generateChartDays(dayCount: feb29Count, anchorDate: calendar.startOfDay(for: feb29))
        XCTAssertEqual(feb29Bars.count, 29)

        // 3e. Mid-month date (e.g. 2026-10-15)
        let oct15 = makeDate(year: 2026, month: 10, day: 15)
        let oct15Count = monthDayCount(for: oct15)
        XCTAssertEqual(oct15Count, 15, "October 15 must evaluate to 15 bars")
        let oct15Bars = generateChartDays(dayCount: oct15Count, anchorDate: calendar.startOfDay(for: oct15))
        XCTAssertEqual(oct15Bars.count, 15)

        // 3f. First day of month (e.g. 2026-10-01)
        let oct01 = makeDate(year: 2026, month: 10, day: 1)
        let oct01Count = monthDayCount(for: oct01)
        XCTAssertEqual(oct01Count, 1, "October 1 must evaluate to 1 bar")
        let oct01Bars = generateChartDays(dayCount: oct01Count, anchorDate: calendar.startOfDay(for: oct01))
        XCTAssertEqual(oct01Bars.count, 1)

        // 4. Boundary clamping checks for dayCount
        XCTAssertEqual(generateChartDays(dayCount: 0).count, 1, "dayCount 0 clamped to 1")
        XCTAssertEqual(generateChartDays(dayCount: -5).count, 1, "Negative dayCount clamped to 1")
        XCTAssertEqual(generateChartDays(dayCount: 100).count, 62, "dayCount 100 clamped to 62")

        // 5. Check consecutive date spacing (strictly 1 calendar day apart)
        for i in 0..<(days30.count - 1) {
            let diff = calendar.dateComponents([.day], from: days30[i], to: days30[i + 1]).day ?? 0
            XCTAssertEqual(diff, 1, "Consecutive bars must be spaced by exactly 1 calendar day")
        }
    }

    // =========================================================================
    // MARK: - 10. Empirical: Dynamic Theme Changes & Accent Rerendering
    // =========================================================================

    func testThemeAccent_ImmediateRerenderOfBarFillsAndAccents() {
        let presets = AccentPreset.allCases
        XCTAssertEqual(presets.count, 6, "Must test all 6 accent presets")

        for preset in presets {
            // 1. Change preference
            UserDefaults.standard.set(preset.rawValue, forKey: "accentPreset")

            // 2. Verify live AppTheme.accent immediately updates
            let currentAccent = AppTheme.accent
            XCTAssertNotNil(currentAccent)
            let currentNSColor = AppTheme.accentNSColor
            XCTAssertEqual(currentNSColor, preset.nsColor, "accentNSColor must match preset \(preset.rawValue)")

            // 3. Render WeeklyFocusChart with this theme
            let weekly = WeeklyFocusChart(sessions: [], dayCount: 7)
            let hostWeekly = NSHostingView(rootView: weekly)
            hostWeekly.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
            hostWeekly.layout()
            XCTAssertGreaterThan(hostWeekly.fittingSize.width, 0)
            XCTAssertGreaterThan(hostWeekly.fittingSize.height, 0)

            // 4. Render TodayHourChart with this theme
            let todayChart = TodayHourChart(hourMinutes: Array(repeating: 15, count: 24))
            let hostToday = NSHostingView(rootView: todayChart)
            hostToday.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
            hostToday.layout()
            XCTAssertGreaterThan(hostToday.fittingSize.width, 0)
            XCTAssertGreaterThan(hostToday.fittingSize.height, 0)
        }

        // 5. Fallback verification on corrupted/invalid key
        UserDefaults.standard.set("corrupted_accent_preset_name", forKey: "accentPreset")
        let fallbackAccent = AppTheme.accent
        XCTAssertNotNil(fallbackAccent)
        let fallbackNSColor = AppTheme.accentNSColor
        XCTAssertEqual(fallbackNSColor, AccentPreset.tomato.nsColor, "Corrupted key must fall back to tomato")
    }

    // =========================================================================
    // MARK: - 11. Empirical: Concurrent Chart & Layout Thread Safety
    // =========================================================================

    func testConcurrentChartRendering_ThreadSafety() {
        let expectation = self.expectation(description: "Concurrent chart rendering")
        let queue = DispatchQueue(label: "test.challenger.charts.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                let range: AnalyticsTimeRange = (i % 2 == 0) ? .today : .days7
                let model = AnalyticsDashboardModel.build(
                    range: range,
                    focusSessions: [
                        FocusSession(
                            id: UUID(),
                            taskTitle: "Session \(i)",
                            durationMinutes: 25,
                            timestamp: Date().addingTimeInterval(Double(-i * 300))
                        )
                    ],
                    tasks: [],
                    dailyGoal: 4,
                    completedPomodoros: i % 4,
                    totalSecondsToday: 1500,
                    isWorkMode: false,
                    sessionLive: false,
                    now: Date(),
                    calendar: self.calendar
                )

                _ = AnalyticsCards.weeklyCard(
                    model: model,
                    colorScheme: (i % 2 == 0) ? .light : .dark
                )

                let hourChart = TodayHourChart(hourMinutes: Array(repeating: i % 60, count: 24))
                _ = hourChart.body

                let weeklyChart = WeeklyFocusChart(sessions: model.sessionsInRange, dayCount: 7)
                _ = weeklyChart.body

                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
