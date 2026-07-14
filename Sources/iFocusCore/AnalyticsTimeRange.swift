import Foundation

/// Dashboard time range — pure, UI-agnostic.
public enum AnalyticsTimeRange: String, CaseIterable, Identifiable, Sendable {
    case today = "今日"
    case days7 = "近7天"
    case days30 = "近30天"
    case month = "本月"

    public var id: String { rawValue }

    /// Inclusive day bounds `[from, through]` at start-of-day resolution.
    public func dayBounds(
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> (from: Date, through: Date) {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today:
            return (today, today)
        case .days7:
            let from = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return (from, today)
        case .days30:
            let from = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return (from, today)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: comps) ?? today
            return (start, today)
        }
    }

    /// Chart day count for bar trends.
    public var trendDayCount: Int {
        switch self {
        case .today, .days7: return 7
        case .days30: return 30
        case .month: return 31
        }
    }
}

public enum AnalyticsReport {
    /// Plain-text summary for mailto / clipboard (no AppKit).
    public static func buildPlainText(
        username: String,
        rangeLabel: String,
        from: Date,
        through: Date,
        rangePomodoros: Int,
        rangeMinutes: Int,
        todayPomodoros: Int,
        todayMinutes: Int,
        streakCurrent: Int,
        freeFocusShare: Double,
        categoryLines: [(name: String, minutes: Int)],
        dayOverDayLabel: String,
        locale: Locale = Locale(identifier: "zh_CN")
    ) -> (subject: String, body: String) {
        let who = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = who.isEmpty ? "小番茄" : who
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = locale
        let end = formatter.string(from: through)
        let start = formatter.string(from: from)

        var lines: [String] = [
            "\(displayName) 的 iFocus 专注摘要 · \(rangeLabel)（\(start) – \(end)）",
            "",
            "· 番茄：\(rangePomodoros) 个",
            "· 专注：\(FocusStats.formatTotalMinutes(rangeMinutes))",
            "· 今日：\(todayPomodoros) 个 / \(FocusStats.formatTotalMinutes(todayMinutes))",
            "· 连续天数：\(streakCurrent) 天",
            "· 任务绑定率：\(Int(((1 - freeFocusShare) * 100).rounded()))%",
            "",
            "分类："
        ]

        if categoryLines.isEmpty {
            lines.append("· 暂无分类数据")
        } else {
            for item in categoryLines {
                lines.append("· \(item.name)：\(item.minutes) 分钟")
            }
        }

        lines.append("")
        lines.append(dayOverDayLabel)
        lines.append("")
        lines.append("-- 来自 iFocus macOS")

        return (
            subject: "iFocus 周报 \(end)",
            body: lines.joined(separator: "\n")
        )
    }
}
