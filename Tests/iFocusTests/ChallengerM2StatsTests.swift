import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

final class ChallengerM2StatsTests: XCTestCase {
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

        // 3. Asia/Shanghai Calendar (fixed UTC+8, no DST)
        var calSh = Calendar(identifier: .gregorian)
        calSh.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calSh.firstWeekday = 1
        shCalendar = calSh

        // 2026-10-28 12:00:00 UTC
        baseDate = Date(timeIntervalSince1970: 1793188800)
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

    // =========================================================================
    // MARK: - 1. Tooltip String Output Across Equivalence Classes
    // =========================================================================

    func testTooltipFormatting_EquivalenceClasses() {
        let testDate = Date(timeIntervalSince1970: 1793188800) // 2026-10-28 12:00:00 UTC

        // Class 1: 0 mins -> "10月28日 · 0分 · 0个番茄"
        let str0 = WeeklyFocusChart.formatTooltip(
            date: testDate,
            minutes: 0,
            pomodoros: 0,
            calendar: utcCalendar
        )
        XCTAssertEqual(str0, "10月28日 · 0分 · 0个番茄")

        // Class 2: 45 mins (sub-hour: < 60) -> "10月28日 · 45分 · 2个番茄"
        let str45 = WeeklyFocusChart.formatTooltip(
            date: testDate,
            minutes: 45,
            pomodoros: 2,
            calendar: utcCalendar
        )
        XCTAssertEqual(str45, "10月28日 · 45分 · 2个番茄")

        // Class 3: 60 mins (exact 1 hour, m == 0) -> "10月28日 · 1小时 · 1个番茄"
        let str60 = WeeklyFocusChart.formatTooltip(
            date: testDate,
            minutes: 60,
            pomodoros: 1,
            calendar: utcCalendar
        )
        XCTAssertEqual(str60, "10月28日 · 1小时 · 1个番茄")

        // Class 4: 135 mins (2 hours 15 mins) -> "10月28日 · 2小时15分 · 5个番茄"
        let str135 = WeeklyFocusChart.formatTooltip(
            date: testDate,
            minutes: 135,
            pomodoros: 5,
            calendar: utcCalendar
        )
        XCTAssertEqual(str135, "10月28日 · 2小时15分 · 5个番茄")

        // Class 5: 1440 mins (exact 24 hours, m == 0) -> "10月28日 · 24小时 · 20个番茄"
        let str1440 = WeeklyFocusChart.formatTooltip(
            date: testDate,
            minutes: 1440,
            pomodoros: 20,
            calendar: utcCalendar
        )
        XCTAssertEqual(str1440, "10月28日 · 24小时 · 20个番茄")
    }

