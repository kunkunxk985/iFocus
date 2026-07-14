import Foundation
import SwiftUI
import iFocusCore

/// Pure-ish snapshot of analytics page metrics — keeps heavy derivation out of the View body.
struct AnalyticsDashboardModel {
    let range: AnalyticsTimeRange
    let calendar: Calendar
    let todayStart: Date
    let rangeBounds: (from: Date, through: Date)
    let sessionPairs: [(timestamp: Date, minutes: Int)]
    let sessionsInRange: [FocusSession]
    let rangeTotals: FocusStats.DayFocusTotals
    let totalMinutesToday: Int
    let yesterdayMinutes: Int
    let streakCurrent: Int
    let freeShare: Double
    let goalProgress: Double
    let goalRemaining: Int
    let completedPomodoros: Int
    let dailyGoal: Int
    let insights: [String]
    let categoryTop: [(name: String, icon: String, color: Color, minutes: Int)]
    let recentSessions: [FocusSession]
    let hasAnyHistory: Bool
    let dayOverDayLabel: String
    let todayHourMinutes: [Int]
    let todayTimelineBlocks: [FocusStats.TimelineBlock]

    var headlineInsight: String? { insights.first }

    var rangeSubtitle: String {
        let mins = rangeTotals.minutes
        let pomos = rangeTotals.pomodoros
        let time = FocusStats.formatTotalMinutes(mins)
            .replacingOccurrences(of: "分钟", with: "分")
        if range == .today {
            return "\(pomos) 番茄 · \(time) · \(dayOverDayLabel)"
        }
        return "\(range.rawValue) · \(pomos) 番茄 · \(time)"
    }

    var dayOverDayShortValue: String {
        if yesterdayMinutes <= 0 {
            return totalMinutesToday > 0 ? "—" : "0"
        }
        guard let pct = FocusStats.percentChange(from: yesterdayMinutes, to: totalMinutesToday) else {
            return "—"
        }
        if pct > 0 { return "+\(pct)%" }
        return "\(pct)%"
    }

