import Foundation

/// Plain-text study log (CSV + one Markdown report per week) so focus history can be
/// read outside the app, e.g. in a spreadsheet or a weekly study review.
public enum StudyLogExport {

    public struct Entry: Equatable {
        /// When the focus segment was logged (its end).
        public let endedAt: Date
        public let minutes: Int
        public let taskTitle: String
        /// Category display name such as "学习"; nil for free focus.
        public let category: String?

        public init(endedAt: Date, minutes: Int, taskTitle: String, category: String?) {
            self.endedAt = endedAt
            self.minutes = minutes
            self.taskTitle = taskTitle
            self.category = category
        }

        /// Approximate start: end minus focused minutes (pauses are not tracked).
        public var startedAt: Date {
            endedAt.addingTimeInterval(TimeInterval(-minutes * 60))
        }
    }

    public static let csvFileName = "sessions.csv"
    public static let weeksDirectoryName = "weeks"
    public static let studyCategory = "学习"
    static let uncategorized = "未分类"

    /// Monday-first calendar (study plan weeks run Monday to Sunday).
    public static func weekCalendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        cal.timeZone = timeZone
        return cal
    }

    public static func weekStart(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Relative path → file contents: the CSV plus one report per week that has
    /// sessions. The current week always gets a report, even before its first session.
    public static func files(entries: [Entry], now: Date, calendar: Calendar) -> [String: String] {
        var files = [csvFileName: csv(entries: entries, calendar: calendar)]
        var weeks = Set(entries.map { weekStart(for: $0.endedAt, calendar: calendar) })
        weeks.insert(weekStart(for: now, calendar: calendar))
        for week in weeks {
            let path = weeksDirectoryName + "/" + dayString(week, calendar: calendar) + ".md"
            files[path] = weeklyMarkdown(entries: entries, weekStart: week, calendar: calendar)
        }
        return files
    }

    // MARK: - CSV

    public static func csv(entries: [Entry], calendar: Calendar) -> String {
        var lines = ["日期,开始,结束,分钟,分类,任务"]
        for entry in entries.sorted(by: { $0.endedAt < $1.endedAt }) {
            let fields = [
                dayString(entry.endedAt, calendar: calendar),
                timeString(entry.startedAt, calendar: calendar),
                timeString(entry.endedAt, calendar: calendar),
                String(entry.minutes),
                entry.category ?? uncategorized,
                entry.taskTitle,
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func csvField(_ value: String) -> String {
        guard value.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\n\r")) != nil else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Weekly report

    public static func weeklyMarkdown(entries: [Entry], weekStart: Date, calendar: Calendar) -> String {
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        guard days.count == 7, let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return ""
        }
        let inWeek = entries
            .filter { $0.endedAt >= weekStart && $0.endedAt < weekEnd }
            .sorted { $0.endedAt < $1.endedAt }
        let activeDays = Set(inWeek.map { calendar.startOfDay(for: $0.endedAt) }).count

        var out: [String] = [
            "# 专注周报 \(dayString(weekStart, calendar: calendar)) 至 \(dayString(days[6], calendar: calendar))",
            "",
            "由 iFocus 自动生成，每记录一次专注都会更新。开始时间按「结束时间减专注分钟」估算。",
            "",
            "- 总专注：\(FocusStats.formatTotalMinutes(totalMinutes(inWeek)))，共 \(inWeek.count) 次",
            "- 学习分类：\(FocusStats.formatTotalMinutes(studyMinutes(inWeek)))",
            "- 有专注的天数：\(activeDays) / 7",
            "",
            "## 每天",
            "",
            "| 日期 | 星期 | 总专注 | 学习 | 次数 |",
            "|---|---|---|---|---|",
        ]
        for day in days {
            let dayEntries = inWeek.filter { calendar.isDate($0.endedAt, inSameDayAs: day) }
            let row = [
                dayString(day, calendar: calendar),
                weekdayName(day, calendar: calendar),
                durationCell(totalMinutes(dayEntries)),
                durationCell(studyMinutes(dayEntries)),
                String(dayEntries.count),
            ]
            out.append("| " + row.joined(separator: " | ") + " |")
        }

        out += ["", "## 按任务", ""]
        if inWeek.isEmpty {
            out.append("本周还没有专注记录。")
        } else {
            out += ["| 任务 | 分类 | 时长 | 次数 |", "|---|---|---|---|"]
            for group in taskGroups(inWeek) {
                let row = [
                    markdownCell(group.title),
                    group.category ?? uncategorized,
                    FocusStats.formatTotalMinutes(group.minutes),
                    String(group.count),
                ]
                out.append("| " + row.joined(separator: " | ") + " |")
            }

            out += ["", "## 明细", "", "| 日期 | 时间 | 分钟 | 分类 | 任务 |", "|---|---|---|---|---|"]
            for entry in inWeek {
                let row = [
                    dayString(entry.endedAt, calendar: calendar),
                    timeString(entry.startedAt, calendar: calendar) + "–" + timeString(entry.endedAt, calendar: calendar),
                    String(entry.minutes),
                    entry.category ?? uncategorized,
                    markdownCell(entry.taskTitle),
                ]
                out.append("| " + row.joined(separator: " | ") + " |")
            }
        }
        return out.joined(separator: "\n") + "\n"
    }

    private struct TaskGroup {
        let title: String
        let category: String?
        var minutes: Int
        var count: Int
    }

    /// Per-task totals, biggest first.
    private static func taskGroups(_ entries: [Entry]) -> [TaskGroup] {
        var groups: [TaskGroup] = []
        for entry in entries {
            if let index = groups.firstIndex(where: { $0.title == entry.taskTitle && $0.category == entry.category }) {
                groups[index].minutes += entry.minutes
                groups[index].count += 1
            } else {
                groups.append(TaskGroup(title: entry.taskTitle, category: entry.category, minutes: entry.minutes, count: 1))
            }
        }
        return groups.sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.title < $1.title }
    }

    private static func totalMinutes(_ entries: [Entry]) -> Int {
        entries.reduce(0) { $0 + max(0, $1.minutes) }
    }

    private static func studyMinutes(_ entries: [Entry]) -> Int {
        totalMinutes(entries.filter { $0.category == studyCategory })
    }

    private static func durationCell(_ minutes: Int) -> String {
        minutes > 0 ? FocusStats.formatTotalMinutes(minutes) : "—"
    }

    /// Keeps user text from breaking table rows.
    static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
    }

    // MARK: - Date text (calendar components, so output never depends on locale)

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func timeString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        // `.weekday` is 1 for Sunday regardless of `firstWeekday`.
        return names[(calendar.component(.weekday, from: date) + 6) % 7]
    }
}
