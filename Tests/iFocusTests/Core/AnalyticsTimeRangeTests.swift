import XCTest
import iFocusCore

final class AnalyticsTimeRangeTests: XCTestCase {
    func testTodayBoundsSingleDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 15))!
        let bounds = AnalyticsTimeRange.today.dayBounds(relativeTo: now, calendar: cal)
        XCTAssertEqual(bounds.from, bounds.through)
        XCTAssertEqual(cal.component(.day, from: bounds.from), 12)
    }

    func testDays7SpansInclusiveWeek() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 10))!
        let bounds = AnalyticsTimeRange.days7.dayBounds(relativeTo: now, calendar: cal)
        let days = cal.dateComponents([.day], from: bounds.from, to: bounds.through).day ?? -1
        XCTAssertEqual(days, 6)
    }

    func testReportPlainTextIncludesTotals() {
        let report = AnalyticsReport.buildPlainText(
            username: "测试",
            rangeLabel: "近7天",
            from: Date(timeIntervalSince1970: 1_720_000_000),
            through: Date(timeIntervalSince1970: 1_720_600_000),
            rangePomodoros: 5,
            rangeMinutes: 125,
            todayPomodoros: 2,
            todayMinutes: 50,
            streakCurrent: 3,
            freeFocusShare: 0.2,
            categoryLines: [("工作", 80)],
            dayOverDayLabel: "比昨天多"
        )
        XCTAssertTrue(report.body.contains("5 个"))
        XCTAssertTrue(report.body.contains("工作"))
        XCTAssertTrue(report.subject.contains("iFocus"))
    }
}