    static func build(
        range: AnalyticsTimeRange,
        focusSessions: [FocusSession],
        tasks: [FocusTask],
        dailyGoal: Int,
        completedPomodoros: Int,
        totalSecondsToday: Int,
        isWorkMode: Bool,
        sessionLive: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnalyticsDashboardModel {
        let todayStart = calendar.startOfDay(for: now)
        let bounds = range.dayBounds(relativeTo: now, calendar: calendar)
        let pairs = focusSessions.map { ($0.timestamp, $0.durationMinutes) }
        let sessionsInRange = focusSessions.filter { session in
            let day = calendar.startOfDay(for: session.timestamp)
            return day >= bounds.from && day <= bounds.through
        }

        let baseRange = FocusStats.rangeTotals(
            sessions: pairs,
            from: bounds.from,
            through: bounds.through,
            calendar: calendar
        )
        let historyToday = FocusStats.dayTotals(sessions: pairs, on: todayStart, calendar: calendar).minutes
        let totalMinutesToday = totalSecondsToday / 60
        var rangeTotals = baseRange
        if bounds.through >= todayStart, isWorkMode, sessionLive {
            let liveMinutes = max(0, totalMinutesToday - historyToday)
            if liveMinutes > 0 {
                rangeTotals = FocusStats.DayFocusTotals(
                    pomodoros: baseRange.pomodoros,
                    minutes: baseRange.minutes + liveMinutes
                )
            }
        }

        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)
            ?? todayStart.addingTimeInterval(-86_400)
        let yesterdayMinutes = FocusStats.dayTotals(
            sessions: pairs,
            on: yesterdayStart,
            calendar: calendar
        ).minutes

        let streak = FocusStats.streaks(
            sessionTimestamps: focusSessions.map(\.timestamp),
            relativeTo: now,
            calendar: calendar
        ).current

        let freeFrom = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let freeWindow = focusSessions.filter {
            let day = calendar.startOfDay(for: $0.timestamp)
            return day >= freeFrom && day <= todayStart
        }
        let freeShare = FocusStats.freeFocusShare(
            freeCount: freeWindow.filter { $0.taskId == nil }.count,
            totalCount: freeWindow.count
        )

        let goalProgress: Double = {
            guard dailyGoal > 0 else { return 0 }
            return min(Double(completedPomodoros) / Double(dailyGoal), 1.0)
        }()

        let insights = FocusStats.smartInsights(
            todayPomodoros: completedPomodoros,
            todayMinutes: totalMinutesToday,
            yesterdayMinutes: yesterdayMinutes,
            dailyGoal: dailyGoal,
            currentStreak: streak,
            freeFocusShare: freeShare,
            hasAnyHistory: !focusSessions.isEmpty
        )

        let categoryTop = Self.categoryTop(sessions: sessionsInRange, tasks: tasks)

        let timelineInput = focusSessions.map {
            (timestamp: $0.timestamp, minutes: $0.durationMinutes, title: $0.taskTitle)
        }

        return AnalyticsDashboardModel(
            range: range,
            calendar: calendar,
            todayStart: todayStart,
            rangeBounds: bounds,
            sessionPairs: pairs,
            sessionsInRange: sessionsInRange,
            rangeTotals: rangeTotals,
            totalMinutesToday: totalMinutesToday,
            yesterdayMinutes: yesterdayMinutes,
            streakCurrent: streak,
            freeShare: freeShare,
            goalProgress: goalProgress,
            goalRemaining: max(0, dailyGoal - completedPomodoros),
            completedPomodoros: completedPomodoros,
            dailyGoal: dailyGoal,
            insights: insights,
            categoryTop: categoryTop,
            recentSessions: Array(sessionsInRange.sorted { $0.timestamp > $1.timestamp }.prefix(8)),
            hasAnyHistory: !focusSessions.isEmpty,
            dayOverDayLabel: FocusStats.dayOverDayMinutesLabel(
                todayMinutes: totalMinutesToday,
                yesterdayMinutes: yesterdayMinutes
            ),
            todayHourMinutes: FocusStats.minutesByHourOfDay(
                sessions: pairs,
                on: todayStart,
                calendar: calendar
            ),
            todayTimelineBlocks: FocusStats.timelineBlocks(
                sessions: timelineInput,
                on: todayStart,
                calendar: calendar
            )
        )
    }

    private static func categoryTop(
        sessions: [FocusSession],
        tasks: [FocusTask]
    ) -> [(name: String, icon: String, color: Color, minutes: Int)] {
        var minutesStats = [TaskCategory: Int]()
        for session in sessions {
            let cat: TaskCategory?
            if let c = session.taskCategory {
                cat = c
            } else if let id = session.taskId,
                      let task = tasks.first(where: { $0.id == id }) {
                cat = task.category
            } else if session.taskId == nil {
                cat = nil
            } else {
                cat = .other
            }
            guard let cat else { continue }
            minutesStats[cat, default: 0] += session.durationMinutes
        }
        return minutesStats
            .map { (name: $0.key.rawValue, icon: $0.key.icon, color: $0.key.color, minutes: $0.value) }
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes > $1.minutes }
            .prefix(3)
            .map { $0 }
    }

    func resolvedCategory(for session: FocusSession, tasks: [FocusTask]) -> TaskCategory? {
        if let c = session.taskCategory { return c }
        if let id = session.taskId,
           let task = tasks.first(where: { $0.id == id }) {
            return task.category
        }
        return nil
    }

    func reportText(username: String) -> (subject: String, body: String) {
        AnalyticsReport.buildPlainText(
            username: username,
            rangeLabel: range.rawValue,
            from: rangeBounds.from,
            through: rangeBounds.through,
            rangePomodoros: rangeTotals.pomodoros,
            rangeMinutes: rangeTotals.minutes,
            todayPomodoros: completedPomodoros,
            todayMinutes: totalMinutesToday,
            streakCurrent: streakCurrent,
            freeFocusShare: freeShare,
            categoryLines: categoryTop.map { ($0.name, $0.minutes) },
            dayOverDayLabel: dayOverDayLabel
        )
    }
}

// Compatibility alias used by older call sites / tests.
typealias AnalyticsRange = AnalyticsTimeRange
