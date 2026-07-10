import XCTest
@testable import iFocusCore

final class FocusStatsTests: XCTestCase {
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = hour
        return calendar.date(from: c)!
    }
    
    func testFormatTotalMinutes() {
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(25), "25分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(60), "1小时")
        XCTAssertEqual(FocusStats.formatTotalMinutes(90), "1小时30分")
        XCTAssertEqual(FocusStats.formatTotalMinutes(120), "2小时")
    }
    
    func testCompletionRate() {
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 0), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: 1), "25%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: 4), "100%")
    }
    
    func testStreaksCurrentIncludesYesterdayIfTodayEmpty() {
        let today = day(2026, 3, 10)
        let sessions = [
            day(2026, 3, 9),
            day(2026, 3, 8),
            day(2026, 3, 7),
        ]
        let result = FocusStats.streaks(
            sessionTimestamps: sessions,
            relativeTo: today,
            calendar: calendar
        )
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }
    
    func testStreaksBrokenDoesNotCountCurrent() {
        let today = day(2026, 3, 10)
        let sessions = [
            day(2026, 3, 7),
            day(2026, 3, 6),
        ]
        let result = FocusStats.streaks(
            sessionTimestamps: sessions,
            relativeTo: today,
            calendar: calendar
        )
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 2)
    }
    
    func testStreaksLongestAcrossGap() {
        let today = day(2026, 3, 10)
        let sessions = [
            day(2026, 3, 10),
            day(2026, 3, 9),
            // gap
            day(2026, 3, 5),
            day(2026, 3, 4),
            day(2026, 3, 3),
            day(2026, 3, 2),
        ]
        let result = FocusStats.streaks(
            sessionTimestamps: sessions,
            relativeTo: today,
            calendar: calendar
        )
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.longest, 4)
    }
    
    func testPeakFocusHours() {
        let sessions = [
            day(2026, 3, 1, hour: 9),
            day(2026, 3, 2, hour: 9),
            day(2026, 3, 3, hour: 14),
        ]
        let label = FocusStats.peakFocusHoursString(
            sessionTimestamps: sessions,
            calendar: calendar
        )
        XCTAssertEqual(label, "09:00 - 10:00")
    }
    
    func testIntensityLevels() {
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 0), 0)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 10), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 30), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 80), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 120), 4)
    }
    
    func testMinutesByDayAggregates() {
        let sessions: [(Date, Int)] = [
            (day(2026, 3, 1, hour: 9), 25),
            (day(2026, 3, 1, hour: 15), 25),
            (day(2026, 3, 2, hour: 10), 50),
        ]
        let map = FocusStats.minutesByDay(sessions: sessions, calendar: calendar)
        let d1 = calendar.startOfDay(for: day(2026, 3, 1))
        let d2 = calendar.startOfDay(for: day(2026, 3, 2))
        XCTAssertEqual(map[d1], 50)
        XCTAssertEqual(map[d2], 50)
    }
    
    func testContributionGridHasExpectedShape() {
        let grid = FocusStats.contributionGrid(
            minutesByDay: [:],
            relativeTo: day(2026, 3, 10),
            calendar: calendar,
            weeks: 4
        )
        XCTAssertEqual(grid.count, 4)
        for col in grid {
            XCTAssertEqual(col.count, 7)
        }
    }
}
