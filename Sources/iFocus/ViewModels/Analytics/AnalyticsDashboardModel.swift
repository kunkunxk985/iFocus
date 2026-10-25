import Foundation
import SwiftUI
import iFocusCore

/// Profile cards + heatmap bundled with the range dashboard — one pass over sessions/tasks per refresh.
struct AnalyticsPageSnapshot {
    let model: AnalyticsDashboardModel
    let heatmapGrid: [[FocusStats.ContributionCell]]
    let heatmapMonthLabels: [Int: String]
    let categoryStats: [ProfileCategoryStat]
    let totalMinutesAllTime: Int
    let maxSingleFocusSession: Int
    let averageDailyLabel: String
    let peakHours: String
    let completionRate: String

    static func build(
        range: AnalyticsTimeRange,
        focusSessions: [FocusSession],
        tasks: [FocusTask],
        categoriesInUse: [TaskCategory],
        dailyGoal: Int,
        completedPomodoros: Int,
        totalSecondsToday: Int,
        isWorkMode: Bool,
        sessionLive: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnalyticsPageSnapshot {
        let taskByID = AnalyticsDashboardModel.taskByID(from: tasks)
        let pairs = focusSessions.map { ($0.timestamp, $0.durationMinutes) }
        let sessionTimestamps = focusSessions.map(\.timestamp)

        var totalMinutesAllTime = 0
        var maxSingle = 0
        var minutesByCategoryID = [String: Int]()
        var countByCategoryID = [String: Int]()
        var categoriesByID = AnalyticsDashboardModel.categoriesByID(from: categoriesInUse)

        for session in focusSessions {
            totalMinutesAllTime += session.durationMinutes
            maxSingle = max(maxSingle, session.durationMinutes)
            let category = AnalyticsDashboardModel.resolveCategory(
                for: session,
                taskByID: taskByID
            )
            if categoriesByID[category.id] == nil {
                categoriesByID[category.id] = category
            }
            minutesByCategoryID[category.id, default: 0] += session.durationMinutes
            countByCategoryID[category.id, default: 0] += 1
        }

        let byDay = FocusStats.minutesByDay(sessions: pairs)
        let heatmapGrid = FocusStats.contributionGrid(minutesByDay: byDay)
        let heatmapMonthLabels = FocusStats.monthLabels(for: heatmapGrid)

        let categoryStats = categoriesInUse
            .map { cat in
                ProfileCategoryStat(
                    category: categoriesByID[cat.id] ?? cat,
                    minutes: minutesByCategoryID[cat.id] ?? 0,
                    count: countByCategoryID[cat.id] ?? 0
                )
            }
            .sorted { $0.minutes > $1.minutes }

        let completedTasks = tasks.reduce(0) { $0 + ($1.isCompleted ? 1 : 0) }
        let completionRate = FocusStats.completionRate(total: tasks.count, completed: completedTasks)
        let averageDailyLabel = FocusStats.formatTotalMinutes(
            FocusStats.averageDailyFocusMinutes(
                sessionTimestamps: sessionTimestamps,
                totalMinutes: totalMinutesAllTime
            )
        )
        let peakHours = FocusStats.peakFocusHoursString(sessionTimestamps: sessionTimestamps)

        let model = AnalyticsDashboardModel.build(
            range: range,
            focusSessions: focusSessions,
            tasks: tasks,
            taskByID: taskByID,
            sessionPairs: pairs,
            sessionTimestamps: sessionTimestamps,
            dailyGoal: dailyGoal,
            completedPomodoros: completedPomodoros,
            totalSecondsToday: totalSecondsToday,
            isWorkMode: isWorkMode,
            sessionLive: sessionLive,
            now: now,
            calendar: calendar
        )

        return AnalyticsPageSnapshot(
            model: model,
            heatmapGrid: heatmapGrid,
            heatmapMonthLabels: heatmapMonthLabels,
            categoryStats: categoryStats,
            totalMinutesAllTime: totalMinutesAllTime,
            maxSingleFocusSession: maxSingle,
            averageDailyLabel: averageDailyLabel,
            peakHours: peakHours,
            completionRate: completionRate
        )
    }
}

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
        let taskByID = Self.taskByID(from: tasks)
        let pairs = focusSessions.map { ($0.timestamp, $0.durationMinutes) }
        let sessionTimestamps = focusSessions.map(\.timestamp)
        return build(
            range: range,
            focusSessions: focusSessions,
            tasks: tasks,
            taskByID: taskByID,
            sessionPairs: pairs,
            sessionTimestamps: sessionTimestamps,
            dailyGoal: dailyGoal,
            completedPomodoros: completedPomodoros,
            totalSecondsToday: totalSecondsToday,
            isWorkMode: isWorkMode,
            sessionLive: sessionLive,
            now: now,
            calendar: calendar
        )
    }

    static func build(
        range: AnalyticsTimeRange,
        focusSessions: [FocusSession],
        tasks: [FocusTask],
        taskByID: [UUID: FocusTask],
        sessionPairs pairs: [(timestamp: Date, minutes: Int)],
        sessionTimestamps: [Date],
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
            sessionTimestamps: sessionTimestamps,
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

        let categoryTop = Self.categoryTop(sessions: sessionsInRange, taskByID: taskByID)

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

    /// First task wins when corrupt data duplicates ids (matches `TaskStore.tasks(for:)`).
    static func taskByID(from tasks: [FocusTask]) -> [UUID: FocusTask] {
        var byID: [UUID: FocusTask] = [:]
        byID.reserveCapacity(tasks.count)
        for task in tasks where byID[task.id] == nil {
            byID[task.id] = task
        }
        return byID
    }

    static func categoriesByID(from categories: [TaskCategory]) -> [String: TaskCategory] {
        var byID: [String: TaskCategory] = [:]
        for category in categories where byID[category.id] == nil {
            byID[category.id] = category
        }
        return byID
    }

    static func resolveCategory(for session: FocusSession, taskByID: [UUID: FocusTask]) -> TaskCategory {
        if let stored = session.taskCategory { return stored }
        if let taskId = session.taskId, let task = taskByID[taskId] {
            return task.category
        }
        return .other
    }

    private static func categoryTop(
        sessions: [FocusSession],
        taskByID: [UUID: FocusTask]
    ) -> [(name: String, icon: String, color: Color, minutes: Int)] {
        var minutesByID = [String: Int]()
        var categoryByID = [String: TaskCategory]()
        for session in sessions {
            if session.taskId == nil, session.taskCategory == nil { continue }
            let cat = resolveCategory(for: session, taskByID: taskByID)
            if categoryByID[cat.id] == nil { categoryByID[cat.id] = cat }
            minutesByID[cat.id, default: 0] += session.durationMinutes
        }
        return minutesByID.compactMap { id, minutes -> (name: String, icon: String, color: Color, minutes: Int)? in
            guard minutes > 0, let category = categoryByID[id] else { return nil }
            return (name: category.name, icon: category.icon, color: category.color, minutes: minutes)
        }
        .sorted { $0.minutes > $1.minutes }
        .prefix(3)
        .map { $0 }
    }

    func resolvedCategory(for session: FocusSession, tasks: [FocusTask]) -> TaskCategory? {
        if session.taskId == nil, session.taskCategory == nil { return nil }
        return Self.resolveCategory(for: session, taskByID: Self.taskByID(from: tasks))
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
            categoryLines: [],
            dayOverDayLabel: dayOverDayLabel
        )
    }
}

// Compatibility alias used by older call sites / tests.