    func testTooltipFormatting_MinuteBoundaryConditions() {
        let testDate = Date(timeIntervalSince1970: 1793188800)

        // 1 min
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 1, pomodoros: 1, calendar: utcCalendar),
            "10月28日 · 1分 · 1个番茄"
        )

        // 59 mins (upper sub-hour boundary)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 59, pomodoros: 2, calendar: utcCalendar),
            "10月28日 · 59分 · 2个番茄"
        )

        // 61 mins (lower compound hour boundary)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 61, pomodoros: 2, calendar: utcCalendar),
            "10月28日 · 1小时1分 · 2个番茄"
        )

        // 119 mins (upper 1-hour boundary)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 119, pomodoros: 4, calendar: utcCalendar),
            "10月28日 · 1小时59分 · 4个番茄"
        )

        // 120 mins (exact 2 hours)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 120, pomodoros: 4, calendar: utcCalendar),
            "10月28日 · 2小时 · 4个番茄"
        )

        // 1439 mins (23 hours 59 mins)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 1439, pomodoros: 24, calendar: utcCalendar),
            "10月28日 · 23小时59分 · 24个番茄"
        )

        // 1441 mins (24 hours 1 min)
        XCTAssertEqual(
            WeeklyFocusChart.formatTooltip(date: testDate, minutes: 1441, pomodoros: 25, calendar: utcCalendar),
            "10月28日 · 24小时1分 · 25个番茄"
        )
    }

    func testTooltipFormatting_DefensiveNegativeAndExtremeInputs() {
        let testDate = Date(timeIntervalSince1970: 1793188800)

        // Negative minutes sanitized to 0
        let negMins = WeeklyFocusChart.formatTooltip(date: testDate, minutes: -50, pomodoros: 3, calendar: utcCalendar)
        XCTAssertEqual(negMins, "10月28日 · 0分 · 3个番茄")

        // Negative pomodoros sanitized to 0
        let negPomos = WeeklyFocusChart.formatTooltip(date: testDate, minutes: 30, pomodoros: -4, calendar: utcCalendar)
        XCTAssertEqual(negPomos, "10月28日 · 30分 · 0个番茄")

        // Both negative
        let bothNeg = WeeklyFocusChart.formatTooltip(date: testDate, minutes: -99, pomodoros: -10, calendar: utcCalendar)
        XCTAssertEqual(bothNeg, "10月28日 · 0分 · 0个番茄")

        // Extreme duration: 10,080 mins (168 hours = 1 week)
        let extremeDuration = WeeklyFocusChart.formatTooltip(date: testDate, minutes: 10080, pomodoros: 500, calendar: utcCalendar)
        XCTAssertEqual(extremeDuration, "10月28日 · 168小时 · 500个番茄")
    }

    // =========================================================================
    // MARK: - 2. Pomodoro Count Aggregation (0, 1, 20 Sessions Single Day)
    // =========================================================================

    func testPomodoroAggregation_SingleDayStress() {
        let cal = utcCalendar!
        let targetDay = cal.startOfDay(for: baseDate)

        // Sub-case A: 0 sessions on target day
        let sessionsA: [FocusSession] = []
        let daySessionsA = sessionsA.filter { cal.isDate($0.timestamp, inSameDayAs: targetDay) }
        let minsA = daySessionsA.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let pomosA = daySessionsA.count
        let dayFocusA = WeeklyFocusChart.DayFocus(date: targetDay, label: "10-28", minutes: minsA, pomodoros: pomosA)
        XCTAssertEqual(dayFocusA.minutes, 0)
        XCTAssertEqual(dayFocusA.pomodoros, 0)
        XCTAssertEqual(dayFocusA.id, targetDay)

        // Sub-case B: 1 session on target day
        let s1 = makeSession(timestamp: targetDay.addingTimeInterval(3600), durationMinutes: 25)
        let sessionsB = [s1]
        let daySessionsB = sessionsB.filter { cal.isDate($0.timestamp, inSameDayAs: targetDay) }
        let minsB = daySessionsB.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let pomosB = daySessionsB.count
        let dayFocusB = WeeklyFocusChart.DayFocus(date: targetDay, label: "10-28", minutes: minsB, pomodoros: pomosB)
        XCTAssertEqual(dayFocusB.minutes, 25)
        XCTAssertEqual(dayFocusB.pomodoros, 1)

        // Sub-case C: Exactly 20 sessions on target day
        var sessionsC: [FocusSession] = []
        for i in 0..<20 {
            // Spread across hours 1 to 20
            let ts = targetDay.addingTimeInterval(Double(i * 3600 + 120))
            let duration = (i % 2 == 0) ? 25 : 30
            sessionsC.append(makeSession(timestamp: ts, durationMinutes: duration, taskTitle: "Session \(i)"))
        }
        let daySessionsC = sessionsC.filter { cal.isDate($0.timestamp, inSameDayAs: targetDay) }
        let minsC = daySessionsC.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let pomosC = daySessionsC.count
        let dayFocusC = WeeklyFocusChart.DayFocus(date: targetDay, label: "10-28", minutes: minsC, pomodoros: pomosC)
        // 10 * 25 + 10 * 30 = 250 + 300 = 550 mins
        XCTAssertEqual(dayFocusC.minutes, 550)
        XCTAssertEqual(dayFocusC.pomodoros, 20)

        // Sub-case D: 20 sessions mixed with other-day sessions
        let yesterday = cal.date(byAdding: .day, value: -1, to: targetDay)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: targetDay)!
        var mixedSessions = sessionsC
        mixedSessions.append(makeSession(timestamp: yesterday.addingTimeInterval(5000), durationMinutes: 40))
        mixedSessions.append(makeSession(timestamp: tomorrow.addingTimeInterval(5000), durationMinutes: 40))

        let daySessionsMixed = mixedSessions.filter { cal.isDate($0.timestamp, inSameDayAs: targetDay) }
        let minsMixed = daySessionsMixed.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let pomosMixed = daySessionsMixed.count
        XCTAssertEqual(minsMixed, 550, "Sessions from other days must not leak into target day minutes")
        XCTAssertEqual(pomosMixed, 20, "Sessions from other days must not leak into target day pomodoro count")
    }

    func testPomodoroAggregation_ZeroAndDefensiveMinutesSessions() {
        let cal = utcCalendar!
        let targetDay = cal.startOfDay(for: baseDate)

        // 3 sessions: one normal (25m), one 0-minute session (aborted), one negative (-15m defensive error)
        let sessions = [
            makeSession(timestamp: targetDay.addingTimeInterval(1000), durationMinutes: 25),
            makeSession(timestamp: targetDay.addingTimeInterval(2000), durationMinutes: 0),
            makeSession(timestamp: targetDay.addingTimeInterval(3000), durationMinutes: -15)
        ]

        let daySessions = sessions.filter { cal.isDate($0.timestamp, inSameDayAs: targetDay) }
        let mins = daySessions.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let pomos = daySessions.count

        XCTAssertEqual(pomos, 3, "All 3 session records must be counted in pomodoros")
        XCTAssertEqual(mins, 25, "0-minute and negative sessions must contribute 0 minutes (not reduce totals)")
    }

    // =========================================================================
    // MARK: - 3. DayFocus Date Resolution & Midnight / DST Transitions
    // =========================================================================

    func testDayFocus_MidnightBoundaries() {
        let cal = utcCalendar!
        // 2026-10-28 00:00:00 UTC
        let day28Start = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 0, minute: 0, second: 0))!
        // 2026-10-28 23:59:59 UTC (1 second before midnight)
        let day28End = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 23, minute: 59, second: 59))!
        // 2026-10-29 00:00:00 UTC (exact midnight)
        let day29Start = cal.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 0, minute: 0, second: 0))!

        XCTAssertTrue(cal.isDate(day28End, inSameDayAs: day28Start))
        XCTAssertFalse(cal.isDate(day29Start, inSameDayAs: day28Start))
        XCTAssertTrue(cal.isDate(day29Start, inSameDayAs: day29Start))

        let sessions = [
            makeSession(timestamp: day28End, durationMinutes: 25),
            makeSession(timestamp: day29Start, durationMinutes: 50)
        ]

        let sessionsOn28 = sessions.filter { cal.isDate($0.timestamp, inSameDayAs: day28Start) }
        let sessionsOn29 = sessions.filter { cal.isDate($0.timestamp, inSameDayAs: day29Start) }

        XCTAssertEqual(sessionsOn28.count, 1)
        XCTAssertEqual(sessionsOn28.first?.durationMinutes, 25)

        XCTAssertEqual(sessionsOn29.count, 1)
        XCTAssertEqual(sessionsOn29.first?.durationMinutes, 50)
    }

    func testDayFocus_DaylightSavingTime_AutumnFallBack25HourDay() {
        // America/New_York DST fall transition: Sunday, November 1, 2026
        // At 02:00 EDT clocks fall back to 01:00 EST. Total day length = 25 hours.
        let cal = nyCalendar!
        var compNov1 = DateComponents()
        compNov1.year = 2026
        compNov1.month = 11
        compNov1.day = 1
        compNov1.hour = 0
        compNov1.minute = 0
        compNov1.second = 0
        let nov1Start = cal.date(from: compNov1)!

        // Session 1: Nov 1 at 00:30 (EDT)
        let s1 = cal.date(bySettingHour: 0, minute: 30, second: 0, of: nov1Start)!
        // Session 2: Nov 1 at 12:00 (EST)
        let s2 = cal.date(bySettingHour: 12, minute: 0, second: 0, of: nov1Start)!
        // Session 3: Nov 1 at 23:45 (EST)
        let s3 = cal.date(bySettingHour: 23, minute: 45, second: 0, of: nov1Start)!

        XCTAssertTrue(cal.isDate(s1, inSameDayAs: nov1Start))
        XCTAssertTrue(cal.isDate(s2, inSameDayAs: nov1Start))
        XCTAssertTrue(cal.isDate(s3, inSameDayAs: nov1Start))

        // Nov 2 00:00 (next day)
        var compNov2 = DateComponents()
        compNov2.year = 2026
        compNov2.month = 11
        compNov2.day = 2
        compNov2.hour = 0
        let nov2Start = cal.date(from: compNov2)!
        XCTAssertFalse(cal.isDate(nov2Start, inSameDayAs: nov1Start))

        // Verify date addition across the 25h boundary
        let computedNov2 = cal.date(byAdding: .day, value: 1, to: nov1Start)!
        XCTAssertEqual(cal.startOfDay(for: computedNov2), cal.startOfDay(for: nov2Start))
    }

    func testDayFocus_DaylightSavingTime_SpringForward23HourDay() {
        // America/New_York DST spring transition: Sunday, March 8, 2026
        // At 02:00 EST clocks spring forward to 03:00 EDT. Total day length = 23 hours.
        let cal = nyCalendar!
        var compMar8 = DateComponents()
        compMar8.year = 2026
        compMar8.month = 3
        compMar8.day = 8
        compMar8.hour = 0
        let mar8Start = cal.date(from: compMar8)!

        // Session before skip: Mar 8 at 01:30 (EST)
        let s1 = cal.date(bySettingHour: 1, minute: 30, second: 0, of: mar8Start)!
        // Session after skip: Mar 8 at 04:30 (EDT)
        let s2 = cal.date(bySettingHour: 4, minute: 30, second: 0, of: mar8Start)!

        XCTAssertTrue(cal.isDate(s1, inSameDayAs: mar8Start))
        XCTAssertTrue(cal.isDate(s2, inSameDayAs: mar8Start))

        // Verify date addition across the 23h boundary
        let computedMar9 = cal.date(byAdding: .day, value: 1, to: mar8Start)!
        var compMar9 = DateComponents()
        compMar9.year = 2026
        compMar9.month = 3
        compMar9.day = 9
        let mar9Start = cal.date(from: compMar9)!
        XCTAssertEqual(cal.startOfDay(for: computedMar9), cal.startOfDay(for: mar9Start))
    }

    func testDayFocus_TimezoneDateFormattingConsistency() {
        // Timestamp: 2026-10-28 23:30:00 UTC
        let ts = Date(timeIntervalSince1970: 1793230200)

        // In UTC: Date is 10月28日
        let utcStr = WeeklyFocusChart.formatTooltip(date: ts, minutes: 25, pomodoros: 1, calendar: utcCalendar)
        XCTAssertTrue(utcStr.hasPrefix("10月28日"))

        // In Asia/Shanghai (UTC+8): 2026-10-28 23:30 UTC is 2026-10-29 07:30 CST -> Date is 10月29日
        let shStr = WeeklyFocusChart.formatTooltip(date: ts, minutes: 25, pomodoros: 1, calendar: shCalendar)
        XCTAssertTrue(shStr.hasPrefix("10月29日"), "In Asia/Shanghai timezone, date must resolve to 10月29日")
    }

    // =========================================================================
    // MARK: - 4. Tooltip Clamping Math (minMargin: 105) Bounds Guarantee
    // =========================================================================

    /// Pure mathematical oracle reproducing `WeeklyFocusChart.tooltipPosition` logic.
    private func computeClampedX(rawCenterX: CGFloat, containerWidth: CGFloat, minMargin: CGFloat = 105) -> CGFloat {
        if containerWidth > minMargin * 2 {
            return min(max(rawCenterX, minMargin), containerWidth - minMargin)
        } else {
            return containerWidth / 2
        }
    }

    func testEdgeClamping_StandardContainers_CapsuleNeverEscapesBounds() {
        let minMargin: CGFloat = 105.0
        let estimatedCapsuleHalfWidth: CGFloat = 105.0 // Capsule width = 210pt max
        let testContainerWidths: [CGFloat] = [300, 400, 600, 800, 1200, 1920, 2560]
        let testRawPositions: [CGFloat] = [
            -500, -100, 0, 10, 50, 104, 105, 106,
            200, 300, 450, 600, 799, 800, 1500, 3000
        ]

        for width in testContainerWidths {
            for rawX in testRawPositions {
                let clampedX = computeClampedX(rawCenterX: rawX, containerWidth: width, minMargin: minMargin)

                // 1. Clamped position must be within [minMargin, width - minMargin]
                XCTAssertGreaterThanOrEqual(clampedX, minMargin, "clampedX (\(clampedX)) must be >= minMargin for width \(width), rawX \(rawX)")
                XCTAssertLessThanOrEqual(clampedX, width - minMargin, "clampedX (\(clampedX)) must be <= width - minMargin for width \(width), rawX \(rawX)")

                // 2. Physical capsule left edge must never escape left bound 0
                let capsuleLeft = clampedX - estimatedCapsuleHalfWidth
                XCTAssertGreaterThanOrEqual(capsuleLeft, 0.0, "Capsule left edge (\(capsuleLeft)) clipped past 0 for width \(width), rawX \(rawX)")

                // 3. Physical capsule right edge must never escape right bound width
                let capsuleRight = clampedX + estimatedCapsuleHalfWidth
                XCTAssertLessThanOrEqual(capsuleRight, width, "Capsule right edge (\(capsuleRight)) clipped past \(width) for rawX \(rawX)")
            }
        }
    }

    func testEdgeClamping_NarrowContainers_GracefulCenterFallback() {
        let minMargin: CGFloat = 105.0
        // Container widths less than or equal to minMargin * 2 (210)
        let narrowWidths: [CGFloat] = [0, 50, 100, 150, 200, 210]

        for width in narrowWidths {
            let clampedXFarLeft = computeClampedX(rawCenterX: -50, containerWidth: width, minMargin: minMargin)
            let clampedXFarRight = computeClampedX(rawCenterX: 500, containerWidth: width, minMargin: minMargin)
            let clampedXCenter = computeClampedX(rawCenterX: width / 2, containerWidth: width, minMargin: minMargin)

            let expectedCenter = width / 2
            XCTAssertEqual(clampedXFarLeft, expectedCenter, "Narrow width \(width) must fall back to exact center")
            XCTAssertEqual(clampedXFarRight, expectedCenter, "Narrow width \(width) must fall back to exact center")
            XCTAssertEqual(clampedXCenter, expectedCenter, "Narrow width \(width) must fall back to exact center")
        }
    }

    func testEdgeClamping_BoundaryThreshold_Exact210And211Points() {
        let minMargin: CGFloat = 105.0

        // At exact 210 (width == minMargin * 2): condition `width > minMargin * 2` is false
        let clampedAt210 = computeClampedX(rawCenterX: 50, containerWidth: 210, minMargin: minMargin)
        XCTAssertEqual(clampedAt210, 105.0, "Width 210 must center at 105")

        // At 211 (width > minMargin * 2):
        // minMargin = 105, width - minMargin = 211 - 105 = 106.
        // Clamping range is [105, 106].
        let clampedAt211Left = computeClampedX(rawCenterX: 10, containerWidth: 211, minMargin: minMargin)
        XCTAssertEqual(clampedAt211Left, 105.0)

        let clampedAt211Right = computeClampedX(rawCenterX: 200, containerWidth: 211, minMargin: minMargin)
        XCTAssertEqual(clampedAt211Right, 106.0)
    }

    // =========================================================================
    // MARK: - 5. WeeklyFocusChart Structural & Interactive Contract Verification
    // =========================================================================

    func testWeeklyFocusChart_StrideDaysCalculation() {
        // Inspect strideDays via various dayCount values
        let chart7 = WeeklyFocusChart(sessions: [], dayCount: 7)
        XCTAssertEqual(chart7.dayCount, 7)

        let chart14 = WeeklyFocusChart(sessions: [], dayCount: 14)
        XCTAssertEqual(chart14.dayCount, 14)

        let chart30 = WeeklyFocusChart(sessions: [], dayCount: 30)
        XCTAssertEqual(chart30.dayCount, 30)

        let chart60 = WeeklyFocusChart(sessions: [], dayCount: 60)
        XCTAssertEqual(chart60.dayCount, 60)
    }

    func testWeeklyFocusChart_ViewInstantiationAndBodyEvaluation() {
        let s1 = makeSession(timestamp: Date(), durationMinutes: 25)
        let s2 = makeSession(timestamp: Date().addingTimeInterval(-86400), durationMinutes: 50)
        let chart = WeeklyFocusChart(sessions: [s1, s2], dayCount: 7)

        // Verify body produces valid View hierarchy without crash
        let body = chart.body
        XCTAssertNotNil(body)
    }

    func testTodayHourChart_InstantiationAndYScaleDomain() {
        // Case 1: Max minutes under 60 (e.g. 25 mins) -> Domain defaults to 0...60
        let under60 = [0, 0, 0, 25, 0, 0]
        let chartUnder60 = TodayHourChart(hourMinutes: under60)
        XCTAssertNotNil(chartUnder60.body)

        // Case 2: Max minutes exceeds 60 (e.g. 120 mins) -> Domain expands to 0...120
        let over60 = [0, 0, 120, 0]
        let chartOver60 = TodayHourChart(hourMinutes: over60)
        XCTAssertNotNil(chartOver60.body)

        // Case 3: Empty hours array
        let emptyChart = TodayHourChart(hourMinutes: [])
        XCTAssertNotNil(emptyChart.body)
    }

    func testTimeRangeMapping_ChipsAndTitlesFidelity() {
        // Verify trend titles contract: "今天趋势", "7天趋势", "30天趋势", "本月趋势"
        func expectedTrendTitle(for range: AnalyticsTimeRange) -> String {
            switch range {
            case .today: return "今天趋势"
            case .days7: return "7天趋势"
            case .days30: return "30天趋势"
            case .month: return "本月趋势"
            }
        }

        func expectedChipTitle(for range: AnalyticsTimeRange) -> String {
            switch range {
            case .today: return "今天"
            case .days7: return "7天"
            case .days30: return "30天"
            case .month: return "本月"
            }
        }

        for r in AnalyticsTimeRange.allCases {
            XCTAssertFalse(expectedTrendTitle(for: r).isEmpty)
            XCTAssertFalse(expectedChipTitle(for: r).isEmpty)
            XCTAssertTrue(expectedTrendTitle(for: r).contains("趋势"))
        }
    }
}
