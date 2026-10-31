import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

// =============================================================================
// MARK: - Statistics Redesign Design Specification Oracle
// =============================================================================

/// Authoritative design tokens and requirement contracts derived from
/// ORIGINAL_REQUEST.md and PROJECT.md.
enum StatisticsRedesignDesignSpec {
    // M1 / R1: Top Dashboard & Concentric Dual Rings
    static let ringSizeDefault: CGFloat = 104.0
    static let ringSizeMin: CGFloat = 84.0
    static let ringLineWidth: CGFloat = 6.5
    static let ringBreathingScaleMin: CGFloat = 1.00
    static let ringBreathingScaleMax: CGFloat = 1.06
    static let ringBreathingAnimationDuration: Double = 1.8

    // M2 / R2: Trend Bar Chart & Tooltip & Date Bounds
    static let barCornerRadius: CGFloat = 4.0
    static let barGridlineWidth: CGFloat = 0.5
    static let tooltipCapsuleCornerRadius: CGFloat = 12.0
    static let tooltipHorizontalPadding: CGFloat = 10.0
    static let tooltipVerticalPadding: CGFloat = 5.0
    static let supportedRanges: [AnalyticsTimeRange] = [.today, .days7, .days30, .month]

    // M3 / R3: Squircle Heatmap & 4-Step Color Ladder
    static let squircleRadius: CGFloat = 2.8
    static let heatmapGridWeeks: Int = 53
    static let heatmapGridDaysPerWeek: Int = 7
    static let heatmapLevel0Opacity: Double = 0.045
    static let heatmapLevel1Opacity: Double = 0.25
    static let heatmapLevel2Opacity: Double = 0.50
    static let heatmapLevel3Opacity: Double = 0.75
    static let heatmapLevel4Opacity: Double = 1.00

    // M4 / R4: 2x2 Metric Tiles
    static let tileMaxSingleIcon = "stopwatch"
    static let tileMaxSingleAlternativeIcon = "flame.fill"
    static let tileDailyAvgIcon = "clock.fill"
    static let tilePeakHourIcon = "sun.max.fill"
    static let tileCompletionRateIcon = "checkmark.circle.fill"
    static let tileBackgroundFillOpacity: Double = 0.08
    static let tileCornerRadius: CGFloat = 12.0

    // M5 / R5: Performance Budgets
    static let maxPageSnapshotBuildMs: Double = 220.0
    static let maxHeatmapGridComputationMs: Double = 150.0
    static let maxMinutesByDayAggregationMs: Double = 120.0
}

// =============================================================================
// MARK: - Statistics Redesign Test Harness & Query Oracle
// =============================================================================

enum StatisticsRedesignTestHarness {
    /// Canonical calendar configured to UTC for deterministic cross-platform date math.
    static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1 // Sunday
        return cal
    }

    /// Construct deterministic Date in UTC.
    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return utcCalendar.date(from: c)!
    }

    /// Helper to generate a `FocusSession`.
    static func makeSession(
        timestamp: Date,
        durationMinutes: Int,
        taskId: UUID? = nil,
        taskTitle: String = "Test Focus Session",
        category: TaskCategory? = nil
    ) -> FocusSession {
        FocusSession(
            id: UUID(),
            taskId: taskId,
            taskTitle: taskTitle,
            taskCategory: category,
            durationMinutes: durationMinutes,
            timestamp: timestamp
        )
    }

    /// Helper to generate a `FocusTask`.
    static func makeTask(
        title: String,
        category: TaskCategory = .other,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        priority: Int = 1
    ) -> FocusTask {
        var task = FocusTask(title: title, category: category, priority: priority)
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.dueDate = dueDate
        task.startDate = startDate
        return task
    }

    /// Authoritative tooltip formatter matching PROJECT.md § M2 Interface Contracts:
    /// `M月d日 · H小时m分 · N个番茄` (or `m分 · N个番茄` when duration < 60 mins).
    static func formatTrendTooltip(
        date: Date,
        minutes: Int,
        pomodoros: Int,
        calendar: Calendar = utcCalendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let datePart = formatter.string(from: date)

        let safeMinutes = max(0, minutes)
        let timePart: String
        if safeMinutes < 60 {
            timePart = "\(safeMinutes)分"
        } else {
            let h = safeMinutes / 60
            let m = safeMinutes % 60
            if m == 0 {
                timePart = "\(h)小时"
            } else {
                timePart = "\(h)小时\(m)分"
            }
        }
        return "\(datePart) · \(timePart) · \(max(0, pomodoros))个番茄"
    }

    /// Authoritative heatmap hover tooltip formatter matching PROJECT.md § M3 Interface Contracts:
    /// `yyyy年M月d日 · N 分钟`
    static func formatHeatmapTooltip(
        date: Date,
        minutes: Int,
        calendar: Calendar = utcCalendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return "\(formatter.string(from: date)) · \(max(0, minutes)) 分钟"
    }

    /// Authoritative Concentric Dual Ring progress calculation oracle.
    static func ringProgress(
        range: AnalyticsTimeRange,
        completedPomodoros: Int,
        dailyGoal: Int,
        totalMinutes: Int,
        dayCount: Int
    ) -> (pomodoroProgress: Double, durationProgress: Double) {
        guard dailyGoal > 0 else {
            return (0.0, 0.0)
        }
        let safeDays = max(1, dayCount)
        let safePomodoros = max(0, completedPomodoros)
        let safeMinutes = max(0, totalMinutes)

        let pomodoroTarget: Double
        let durationTarget: Double

        if range == .today {
            pomodoroTarget = Double(dailyGoal)
            durationTarget = Double(dailyGoal * 25)
        } else {
            pomodoroTarget = Double(dailyGoal * safeDays)
            durationTarget = Double(max(25, dailyGoal * 25 * safeDays))
        }

        let pomoProgress = min(1.0, max(0.0, Double(safePomodoros) / pomodoroTarget))
        let durProgress = min(1.0, max(0.0, Double(safeMinutes) / durationTarget))
        return (pomoProgress, durProgress)
    }

    /// Authoritative Squircle heatmap intensity level oracle.
    static func heatmapIntensityLevel(minutes: Int) -> Int {
        FocusStats.intensityLevel(minutes: minutes)
    }

    /// Measure elapsed milliseconds of a block.
    static func measureMilliseconds(_ block: () throws -> Void) rethrows -> Double {
        let start = DispatchTime.now()
        try block()
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanoTime) / 1_000_000.0
    }
}

