import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

/// Adversarial empirical verification test suite for Milestone 4:
/// 2x2 Metric Tiles, Formatting Math, SF Symbols Contract, and Visual Tokens.
final class ChallengerM4StatsTests: XCTestCase {
    private var utcCalendar: Calendar!
    private var nyCalendar: Calendar!
    private var shCalendar: Calendar!
    private var baseDate: Date!

    override func setUpWithError() throws {
        // 1. UTC Calendar
        var calUtc = Calendar(identifier: .gregorian)
        calUtc.timeZone = TimeZone(secondsFromGMT: 0)!
        calUtc.firstWeekday = 1
        utcCalendar = calUtc

        // 2. America/New_York Calendar (with DST transitions)
        var calNy = Calendar(identifier: .gregorian)
        calNy.timeZone = TimeZone(identifier: "America/New_York")!
        calNy.firstWeekday = 1
        nyCalendar = calNy

        // 3. Asia/Shanghai Calendar (UTC+8, no DST)
        var calSh = Calendar(identifier: .gregorian)
        calSh.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calSh.firstWeekday = 1
        shCalendar = calSh

        // 2026-10-31 12:00:00 UTC
        baseDate = Date(timeIntervalSince1970: 1793448000)
    }

    private func makeSession(
        timestamp: Date,
        durationMinutes: Int,
        taskTitle: String = "Test Session"
    ) -> FocusSession {
        FocusSession(
            id: UUID(),
            taskId: nil,
            taskTitle: taskTitle,
            taskCategory: .work,
            durationMinutes: durationMinutes,
            timestamp: timestamp
        )
    }

    private func makeTask(
        title: String,
        category: TaskCategory = .work,
        isCompleted: Bool = false
    ) -> FocusTask {
        var task = FocusTask(title: title, category: category, priority: 1)
        task.isCompleted = isCompleted
        return task
    }

    // =========================================================================
    // MARK: - 1. "单次最长" Formatting Math (FocusStats.formatTotalMinutes)
    // =========================================================================

    func testMaxSingleFocusSessionFormatting_EquivalenceClasses() {
        // Class 1: Exact prompt requirements
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟", "0 mins -> '0分钟'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(45), "45分钟", "45 mins -> '45分钟'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(90), "1小时30分", "90 mins -> '1小时30分'")

        // Class 2: Defensive boundary for negative inputs
        XCTAssertEqual(FocusStats.formatTotalMinutes(-1), "0分钟", "Negative minutes clamped to '0分钟'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(-100), "0分钟", "Negative minutes clamped to '0分钟'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(Int.min + 1), "0分钟", "Extremely negative minutes clamped to '0分钟'")

        // Class 3: Minute boundaries (< 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(1), "1分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(25), "25分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(59), "59分钟")

        // Class 4: Exact hour boundaries (no trailing '0分')
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时", "Exact 60 mins should be '1小时', not '1小时0分'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(120), "2小时", "Exact 120 mins should be '2小时'")
        XCTAssertEqual(FocusStats.formatTotalMinutes(180), "3小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(1440), "24小时")

        // Class 5: Mixed hour and minutes (> 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(61), "1小时1分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(119), "1小时59分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(125), "2小时5分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(1439), "23小时59分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(1441), "24小时1分")

        // Class 6: Very large numbers
        XCTAssertEqual(FocusStats.formatTotalMinutes(10_000), "166小时40分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(100_000), "1666小时40分")
    }

    // =========================================================================
    // MARK: - 2. "日均专注" Daily Average Focus Math
    // =========================================================================

    func testAverageDailyFocusCalculation_EdgeCasesAndMath() {
        // Case 1: Empty timestamps
        let emptyAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: [],
            totalMinutes: 0,
            calendar: utcCalendar
        )
        XCTAssertEqual(emptyAvg, 0)
        XCTAssertEqual(FocusStats.formatTotalMinutes(emptyAvg), "0分钟")

        // Case 2: Empty timestamps with non-zero totalMinutes (defensive against corruption)
        let corruptEmptyAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: [],
            totalMinutes: 60,
            calendar: utcCalendar
        )
        // days clamped to max(1, 0) = 1 -> 60 / 1 = 60
        XCTAssertEqual(corruptEmptyAvg, 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(corruptEmptyAvg), "1小时")

