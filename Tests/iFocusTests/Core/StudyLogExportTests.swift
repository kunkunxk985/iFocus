import XCTest
@testable import iFocusCore

final class StudyLogExportTests: XCTestCase {

    private let calendar = StudyLogExport.weekCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    func testWeekStartsOnMonday() {
        // 2026-10-25 is a Sunday; its week starts Monday 2026-10-19.
        let start = StudyLogExport.weekStart(for: date(2026, 10, 25, 21), calendar: calendar)
        XCTAssertEqual(start, date(2026, 10, 19, 0))
        XCTAssertEqual(StudyLogExport.weekStart(for: date(2026, 10, 19, 8), calendar: calendar), start)
    }

    func testCSVEstimatesStartAndQuotesSpecialCharacters() {
        let entries = [
            StudyLogExport.Entry(endedAt: date(2026, 10, 19, 9, 30), minutes: 25, taskTitle: "3b1b 线代, 第1集", category: "学习"),
            StudyLogExport.Entry(endedAt: date(2026, 10, 19, 8, 0), minutes: 5, taskTitle: "说\"你好\"", category: nil),
        ]
        let lines = StudyLogExport.csv(entries: entries, calendar: calendar)
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, [
            "日期,开始,结束,分钟,分类,任务",
            "2026-10-19,07:55,08:00,5,未分类,\"说\"\"你好\"\"\"",
            "2026-10-19,09:05,09:30,25,学习,\"3b1b 线代, 第1集\"",
        ])
    }

    func testWeeklyMarkdownTotalsOnlyThatWeek() {
        let entries = [
            StudyLogExport.Entry(endedAt: date(2026, 10, 19, 10), minutes: 25, taskTitle: "线性代数", category: "学习"),
            StudyLogExport.Entry(endedAt: date(2026, 10, 19, 15), minutes: 30, taskTitle: "线性代数", category: "学习"),
            StudyLogExport.Entry(endedAt: date(2026, 10, 21, 20), minutes: 20, taskTitle: "组会|材料", category: "工作"),
            // Previous Sunday: belongs to last week's report.
            StudyLogExport.Entry(endedAt: date(2026, 10, 18, 22), minutes: 50, taskTitle: "热身", category: "学习"),
        ]
        let md = StudyLogExport.weeklyMarkdown(entries: entries, weekStart: date(2026, 10, 19, 0), calendar: calendar)

        XCTAssertTrue(md.hasPrefix("# 专注周报 2026-10-19 至 2026-10-25\n"))
        XCTAssertTrue(md.contains("- 总专注：1小时15分，共 3 次"))
        XCTAssertTrue(md.contains("- 学习分类：55分钟"))
        XCTAssertTrue(md.contains("- 有专注的天数：2 / 7"))
        XCTAssertTrue(md.contains("| 2026-10-19 | 周一 | 55分钟 | 55分钟 | 2 |"))
        XCTAssertTrue(md.contains("| 2026-10-20 | 周二 | — | — | 0 |"))
        XCTAssertTrue(md.contains("| 2026-10-25 | 周日 | — | — | 0 |"))
        XCTAssertTrue(md.contains("| 线性代数 | 学习 | 55分钟 | 2 |"))
        XCTAssertTrue(md.contains("| 组会\\|材料 | 工作 | 20分钟 | 1 |"))
        XCTAssertFalse(md.contains("热身"))
    }

    func testEmptyWeekStillProducesReport() {
        let md = StudyLogExport.weeklyMarkdown(entries: [], weekStart: date(2026, 10, 19, 0), calendar: calendar)
        XCTAssertTrue(md.contains("- 总专注：0分钟，共 0 次"))
        XCTAssertTrue(md.contains("本周还没有专注记录。"))
    }

    func testFilesIncludeCurrentWeekAndEveryWeekWithSessions() {
        let entries = [
            StudyLogExport.Entry(endedAt: date(2026, 10, 7, 10), minutes: 25, taskTitle: "旧", category: "学习"),
        ]
        let files = StudyLogExport.files(entries: entries, now: date(2026, 10, 20, 9), calendar: calendar)
        XCTAssertEqual(Set(files.keys), ["sessions.csv", "weeks/2026-10-05.md", "weeks/2026-10-19.md"])
    }
}