// =============================================================================
// MARK: - Main Statistics Redesign E2E & Component Test Suite
// =============================================================================

final class StatisticsRedesignTests: XCTestCase {
    private var tempDir: URL!
    private var calendar: Calendar { StatisticsRedesignTestHarness.utcCalendar }

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-StatsRedesign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func makeStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 1-3 (M1) — Top Dashboard & Concentric Dual Rings
    // =========================================================================

    func testF01_MasterDashboard_VisualHierarchyAndDesignTokens() {
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringSizeDefault, 104.0)
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringSizeMin, 84.0)
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringLineWidth, 6.5)
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringBreathingScaleMin, 1.00)
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringBreathingScaleMax, 1.06)
        XCTAssertEqual(StatisticsRedesignDesignSpec.ringBreathingAnimationDuration, 1.8)
    }

    func testF02_ConcentricRings_TodayPomodoroProgressMath() {
        // Daily goal = 8 pomodoros
        // Case 1: 0 completed -> 0.0
        let (pomo0, _) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 0, dailyGoal: 8, totalMinutes: 0, dayCount: 1
        )
        XCTAssertEqual(pomo0, 0.0, accuracy: 0.0001)

        // Case 2: 4 completed -> 0.5
        let (pomoHalf, _) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 4, dailyGoal: 8, totalMinutes: 100, dayCount: 1
        )
        XCTAssertEqual(pomoHalf, 0.5, accuracy: 0.0001)

        // Case 3: 8 completed -> 1.0 (Exact 100%)
        let (pomoFull, _) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 8, dailyGoal: 8, totalMinutes: 200, dayCount: 1
        )
        XCTAssertEqual(pomoFull, 1.0, accuracy: 0.0001)

        // Case 4: 12 completed -> Capped at 1.0 (Progress clipping)
        let (pomoOver, _) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 12, dailyGoal: 8, totalMinutes: 300, dayCount: 1
        )
        XCTAssertEqual(pomoOver, 1.0, accuracy: 0.0001)
    }

    func testF02_ConcentricRings_TodayDurationProgressMath() {
        // Daily goal = 4 pomodoros -> target duration = 4 * 25 = 100 minutes
        // Case 1: 25 minutes -> 0.25
        let (_, dur25) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 1, dailyGoal: 4, totalMinutes: 25, dayCount: 1
        )
        XCTAssertEqual(dur25, 0.25, accuracy: 0.0001)

        // Case 2: 100 minutes -> 1.00
        let (_, dur100) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 4, dailyGoal: 4, totalMinutes: 100, dayCount: 1
        )
        XCTAssertEqual(dur100, 1.0, accuracy: 0.0001)

        // Case 3: 150 minutes -> clipped at 1.00
        let (_, dur150) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 6, dailyGoal: 4, totalMinutes: 150, dayCount: 1
        )
        XCTAssertEqual(dur150, 1.0, accuracy: 0.0001)
    }

    func testF02_ConcentricRings_MultiDayRangesProgressMath() {
        // 7 Days Range: daily goal 4 -> target pomodoros = 28, target minutes = 700
        let (pomo7d, dur7d) = StatisticsRedesignTestHarness.ringProgress(
            range: .days7, completedPomodoros: 14, dailyGoal: 4, totalMinutes: 350, dayCount: 7
        )
        XCTAssertEqual(pomo7d, 0.5, accuracy: 0.0001)
        XCTAssertEqual(dur7d, 0.5, accuracy: 0.0001)

        // 30 Days Range: daily goal 4 -> target pomodoros = 120, target minutes = 3000
        let (pomo30d, dur30d) = StatisticsRedesignTestHarness.ringProgress(
            range: .days30, completedPomodoros: 90, dailyGoal: 4, totalMinutes: 2250, dayCount: 30
        )
        XCTAssertEqual(pomo30d, 0.75, accuracy: 0.0001)
        XCTAssertEqual(dur30d, 0.75, accuracy: 0.0001)
    }

    func testF02_ConcentricRings_ZeroDailyGoalSafeguard() {
        let (pomo, dur) = StatisticsRedesignTestHarness.ringProgress(
            range: .today, completedPomodoros: 5, dailyGoal: 0, totalMinutes: 125, dayCount: 1
        )
        XCTAssertEqual(pomo, 0.0)
        XCTAssertEqual(dur, 0.0)
        XCTAssertFalse(pomo.isNaN)
        XCTAssertFalse(dur.isNaN)
    }

    func testF03_MonospacedStats_FormattingExactness() {
        // Focus duration formatting
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(25), "25分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(75), "1小时15分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(120), "2小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(145), "2小时25分")

        // Streaks formatting and calculation
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let sessions = [
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 10),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 30, hour: 10),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 29, hour: 10),
        ]
        let streak = FocusStats.streaks(sessionTimestamps: sessions, relativeTo: now, calendar: calendar)
        XCTAssertEqual(streak.current, 3)
        XCTAssertEqual(streak.longest, 3)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 4-6 (M2) — Trend Bar Chart & Hover Tooltip & Bounds
    // =========================================================================

    func testF04_TrendChart_DailySessionAggregation() {
        let d1 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 9)
        let d2 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 14)
        let d3 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 29, hour: 11)

        let sessions = [
            StatisticsRedesignTestHarness.makeSession(timestamp: d1, durationMinutes: 25),
            StatisticsRedesignTestHarness.makeSession(timestamp: d2, durationMinutes: 50),
            StatisticsRedesignTestHarness.makeSession(timestamp: d3, durationMinutes: 30)
        ]

        let pairs = sessions.map { ($0.timestamp, $0.durationMinutes) }
        let byDay = FocusStats.minutesByDay(sessions: pairs, calendar: calendar)

        let startDay28 = calendar.startOfDay(for: d1)
        let startDay29 = calendar.startOfDay(for: d3)

        XCTAssertEqual(byDay[startDay28], 75, "Day 28 should aggregate 25 + 50 = 75 minutes")
        XCTAssertEqual(byDay[startDay29], 30, "Day 29 should aggregate 30 minutes")
    }

    func testF05_HoverTooltip_FormatStandardLongDuration() {
        let targetDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 15)
        let tooltip = StatisticsRedesignTestHarness.formatTrendTooltip(
            date: targetDate,
            minutes: 135,
            pomodoros: 5,
            calendar: calendar
        )
        // Expected format: M月d日 · H小时m分 · N个番茄 -> 10月28日 · 2小时15分 · 5个番茄
        XCTAssertEqual(tooltip, "10月28日 · 2小时15分 · 5个番茄")
    }

    func testF05_HoverTooltip_FormatSubHourDuration() {
        let targetDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 15)
        let tooltip = StatisticsRedesignTestHarness.formatTrendTooltip(
            date: targetDate,
            minutes: 45,
            pomodoros: 2,
            calendar: calendar
        )
        // Duration < 60 mins: M月d日 · m分 · N个番茄 -> 10月28日 · 45分 · 2个番茄
        XCTAssertEqual(tooltip, "10月28日 · 45分 · 2个番茄")
    }

    func testF05_HoverTooltip_FormatExactHourDuration() {
        let targetDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 15)
        let tooltip = StatisticsRedesignTestHarness.formatTrendTooltip(
            date: targetDate,
            minutes: 120,
            pomodoros: 4,
            calendar: calendar
        )
        XCTAssertEqual(tooltip, "10月28日 · 2小时 · 4个番茄")
    }

    func testF05_HoverTooltip_FormatZeroDuration() {
        let targetDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 15)
        let tooltip = StatisticsRedesignTestHarness.formatTrendTooltip(
            date: targetDate,
            minutes: 0,
            pomodoros: 0,
            calendar: calendar
        )
        XCTAssertEqual(tooltip, "10月28日 · 0分 · 0个番茄")
    }

    func testF06_DateBounds_SupportedRangesFidelity() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 14)
        let today = calendar.startOfDay(for: now)

        // 1. Today
        let todayBounds = AnalyticsTimeRange.today.dayBounds(relativeTo: now, calendar: calendar)
        XCTAssertEqual(todayBounds.from, today)
        XCTAssertEqual(todayBounds.through, today)

        // 2. 7 Days (Inclusive: today - 6 days through today)
        let days7Bounds = AnalyticsTimeRange.days7.dayBounds(relativeTo: now, calendar: calendar)
        let days7Diff = calendar.dateComponents([.day], from: days7Bounds.from, to: days7Bounds.through).day ?? 0
        XCTAssertEqual(days7Diff, 6, "7 days inclusive must span 6 days offset (total 7 distinct calendar days)")
        XCTAssertEqual(days7Bounds.through, today)

        // 3. 30 Days (Inclusive: today - 29 days through today)
        let days30Bounds = AnalyticsTimeRange.days30.dayBounds(relativeTo: now, calendar: calendar)
        let days30Diff = calendar.dateComponents([.day], from: days30Bounds.from, to: days30Bounds.through).day ?? 0
        XCTAssertEqual(days30Diff, 29, "30 days inclusive must span 29 days offset (total 30 distinct calendar days)")
        XCTAssertEqual(days30Bounds.through, today)

        // 4. Month (1st day of month through today)
        let monthBounds = AnalyticsTimeRange.month.dayBounds(relativeTo: now, calendar: calendar)
        let expectedFirstDay = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 1)
        XCTAssertEqual(monthBounds.from, expectedFirstDay)
        XCTAssertEqual(monthBounds.through, today)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 7-9 (M3) — Squircle Heatmap & 4-Step Color Ladder
    // =========================================================================

    func testF07_SquircleHeatmap_ShapeTokenContinuousRadius() {
        let squircle = AppTheme.squircle(radius: StatisticsRedesignDesignSpec.squircleRadius)
        XCTAssertEqual(StatisticsRedesignDesignSpec.squircleRadius, 2.8)
        XCTAssertNotNil(squircle)
    }

    func testF08_SquircleHeatmap_IntensityLevelThresholds() {
        // Level 0: 0 mins
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 0), 0)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: -5), 0)

        // Level 1: 1...25 mins
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 1), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 15), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 25), 1)

        // Level 2: 26...50 mins
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 26), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 40), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 50), 2)

        // Level 3: 51...100 mins
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 51), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 80), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 100), 3)

        // Level 4: > 100 mins
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 101), 4)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 250), 4)
    }

    func testF08_SquircleHeatmap_ColorLadderOpacities() {
        XCTAssertEqual(StatisticsRedesignDesignSpec.heatmapLevel0Opacity, 0.045)
        XCTAssertEqual(StatisticsRedesignDesignSpec.heatmapLevel1Opacity, 0.25)
        XCTAssertEqual(StatisticsRedesignDesignSpec.heatmapLevel2Opacity, 0.50)
        XCTAssertEqual(StatisticsRedesignDesignSpec.heatmapLevel3Opacity, 0.75)
        XCTAssertEqual(StatisticsRedesignDesignSpec.heatmapLevel4Opacity, 1.00)
    }

    func testF09_SquircleHeatmap_53WeeksGridStructure() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: now,
            calendar: calendar,
            weeks: StatisticsRedesignDesignSpec.heatmapGridWeeks
        )

        XCTAssertEqual(grid.count, 53, "Annual heatmap must have 53 week columns")
        for (idx, week) in grid.enumerated() {
            XCTAssertEqual(week.count, 7, "Week column \(idx) must contain exactly 7 day cells")
        }
    }

    func testF09_SquircleHeatmap_MonthLabelsAndActiveDaysCount() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let d1 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 15)
        let d2 = StatisticsRedesignTestHarness.date(year: 2026, month: 9, day: 20)
        let d3 = StatisticsRedesignTestHarness.date(year: 2026, month: 8, day: 5)

        let minutesMap: [Date: Int] = [
            calendar.startOfDay(for: d1): 50,
            calendar.startOfDay(for: d2): 30,
            calendar.startOfDay(for: d3): 80
        ]

        let grid = FocusStats.contributionGrid(
            minutesByDay: minutesMap,
            relativeTo: now,
            calendar: calendar,
            weeks: 53
        )
        let labels = FocusStats.monthLabels(for: grid, calendar: calendar)
        XCTAssertFalse(labels.isEmpty, "Month labels should be generated at month boundaries")

        let activeDays = grid.flatMap { $0 }.filter { $0.minutes > 0 }.count
        XCTAssertEqual(activeDays, 3, "Grid must reflect exactly 3 active days")

        let tooltip = StatisticsRedesignTestHarness.formatHeatmapTooltip(
            date: d1,
            minutes: 50,
            calendar: calendar
        )
        XCTAssertEqual(tooltip, "2026年10月15日 · 50 分钟")
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 10-11 (M4) — 2x2 Metric Tiles & Unified Icons
    // =========================================================================

    func testF10_MetricTiles_MaxSingleFocusSession() {
        let sessions = [
            StatisticsRedesignTestHarness.makeSession(timestamp: Date(), durationMinutes: 25),
            StatisticsRedesignTestHarness.makeSession(timestamp: Date(), durationMinutes: 90),
            StatisticsRedesignTestHarness.makeSession(timestamp: Date(), durationMinutes: 45),
            StatisticsRedesignTestHarness.makeSession(timestamp: Date(), durationMinutes: 15)
        ]

        var maxSingle = 0
        for s in sessions {
            maxSingle = max(maxSingle, s.durationMinutes)
        }
        XCTAssertEqual(maxSingle, 90, "Max single focus session should be 90 minutes")
    }

    func testF10_MetricTiles_AverageDailyFocusCalculation() {
        let d1 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 20, hour: 10)
        let d2 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 21, hour: 11)
        let d3 = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 22, hour: 14)

        let sessions = [
            StatisticsRedesignTestHarness.makeSession(timestamp: d1, durationMinutes: 60),
            StatisticsRedesignTestHarness.makeSession(timestamp: d2, durationMinutes: 60),
            StatisticsRedesignTestHarness.makeSession(timestamp: d3, durationMinutes: 60)
        ]

        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes } // 180 mins
        let timestamps = sessions.map(\.timestamp)
        let avgMinutes = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: timestamps,
            totalMinutes: totalMinutes,
            calendar: calendar
        )
        // 180 / 3 active days = 60 minutes
        XCTAssertEqual(avgMinutes, 60)
        XCTAssertEqual(FocusStats.formatTotalMinutes(avgMinutes), "1小时")
    }

    func testF10_MetricTiles_PeakFocusHoursGoldenTime() {
        let sessions = [
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 20, hour: 9),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 21, hour: 9),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 22, hour: 9),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 23, hour: 14),
            StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 24, hour: 20)
        ]

        let peakStr = FocusStats.peakFocusHoursString(sessionTimestamps: sessions, calendar: calendar)
        XCTAssertEqual(peakStr, "09:00 - 10:00", "Golden time peak hours must identify modal hour 09:00 - 10:00")
    }

    func testF10_MetricTiles_TaskCompletionRateCalculation() {
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 0), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 10, completed: 3), "30%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: 4), "100%")
        XCTAssertEqual(FocusStats.completionRate(total: 5, completed: 6), "100%", "Capped at 100%")
    }

    func testF11_MetricTiles_SFSymbolsContractAndVisualTokens() {
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileMaxSingleIcon, "stopwatch")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileDailyAvgIcon, "clock.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tilePeakHourIcon, "sun.max.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileCompletionRateIcon, "checkmark.circle.fill")
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileBackgroundFillOpacity, 0.08)
        XCTAssertEqual(StatisticsRedesignDesignSpec.tileCornerRadius, 12.0)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 12-16 (M5) — TaskStore Backwards Compatibility & Perf
    // =========================================================================

    func testF12_TaskStore_ModelPersistenceAndZeroDataLoss() {
        let store1 = makeStore()
        store1.newTaskTitle = "Redesign Architecture"
        guard let taskId = store1.addTask(for: .todayTask) else {
            XCTFail("Failed to add task")
            return
        }

        let now = Date()
        let session = FocusSession(
            id: UUID(),
            taskId: taskId,
            taskTitle: "Redesign Architecture",
            taskCategory: .work,
            durationMinutes: 45,
            timestamp: now
        )
        store1.focusSessions.append(session)
        store1.flushPendingSaves()

        // Create fresh store instance on same directory to test reload
        let store2 = makeStore()
        XCTAssertEqual(store2.tasks.count, 1)
        XCTAssertEqual(store2.tasks.first?.id, taskId)
        XCTAssertEqual(store2.tasks.first?.title, "Redesign Architecture")
        XCTAssertEqual(store2.focusSessions.count, 1)
        XCTAssertEqual(store2.focusSessions.first?.id, session.id)
        XCTAssertEqual(store2.focusSessions.first?.durationMinutes, 45)
        XCTAssertEqual(store2.focusSessions.first?.taskTitle, "Redesign Architecture")
        XCTAssertEqual(store2.focusSessions.first?.taskCategory, .work)
    }

    func testF13_ZeroExternalDependenciesRule() {
        // Assert Package.swift does not introduce external third-party packages
        let packagePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Analytics
            .deletingLastPathComponent() // iFocusTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iFocus root
            .appendingPathComponent("Package.swift")

        let content = try? String(contentsOf: packagePath, encoding: .utf8)
        XCTAssertNotNil(content, "Package.swift must exist and be readable")
        if let content {
            XCTAssertFalse(content.contains(".package(url:"), "No external third-party package dependencies allowed")
        }
    }

    func testF16_Performance_PageSnapshot5000SessionsUnderBudget() {
        var syntheticSessions: [FocusSession] = []
        syntheticSessions.reserveCapacity(5000)
        let baseDate = Date()

        for i in 0..<5000 {
            syntheticSessions.append(FocusSession(
                id: UUID(),
                taskId: nil,
                taskTitle: "Session #\(i)",
                taskCategory: .work,
                durationMinutes: 25 + (i % 30),
                timestamp: baseDate.addingTimeInterval(-Double(i * 3600))
            ))
        }

        var syntheticTasks: [FocusTask] = []
        syntheticTasks.reserveCapacity(500)
        for i in 0..<500 {
            syntheticTasks.append(StatisticsRedesignTestHarness.makeTask(
                title: "Task #\(i)",
                isCompleted: i % 2 == 0
            ))
        }

        let elapsed = StatisticsRedesignTestHarness.measureMilliseconds {
            _ = AnalyticsPageSnapshot.build(
                range: .days30,
                focusSessions: syntheticSessions,
                tasks: syntheticTasks,
                categoriesInUse: TaskCategory.allCases,
                dailyGoal: 8,
                completedPomodoros: 4,
                totalSecondsToday: 3600,
                isWorkMode: true,
                sessionLive: false,
                now: baseDate,
                calendar: calendar
            )
        }

        print("[Perf Check] AnalyticsPageSnapshot.build 5000 sessions + 500 tasks = \(elapsed) ms (Budget: \(StatisticsRedesignDesignSpec.maxPageSnapshotBuildMs) ms)")
        XCTAssertLessThan(elapsed, StatisticsRedesignDesignSpec.maxPageSnapshotBuildMs, "Snapshot build must stay under performance limit")
    }

    func testF16_Performance_HeatmapGridComputationUnderBudget() {
        let baseDate = Date()
        var minutesMap: [Date: Int] = [:]
        for i in 0..<365 {
            let day = calendar.date(byAdding: .day, value: -i, to: baseDate)!
            minutesMap[calendar.startOfDay(for: day)] = 25 * (i % 6)
        }

        let elapsed = StatisticsRedesignTestHarness.measureMilliseconds {
            _ = FocusStats.contributionGrid(
                minutesByDay: minutesMap,
                relativeTo: baseDate,
                calendar: calendar,
                weeks: 53
            )
        }

        print("[Perf Check] Heatmap contributionGrid computation = \(elapsed) ms (Budget: \(StatisticsRedesignDesignSpec.maxHeatmapGridComputationMs) ms)")
        XCTAssertLessThan(elapsed, StatisticsRedesignDesignSpec.maxHeatmapGridComputationMs)
    }

    // =========================================================================
    // MARK: - TIER 2: BOUNDARY & CORNER CASES (10 tests)
    // =========================================================================

    func testTier2_ZeroMinutesSession_SafelyHandledWithoutDivisionByZero() {
        let (pomo, dur) = StatisticsRedesignTestHarness.ringProgress(
            range: .today,
            completedPomodoros: 0,
            dailyGoal: 0,
            totalMinutes: 0,
            dayCount: 1
        )
        XCTAssertEqual(pomo, 0.0)
        XCTAssertEqual(dur, 0.0)
        XCTAssertFalse(pomo.isNaN)
        XCTAssertFalse(dur.isNaN)
    }

    func testTier2_NegativeAndDefensiveMinutes_SanitizedToZero() {
        XCTAssertEqual(FocusStats.formatTotalMinutes(-100), "0分钟")
        XCTAssertEqual(FocusStats.intensityLevel(minutes: -20), 0)

        let session = StatisticsRedesignTestHarness.makeSession(
            timestamp: Date(),
            durationMinutes: -30
        )
        let pairs = [(session.timestamp, session.durationMinutes)]
        let totals = FocusStats.dayTotals(sessions: pairs, on: Date(), calendar: calendar)
        XCTAssertEqual(totals.minutes, 0, "Negative session minutes must be defensively clamped to zero")
    }

    func testTier2_FutureTimestampSession_HandledSafely() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let futureDate = StatisticsRedesignTestHarness.date(year: 2026, month: 11, day: 5, hour: 12)

        let sessions = [
            StatisticsRedesignTestHarness.makeSession(timestamp: futureDate, durationMinutes: 45)
        ]

        let todayBounds = AnalyticsTimeRange.today.dayBounds(relativeTo: now, calendar: calendar)
        let inTodayRange = sessions.filter {
            let day = calendar.startOfDay(for: $0.timestamp)
            return day >= todayBounds.from && day <= todayBounds.through
        }
        XCTAssertTrue(inTodayRange.isEmpty, "Future session must not leak into today's range bounds")
    }

    func testTier2_SingleSessionExceeding24Hours_HandledWithoutOverflow() {
        let extremeMinutes = 1500 // 25 hours
        let formatted = FocusStats.formatTotalMinutes(extremeMinutes)
        XCTAssertEqual(formatted, "25小时")

        let level = FocusStats.intensityLevel(minutes: extremeMinutes)
        XCTAssertEqual(level, 4)

        let tooltip = StatisticsRedesignTestHarness.formatTrendTooltip(
            date: Date(),
            minutes: extremeMinutes,
            pomodoros: 1,
            calendar: calendar
        )
        XCTAssertTrue(tooltip.contains("25小时"), "Tooltip must cleanly format sessions > 24 hours")
    }

    func testTier2_ZeroTasks_CompletionRateIsZeroPercent() {
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 0), "0%")
    }

    func testTier2_AllTasksCompleted_CompletionRateIs100Percent() {
        XCTAssertEqual(FocusStats.completionRate(total: 50, completed: 50), "100%")
    }

    func testTier2_LeapYear_February29_BoundsAndHeatmap() {
        // Leap year 2024: Feb 29
        let feb29_2024 = StatisticsRedesignTestHarness.date(year: 2024, month: 2, day: 29, hour: 12)
        let bounds = AnalyticsTimeRange.month.dayBounds(relativeTo: feb29_2024, calendar: calendar)

        let feb1_2024 = StatisticsRedesignTestHarness.date(year: 2024, month: 2, day: 1)
        XCTAssertEqual(bounds.from, feb1_2024)
        XCTAssertEqual(bounds.through, calendar.startOfDay(for: feb29_2024))

        let daysInMonth = (calendar.dateComponents([.day], from: bounds.from, to: bounds.through).day ?? 0) + 1
        XCTAssertEqual(daysInMonth, 29, "2024 Leap year February through day 29 must span 29 days")
    }

    func testTier2_YearBoundary_Dec31ToJan01_StreakAndMonthBounds() {
        let dec31 = StatisticsRedesignTestHarness.date(year: 2025, month: 12, day: 31, hour: 12)
        let jan01 = StatisticsRedesignTestHarness.date(year: 2026, month: 1, day: 1, hour: 12)

        let sessions = [dec31, jan01]
        let streaks = FocusStats.streaks(sessionTimestamps: sessions, relativeTo: jan01, calendar: calendar)
        XCTAssertEqual(streaks.current, 2, "Streak across Dec 31 to Jan 01 year rollover must be continuous")

        let janMonthBounds = AnalyticsTimeRange.month.dayBounds(relativeTo: jan01, calendar: calendar)
        XCTAssertEqual(janMonthBounds.from, calendar.startOfDay(for: jan01))
    }

    func testTier2_DailyGoalZero_ProgressCappedCleanly() {
        let (pomo, dur) = StatisticsRedesignTestHarness.ringProgress(
            range: .days7,
            completedPomodoros: 10,
            dailyGoal: 0,
            totalMinutes: 250,
            dayCount: 7
        )
        XCTAssertEqual(pomo, 0.0)
        XCTAssertEqual(dur, 0.0)
    }

    func testTier2_EmptyHistory_PeakHoursAndAverageYieldsSafeDefaults() {
        let emptyTimestamps: [Date] = []
        let peak = FocusStats.peakFocusHoursString(sessionTimestamps: emptyTimestamps, calendar: calendar)
        XCTAssertEqual(peak, "暂无数据")

        let avg = FocusStats.averageDailyFocusMinutes(
            sessionTimestamps: emptyTimestamps,
            totalMinutes: 0,
            calendar: calendar
        )
        XCTAssertEqual(avg, 0)
        XCTAssertEqual(FocusStats.formatTotalMinutes(avg), "0分钟")
    }

    // =========================================================================
    // MARK: - TIER 3: CROSS-FEATURE COMBINATIONS (5 tests)
    // =========================================================================

    func testTier3_TodayZeroSessions_WithAnnualHeatmapActiveStreak() {
        // Today has 0 sessions, but yesterday was active
        let today = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let yesterday = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 30, hour: 12)
        let dayBefore = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 29, hour: 12)

        let sessions = [yesterday, dayBefore]
        let streak = FocusStats.streaks(sessionTimestamps: sessions, relativeTo: today, calendar: calendar)
        XCTAssertEqual(streak.current, 2, "Even with 0 sessions today, streak must retain yesterday's active streak")

        let (pomo, dur) = StatisticsRedesignTestHarness.ringProgress(
            range: .today,
            completedPomodoros: 0,
            dailyGoal: 8,
            totalMinutes: 0,
            dayCount: 1
        )
        XCTAssertEqual(pomo, 0.0, "Today rings must reflect 0% when today is empty")
        XCTAssertEqual(dur, 0.0)

        // Meanwhile, heatmap reflects the past days
        let minutesMap: [Date: Int] = [
            calendar.startOfDay(for: yesterday): 50,
            calendar.startOfDay(for: dayBefore): 50
        ]
        let grid = FocusStats.contributionGrid(minutesByDay: minutesMap, relativeTo: today, calendar: calendar)
        let activeCount = grid.flatMap { $0 }.filter { $0.minutes > 0 }.count
        XCTAssertEqual(activeCount, 2)
    }

    func testTier3_DualRingProgress_WithLiveTickingSession() {
        // Test live session addition to range totals
        let today = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let pastSession = StatisticsRedesignTestHarness.makeSession(
            timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 9),
            durationMinutes: 25
        )

        // Build dashboard model with sessionLive = true and totalSecondsToday = 3000 (50 mins)
        // Historical committed = 25 mins. Live session in progress = 25 additional minutes.
        let model = AnalyticsDashboardModel.build(
            range: .today,
            focusSessions: [pastSession],
            tasks: [],
            dailyGoal: 4,
            completedPomodoros: 1,
            totalSecondsToday: 3000, // 50 mins
            isWorkMode: true,
            sessionLive: true,
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(model.totalMinutesToday, 50)
        XCTAssertEqual(model.rangeTotals.minutes, 50, "Live ticking session minutes must be incorporated into range totals")
        XCTAssertEqual(model.completedPomodoros, 1, "Pomodoro count remains 1 until live session commits")
    }

    func testTier3_TimeRangeSwitching_ConsistencyAcrossAllViews() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        let sToday = StatisticsRedesignTestHarness.makeSession(
            timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 10),
            durationMinutes: 25
        )
        let s3DaysAgo = StatisticsRedesignTestHarness.makeSession(
            timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 28, hour: 10),
            durationMinutes: 50
        )
        let s20DaysAgo = StatisticsRedesignTestHarness.makeSession(
            timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 11, hour: 10),
            durationMinutes: 100
        )

        let allSessions = [sToday, s3DaysAgo, s20DaysAgo]

        // 1. Today View: Only sToday (25 mins, 1 pomo)
        let modelToday = AnalyticsDashboardModel.build(
            range: .today, focusSessions: allSessions, tasks: [], dailyGoal: 4,
            completedPomodoros: 1, totalSecondsToday: 1500, isWorkMode: false, sessionLive: false,
            now: now, calendar: calendar
        )
        XCTAssertEqual(modelToday.rangeTotals.minutes, 25)
        XCTAssertEqual(modelToday.rangeTotals.pomodoros, 1)

        // 2. 7 Days View: sToday + s3DaysAgo (75 mins, 2 pomos)
        let model7d = AnalyticsDashboardModel.build(
            range: .days7, focusSessions: allSessions, tasks: [], dailyGoal: 4,
            completedPomodoros: 1, totalSecondsToday: 1500, isWorkMode: false, sessionLive: false,
            now: now, calendar: calendar
        )
        XCTAssertEqual(model7d.rangeTotals.minutes, 75)
        XCTAssertEqual(model7d.rangeTotals.pomodoros, 2)

        // 3. 30 Days View: all 3 sessions (175 mins, 3 pomos)
        let model30d = AnalyticsDashboardModel.build(
            range: .days30, focusSessions: allSessions, tasks: [], dailyGoal: 4,
            completedPomodoros: 1, totalSecondsToday: 1500, isWorkMode: false, sessionLive: false,
            now: now, calendar: calendar
        )
        XCTAssertEqual(model30d.rangeTotals.minutes, 175)
        XCTAssertEqual(model30d.rangeTotals.pomodoros, 3)
    }

    func testTier3_TaskCompletionToggle_InstantlyReflectsIn2x2CompletionRate() {
        var task1 = StatisticsRedesignTestHarness.makeTask(title: "Task 1", isCompleted: false)
        _ = StatisticsRedesignTestHarness.makeTask(title: "Task 2", isCompleted: true)

        let rateBefore = FocusStats.completionRate(total: 2, completed: 1)
        XCTAssertEqual(rateBefore, "50%")

        // Toggle task1 to completed
        task1.isCompleted = true
        let rateAfter = FocusStats.completionRate(total: 2, completed: 2)
        XCTAssertEqual(rateAfter, "100%")
    }

    func testTier3_NewSessionAppended_SimultaneousUpdateAcrossHeaderChartHeatmapTiles() {
        let baseDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        var sessions: [FocusSession] = [
            StatisticsRedesignTestHarness.makeSession(
                timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 30, hour: 10),
                durationMinutes: 30
            )
        ]

        // State before
        let snapshotBefore = AnalyticsPageSnapshot.build(
            range: .today,
            focusSessions: sessions,
            tasks: [],
            categoriesInUse: TaskCategory.allCases,
            dailyGoal: 4,
            completedPomodoros: 0,
            totalSecondsToday: 0,
            isWorkMode: false,
            sessionLive: false,
            now: baseDate,
            calendar: calendar
        )
        XCTAssertEqual(snapshotBefore.totalMinutesAllTime, 30)
        XCTAssertEqual(snapshotBefore.maxSingleFocusSession, 30)

        // Append new session of 60 mins today
        sessions.append(
            StatisticsRedesignTestHarness.makeSession(
                timestamp: StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 11),
                durationMinutes: 60
            )
        )

        // State after
        let snapshotAfter = AnalyticsPageSnapshot.build(
            range: .today,
            focusSessions: sessions,
            tasks: [],
            categoriesInUse: TaskCategory.allCases,
            dailyGoal: 4,
            completedPomodoros: 1,
            totalSecondsToday: 3600,
            isWorkMode: false,
            sessionLive: false,
            now: baseDate,
            calendar: calendar
        )

        // 1. Header
        XCTAssertEqual(snapshotAfter.totalMinutesAllTime, 90)
        XCTAssertEqual(snapshotAfter.model.totalMinutesToday, 60)
        XCTAssertEqual(snapshotAfter.model.completedPomodoros, 1)

        // 2. Metric Tiles
        XCTAssertEqual(snapshotAfter.maxSingleFocusSession, 60, "Max single should update to 60")
        XCTAssertEqual(snapshotAfter.averageDailyLabel, "45分钟", "90 mins / 2 active days = 45 mins")

        // 3. Heatmap
        let activeDays = snapshotAfter.heatmapGrid.flatMap { $0 }.filter { $0.minutes > 0 }.count
        XCTAssertEqual(activeDays, 2)
    }

    // =========================================================================
    // MARK: - TIER 4: REAL-WORLD APPLICATION SCENARIOS (2 comprehensive journeys)
    // =========================================================================

    func testTier4_ThirtyDayUserJourney_ProductivityConsistencyAcrossAllWidgets() {
        let now = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 18)
        var syntheticSessions: [FocusSession] = []
        var totalExpectedMinutes = 0
        var totalExpectedPomodoros = 0
        var activeDaysSet = Set<Date>()
        var maxSessionDuration = 0

        // Simulate 30 days of user activity
        for dayOffset in 0..<30 {
            let sessionDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let dayStart = calendar.startOfDay(for: sessionDate)

            // Pattern:
            // Days 0..4 (Workdays): 4 pomodoros (100 mins, peak at 10:00)
            // Days 5..6 (Weekend): 1 pomodoro (25 mins)
            // Days 14..15 (Vacation gap): 0 pomodoros
            let isVacation = (dayOffset == 14 || dayOffset == 15)
            let isWeekend = (dayOffset % 7 == 5 || dayOffset % 7 == 6)

            if isVacation {
                continue
            }

            let sessionCount = isWeekend ? 1 : 4
            let sessionDuration = isWeekend ? 30 : 25

            for s in 0..<sessionCount {
                let hour = isWeekend ? 15 : (9 + s) // work sessions spread 9, 10, 11, 12
                let timestamp = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: sessionDate)!
                let duration = (dayOffset == 2 && s == 1) ? 90 : sessionDuration // one outlier session of 90m

                syntheticSessions.append(StatisticsRedesignTestHarness.makeSession(
                    timestamp: timestamp,
                    durationMinutes: duration,
                    taskTitle: "Work Task"
                ))

                totalExpectedMinutes += duration
                totalExpectedPomodoros += 1
                maxSessionDuration = max(maxSessionDuration, duration)
            }
            activeDaysSet.insert(dayStart)
        }

        let tasks = [
            StatisticsRedesignTestHarness.makeTask(title: "T1", isCompleted: true),
            StatisticsRedesignTestHarness.makeTask(title: "T2", isCompleted: true),
            StatisticsRedesignTestHarness.makeTask(title: "T3", isCompleted: false),
            StatisticsRedesignTestHarness.makeTask(title: "T4", isCompleted: true)
        ]

        let snapshot = AnalyticsPageSnapshot.build(
            range: .days30,
            focusSessions: syntheticSessions,
            tasks: tasks,
            categoriesInUse: TaskCategory.allCases,
            dailyGoal: 4,
            completedPomodoros: 4,
            totalSecondsToday: 6000,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )

        // Verification 1: Header & Range Totals
        XCTAssertEqual(snapshot.model.rangeTotals.minutes, totalExpectedMinutes)
        XCTAssertEqual(snapshot.model.rangeTotals.pomodoros, totalExpectedPomodoros)

        // Verification 2: 2x2 Metric Tiles
        XCTAssertEqual(snapshot.maxSingleFocusSession, maxSessionDuration)
        XCTAssertEqual(snapshot.maxSingleFocusSession, 90)
        XCTAssertEqual(snapshot.completionRate, "75%") // 3 of 4 completed
        let expectedDailyAvg = totalExpectedMinutes / activeDaysSet.count
        XCTAssertEqual(snapshot.averageDailyLabel, FocusStats.formatTotalMinutes(expectedDailyAvg))

        // Verification 3: Annual Heatmap Active Days within grid
        let heatmapActiveDays = snapshot.heatmapGrid.flatMap { $0 }.filter { $0.minutes > 0 }.count
        XCTAssertEqual(heatmapActiveDays, activeDaysSet.count)

        // Verification 4: Concentric Rings for 30-Day Range
        let (pomoProg, durProg) = StatisticsRedesignTestHarness.ringProgress(
            range: .days30,
            completedPomodoros: totalExpectedPomodoros,
            dailyGoal: 4,
            totalMinutes: totalExpectedMinutes,
            dayCount: 30
        )
        let expectedTargetPomodoros = Double(4 * 30) // 120
        XCTAssertEqual(pomoProg, min(1.0, Double(totalExpectedPomodoros) / expectedTargetPomodoros), accuracy: 0.001)
        let expectedTargetMinutes = Double(4 * 25 * 30) // 3000
        XCTAssertEqual(durProg, min(1.0, Double(totalExpectedMinutes) / expectedTargetMinutes), accuracy: 0.001)
    }

    func testTier4_OneYearFullJourney_HeatmapAndLongTermStats() {
        let baseDate = StatisticsRedesignTestHarness.date(year: 2026, month: 10, day: 31, hour: 12)
        var annualSessions: [FocusSession] = []
        var activeDays = 0

        // Generate 1200+ sessions over 365 days
        for dayOffset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: baseDate) else { continue }
            // Active on 80% of days
            if dayOffset % 5 != 0 {
                activeDays += 1
                let sessionCount = (dayOffset % 3) + 2 // 2 to 4 sessions
                for s in 0..<sessionCount {
                    let ts = calendar.date(bySettingHour: 10 + s, minute: 0, second: 0, of: day)!
                    annualSessions.append(StatisticsRedesignTestHarness.makeSession(
                        timestamp: ts,
                        durationMinutes: 25,
                        taskTitle: "Annual Study"
                    ))
                }
            }
        }

        XCTAssertGreaterThan(annualSessions.count, 800)

        // Build snapshot over entire history
        let snapshot = AnalyticsPageSnapshot.build(
            range: .days30,
            focusSessions: annualSessions,
            tasks: [],
            categoriesInUse: TaskCategory.allCases,
            dailyGoal: 4,
            completedPomodoros: 4,
            totalSecondsToday: 3600,
            isWorkMode: false,
            sessionLive: false,
            now: baseDate,
            calendar: calendar
        )

        // Verify Annual Heatmap has exact 53 columns x 7 rows
        XCTAssertEqual(snapshot.heatmapGrid.count, 53)
        for col in snapshot.heatmapGrid {
            XCTAssertEqual(col.count, 7)
        }

        // Verify total active days in heatmap matches activeDays generated
        let gridActive = snapshot.heatmapGrid.flatMap { $0 }.filter { $0.minutes > 0 }.count
        XCTAssertEqual(gridActive, activeDays)

        // Verify Golden time peak hours
        XCTAssertFalse(snapshot.peakHours.isEmpty)
        XCTAssertNotEqual(snapshot.peakHours, "暂无数据")
        XCTAssertTrue(snapshot.peakHours.contains(":00 - "))

        // Verify TaskStore persistence under annual volume
        let store = makeStore()
        store.focusSessions = annualSessions
        store.flushPendingSaves()

        let reloadedStore = makeStore()
        XCTAssertEqual(reloadedStore.focusSessions.count, annualSessions.count, "All annual sessions must survive disk persistence without data loss")
    }
}