        // Case 3: Multiple sessions on the same calendar day (day deduplication)
        let d1 = utcCalendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)!
        let d2 = utcCalendar.date(bySettingHour: 11, minute: 0, second: 0, of: baseDate)!
        let d3 = utcCalendar.date(bySettingHour: 15, minute: 0, second: 0, of: baseDate)!
        let sameDayTimestamps = [d1, d2, d3]
        let sameDayTotal = 90 // 30 + 30 + 30

        let sameDayAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: sameDayTimestamps,
            totalMinutes: sameDayTotal,
            calendar: utcCalendar
        )
        // 90 total / 1 unique active day = 90 mins
        XCTAssertEqual(sameDayAvg, 90)
        XCTAssertEqual(FocusStats.formatTotalMinutes(sameDayAvg), "1小时30分")

        // Case 4: Multiple sessions across different days
        let day1 = utcCalendar.date(byAdding: .day, value: 0, to: baseDate)!
        let day2 = utcCalendar.date(byAdding: .day, value: 1, to: baseDate)!
        let day3 = utcCalendar.date(byAdding: .day, value: 2, to: baseDate)!
        let multiDayTimestamps = [day1, day2, day3]
        let multiDayTotal = 180

        let multiDayAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: multiDayTimestamps,
            totalMinutes: multiDayTotal,
            calendar: utcCalendar
        )
        // 180 / 3 active days = 60 mins
        XCTAssertEqual(multiDayAvg, 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(multiDayAvg), "1小时")

        // Case 5: Integer division truncation
        let truncTimestamps = [day1, day2, day3]
        let truncTotal = 100 // 100 / 3 = 33
        let truncAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: truncTimestamps,
            totalMinutes: truncTotal,
            calendar: utcCalendar
        )
        XCTAssertEqual(truncAvg, 33)
        XCTAssertEqual(FocusStats.formatTotalMinutes(truncAvg), "33分钟")

        // Case 6: Non-contiguous active days (e.g. Day 0 and Day 10)
        let day10 = utcCalendar.date(byAdding: .day, value: 10, to: baseDate)!
        let sparseTimestamps = [day1, day10]
        let sparseTotal = 120
        let sparseAvg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: sparseTimestamps,
            totalMinutes: sparseTotal,
            calendar: utcCalendar
        )
        // Only active days are counted in denominator (2 days, not 11 calendar span)
        XCTAssertEqual(sparseAvg, 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(sparseAvg), "1小时")
    }

    func testAverageDailyFocus_TimezoneInvariance() {
        // Verify startOfDay grouping produces correct unique day count across different timezones
        let ts1 = Date(timeIntervalSince1970: 1793448000) // 2026-10-31 12:00:00 UTC
        let ts2 = Date(timeIntervalSince1970: 1793451600) // 2026-10-31 13:00:00 UTC (same day in all 3)
        let ts3 = Date(timeIntervalSince1970: 1793534400) // 2026-11-01 12:00:00 UTC (next day)

        let timestamps = [ts1, ts2, ts3]
        let total = 120

        let avgUtc = FocusStats.averageDailyFocusMinutes(sessionTimestamps: timestamps, totalMinutes: total, calendar: utcCalendar)
        let avgSh = FocusStats.averageDailyFocusMinutes(sessionTimestamps: timestamps, totalMinutes: total, calendar: shCalendar)

        XCTAssertEqual(avgUtc, 60, "UTC has 2 unique active days: 120 / 2 = 60")
        XCTAssertEqual(avgSh, 60, "Asia/Shanghai has 2 unique active days: 120 / 2 = 60")
    }

    // =========================================================================
    // MARK: - 3. "黄金时段" Peak Focus Hours Histogram Math
    // =========================================================================

    func testPeakFocusHours_HistogramMath() {
        // 1. Empty timestamps -> "暂无数据"
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [], calendar: utcCalendar), "暂无数据")

        // 2. Single session at hour 9 -> "09:00 - 10:00"
        let d9 = utcCalendar.date(bySettingHour: 9, minute: 30, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [d9], calendar: utcCalendar), "09:00 - 10:00")

        // 3. Single session at midnight hour 0 -> "00:00 - 01:00"
        let d0 = utcCalendar.date(bySettingHour: 0, minute: 15, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [d0], calendar: utcCalendar), "00:00 - 01:00")

        // 4. Single session at 23:00 -> "23:00 - 00:00" (wraparound)
        let d23 = utcCalendar.date(bySettingHour: 23, minute: 45, second: 0, of: baseDate)!
        XCTAssertEqual(FocusStats.peakFocusHoursString(sessionTimestamps: [d23], calendar: utcCalendar), "23:00 - 00:00")

        // 5. Clear modal peak
        var sessions: [Date] = []
        // Hour 14 has 5 sessions
        for _ in 0..<5 {
            sessions.append(utcCalendar.date(bySettingHour: 14, minute: Int.random(in: 0...59), second: 0, of: baseDate)!)
        }
        // Hour 9 has 2 sessions
        for _ in 0..<2 {
            sessions.append(utcCalendar.date(bySettingHour: 9, minute: Int.random(in: 0...59), second: 0, of: baseDate)!)
        }
        // Hour 20 has 1 session
        sessions.append(utcCalendar.date(bySettingHour: 20, minute: 10, second: 0, of: baseDate)!)

        let peak = FocusStats.peakFocusHoursString(sessionTimestamps: sessions, calendar: utcCalendar)
        XCTAssertEqual(peak, "14:00 - 15:00", "Hour 14 is the modal peak")

        // 6. Tie handling: when two hours tie (e.g. Hour 10 and Hour 16 both have 3 sessions)
        var tiedSessions: [Date] = []
        for _ in 0..<3 {
            tiedSessions.append(utcCalendar.date(bySettingHour: 10, minute: 10, second: 0, of: baseDate)!)
            tiedSessions.append(utcCalendar.date(bySettingHour: 16, minute: 10, second: 0, of: baseDate)!)
        }
        let tiedPeak = FocusStats.peakFocusHoursString(sessionTimestamps: tiedSessions, calendar: utcCalendar)
        // Must match either "10:00 - 11:00" or "16:00 - 17:00", cannot crash or produce malformed string
        XCTAssertTrue(
            tiedPeak == "10:00 - 11:00" || tiedPeak == "16:00 - 17:00",
            "Tied peak must return one of the modal hours in valid format, got: \(tiedPeak)"
        )

        // 7. Timezone effect on peak hour
        // Session at 02:00 UTC is 10:00 in Asia/Shanghai (UTC+8)
        let utc2am = utcCalendar.date(bySettingHour: 2, minute: 0, second: 0, of: baseDate)!
        let peakInSh = FocusStats.peakFocusHoursString(sessionTimestamps: [utc2am], calendar: shCalendar)
        XCTAssertEqual(peakInSh, "10:00 - 11:00", "02:00 UTC should be recognized as 10:00 in Asia/Shanghai")
    }

    // =========================================================================
    // MARK: - 4. "任务完成率" Completion Rate Calculation
    // =========================================================================

    func testTaskCompletionRate_CalculationAndClamping() {
        // Standard fractions
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 0), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: 0), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: 3), "30%")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: 5), "50%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: 4), "100%")

        // Integer division truncation
        XCTAssertEqual(FocusStats.completionRate(total: 3, completed: 1), "33%")
        XCTAssertEqual(FocusStats.completionRate(total: 3, completed: 2), "66%")
        XCTAssertEqual(FocusStats.completionRate(total: 7, completed: 1), "14%")

        // Defensive handling: completed > total (clamped at 100%)
        XCTAssertEqual(FocusStats.completionRate(total: 5, completed: 6), "100%")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: 100), "100%")

        // Defensive handling: negative inputs
        XCTAssertEqual(FocusStats.completionRate(total: -5, completed: 2), "0%", "Negative total returns '0%'")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: -3), "0%", "Negative completed clamped to '0%'")
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 5), "0%", "Zero total with positive completed returns '0%'")
    }

    // =========================================================================
    // MARK: - 5. SF Symbols Contract & Visual Tokens Audit
    // =========================================================================

    func testMetricTiles_SFSymbolsContractAndVisualTokens() {
        // Assert design spec contract matches PROJECT.md
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileMaxSingleIcon, "stopwatch")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileDailyAvgIcon, "clock.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tilePeakHourIcon, "sun.max.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileCompletionRateIcon, "checkmark.circle.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileBackgroundFillOpacity, 0.08)
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileCornerRadius, 12.0)

        // Read ProfileInsightsCard source file directly and verify AST/token invariants
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // iFocusTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iFocus root
            .appendingPathComponent("Sources/iFocus/Views/Profile/ProfileInsightsCard.swift")

        let source = try? String(contentsOf: sourcePath, encoding: .utf8)
        XCTAssertNotNil(source, "ProfileInsightsCard.swift must exist and be readable")

        if let source {
            // Verify card title is "统计洞察"
            XCTAssertTrue(source.contains("\"统计洞察\""), "Card title must be '统计洞察'")
            XCTAssertFalse(source.contains("\"简要统计\""), "Old title '简要统计' must be eliminated")

            // Verify tile titles
            XCTAssertTrue(source.contains("\"单次最长\""), "Tile 1 must be '单次最长'")
            XCTAssertTrue(source.contains("\"日均专注\""), "Tile 2 must be '日均专注'")
            XCTAssertTrue(source.contains("\"黄金时段\""), "Tile 3 must be '黄金时段'")
            XCTAssertTrue(source.contains("\"任务完成率\""), "Tile 4 must be '任务完成率'")

            // Verify SF Symbols in source
            XCTAssertTrue(source.contains("icon: \"stopwatch\""), "Must use 'stopwatch' SF symbol")
            XCTAssertTrue(source.contains("icon: \"clock.fill\""), "Must use 'clock.fill' SF symbol")
            XCTAssertTrue(source.contains("icon: \"sun.max.fill\""), "Must use 'sun.max.fill' SF symbol")
            XCTAssertTrue(source.contains("icon: \"checkmark.circle.fill\""), "Must use 'checkmark.circle.fill' SF symbol")

            // Verify elimination of rainbow colors
            let rainbowHexes = ["#F59E0B", "#3B82F6", "#8B5CF6", "#10B981"]
            for hex in rainbowHexes {
                XCTAssertFalse(
                    source.contains(hex),
                    "ProfileInsightsCard must NOT contain rainbow color \(hex)"
                )
            }

            // Verify elimination of Divider
            XCTAssertFalse(
                source.contains("Divider()"),
                "ProfileInsightsCard must NOT contain Divider lines"
            )

            // Verify monospaced digit formatting
            XCTAssertTrue(
                source.contains(".monospacedDigit()"),
                "Metric values must use .monospacedDigit() to avoid jitter"
            )

            // Verify Squircle radius 12 token for tile
            XCTAssertTrue(
                source.contains("AppTheme.squircle(radius: 12)"),
                "Metric tiles must use AppTheme.squircle(radius: 12)"
            )
        }
    }

    // =========================================================================
    // MARK: - 6. End-to-End Pipeline & Concurrency Stress Test
    // =========================================================================

    func testAnalyticsPageSnapshot_MetricTilesEndToEndPipeline() {
        let cal = Calendar.current
        var sessions: [FocusSession] = []
        let d1 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)!
        let d2 = cal.date(bySettingHour: 9, minute: 30, second: 0, of: baseDate)!
        let d3 = cal.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!

        sessions.append(makeSession(timestamp: d1, durationMinutes: 45))
        sessions.append(makeSession(timestamp: d2, durationMinutes: 90)) // max single
        sessions.append(makeSession(timestamp: d3, durationMinutes: 30))

        let tasks: [FocusTask] = [
            makeTask(title: "Task 1", isCompleted: true),
            makeTask(title: "Task 2", isCompleted: false),
            makeTask(title: "Task 3", isCompleted: true),
            makeTask(title: "Task 4", isCompleted: false)
        ] // 2 of 4 completed = 50%

        let snapshot = AnalyticsPageSnapshot.build(
            range: .today,
            focusSessions: sessions,
            tasks: tasks,
            categoriesInUse: [],
            dailyGoal: 4,
            completedPomodoros: 2,
            totalSecondsToday: 165 * 60,
            isWorkMode: false,
            sessionLive: false,
            now: baseDate,
            calendar: utcCalendar
        )

        // 1. Max single focus session
        XCTAssertEqual(snapshot.maxSingleFocusSession, 90)
        XCTAssertEqual(FocusStats.formatTotalMinutes(snapshot.maxSingleFocusSession), "1小时30分")

        // 2. Average daily focus
        // 165 mins total / 1 unique day = 165 mins -> 2小时45分
        XCTAssertEqual(snapshot.averageDailyLabel, "2小时45分")

        // 3. Peak focus hours: Hour 9 has 2 sessions, Hour 14 has 1 session
        XCTAssertEqual(snapshot.peakHours, "09:00 - 10:00")

        // 4. Task completion rate: 2 completed / 4 total = 50%
        XCTAssertEqual(snapshot.completionRate, "50%")
    }

    func testConcurrentSnapshotBuild_ThreadSafetyStress() {
        var sessions: [FocusSession] = []
        for i in 0..<100 {
            let ts = baseDate.addingTimeInterval(Double(-i * 1800))
            sessions.append(makeSession(timestamp: ts, durationMinutes: 25 + (i % 20)))
        }
        var tasks: [FocusTask] = []
        for i in 0..<50 {
            tasks.append(makeTask(title: "Task \(i)", isCompleted: (i % 2 == 0)))
        }

        let expectation = self.expectation(description: "Concurrent snapshot builds")
        expectation.expectedFulfillmentCount = 20

        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            let snapshot = AnalyticsPageSnapshot.build(
                range: .days7,
                focusSessions: sessions,
                tasks: tasks,
                categoriesInUse: [],
                dailyGoal: 4,
                completedPomodoros: 10,
                totalSecondsToday: 1800,
                isWorkMode: false,
                sessionLive: false,
                now: self.baseDate,
                calendar: self.utcCalendar
            )
            XCTAssertGreaterThan(snapshot.maxSingleFocusSession, 0)
            XCTAssertFalse(snapshot.averageDailyLabel.isEmpty)
            XCTAssertFalse(snapshot.peakHours.isEmpty)
            XCTAssertEqual(snapshot.completionRate, "50%")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
}
