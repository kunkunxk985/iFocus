import Foundation

/// Pure focus analytics helpers used by Profile / Analytics / reports.
public enum FocusStats {
    
    // MARK: - Formatting
    
    public static func formatTotalMinutes(_ totalMins: Int) -> String {
        // Negative inputs are treated as zero (defensive for corrupt stats).
        let totalMins = max(0, totalMins)
        if totalMins <= 0 { return "0分钟" }
        let h = totalMins / 60
        let m = totalMins % 60
        if h > 0 && m > 0 {
            return "\(h)小时\(m)分"
        } else if h > 0 {
            return "\(h)小时"
        }
        return "\(m)分钟"
    }
    
    public static func completionRate(total: Int, completed: Int) -> String {
        guard total > 0 else { return "0%" }
        let safeCompleted = max(0, completed)
        let rate = min(100, (safeCompleted * 100) / total)
        return "\(rate)%"
    }
    
    // MARK: - Streaks
    
    /// Current and longest consecutive-day streaks from focus session timestamps.
    public static func streaks(
        sessionTimestamps: [Date],
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> (current: Int, longest: Int) {
        let today = calendar.startOfDay(for: now)
        let sessionDays = Set(sessionTimestamps.map { calendar.startOfDay(for: $0) })
        let sortedDays = sessionDays.sorted(by: >)
        
        guard !sortedDays.isEmpty else { return (0, 0) }
        
        var current = 0
        var checkDate = today
        
        if !sessionDays.contains(today) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               sessionDays.contains(yesterday) {
                checkDate = yesterday
            } else {
                checkDate = today
            }
        }
        
        if sessionDays.contains(checkDate) {
            while sessionDays.contains(checkDate) {
                current += 1
                guard let nextCheck = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = nextCheck
            }
        }
        
        var longest = 0
        var tempStreak = 0
        var prevDate: Date?
        
        for date in sortedDays.sorted() {
            if let prev = prevDate {
                let diff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                if diff == 1 {
                    tempStreak += 1
                } else if diff > 1 {
                    longest = max(longest, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            prevDate = date
        }
        longest = max(longest, tempStreak)
        
        return (current, longest)
    }
    
    // MARK: - Peak hours
    
    public static func peakFocusHoursString(
        sessionTimestamps: [Date],
        calendar: Calendar = .current
    ) -> String {
        guard !sessionTimestamps.isEmpty else { return "暂无数据" }
        var hourCounts = [Int: Int]()
        for ts in sessionTimestamps {
            let hour = calendar.component(.hour, from: ts)
            hourCounts[hour, default: 0] += 1
        }
        guard let peakHour = hourCounts.max(by: { $0.value < $1.value })?.key else {
            return "暂无数据"
        }
        let startStr = String(format: "%02d:00", peakHour)
        let endStr = String(format: "%02d:00", (peakHour + 1) % 24)
        return "\(startStr) - \(endStr)"
    }
    
    // MARK: - Daily aggregation
    
    public static func averageDailyFocusMinutes(
        sessionTimestamps: [Date],
        totalMinutes: Int,
        calendar: Calendar = .current
    ) -> Int {
        let sessionDays = Set(sessionTimestamps.map { calendar.startOfDay(for: $0) })
        let days = max(1, sessionDays.count)
        return totalMinutes / days
    }
    
    /// Minutes focused per calendar day (start-of-day keys).
    public static func minutesByDay(
        sessions: [(timestamp: Date, minutes: Int)],
        calendar: Calendar = .current
    ) -> [Date: Int] {
        var map = [Date: Int]()
        for s in sessions {
            let day = calendar.startOfDay(for: s.timestamp)
            map[day, default: 0] += s.minutes
        }
        return map
    }
    
    // MARK: - Heatmap grid (53 weeks × 7 days)
    
    public struct ContributionCell: Equatable {
        public let date: Date
        public let minutes: Int
        
        public init(date: Date, minutes: Int) {
            self.date = date
            self.minutes = minutes
        }
    }
    
    /// Columns of weeks, each with up to 7 day cells (Sun–Sat depending on calendar).
    public static func contributionGrid(
        minutesByDay: [Date: Int],
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        weeks: Int = 53
    ) -> [[ContributionCell]] {
        let today = calendar.startOfDay(for: now)
        let currentWeekday = calendar.component(.weekday, from: today)
        
        var columns: [[ContributionCell]] = []
        for c in 0..<weeks {
            var columnCells: [ContributionCell] = []
            for r in 0..<7 {
                let dayOffset = ((c - (weeks - 1)) * 7) + (r - (currentWeekday - 1))
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    let dayStart = calendar.startOfDay(for: date)
                    let mins = minutesByDay[dayStart] ?? 0
                    columnCells.append(ContributionCell(date: date, minutes: mins))
                }
            }
            columns.append(columnCells)
        }
        return columns
    }
    
    public static func monthLabels(
        for grid: [[ContributionCell]],
        calendar: Calendar = .current
    ) -> [Int: String] {
        var labels: [Int: String] = [:]
        for c in 0..<grid.count {
            guard let firstCellDate = grid[c].first?.date else { continue }
            let month = calendar.component(.month, from: firstCellDate)
            if c > 0 {
                if let prevDate = grid[c - 1].first?.date {
                    let prevMonth = calendar.component(.month, from: prevDate)
                    if month != prevMonth {
                        labels[c] = "\(month)月"
                    }
                }
            } else {
                labels[c] = "\(month)月"
            }
        }
        return labels
    }
    
    /// Heatmap intensity bucket 0...4 for styling.
    public static func intensityLevel(minutes: Int) -> Int {
        if minutes <= 0 { return 0 }
        if minutes <= 25 { return 1 }
        if minutes <= 50 { return 2 }
        if minutes <= 100 { return 3 }
        return 4
    }
    
    // MARK: - Analytics dashboard helpers
    
    public struct DayFocusTotals: Equatable {
        public let pomodoros: Int
        public let minutes: Int
        
        public init(pomodoros: Int = 0, minutes: Int = 0) {
            self.pomodoros = max(0, pomodoros)
            self.minutes = max(0, minutes)
        }
    }
    
    /// Aggregate pomodoros + minutes for a single calendar day.
    public static func dayTotals(
        sessions: [(timestamp: Date, minutes: Int)],
        on day: Date,
        calendar: Calendar = .current
    ) -> DayFocusTotals {
        let dayStart = calendar.startOfDay(for: day)
        var pomos = 0
        var mins = 0
        for s in sessions {
            guard calendar.isDate(s.timestamp, inSameDayAs: dayStart) else { continue }
            pomos += 1
            mins += max(0, s.minutes)
        }
        return DayFocusTotals(pomodoros: pomos, minutes: mins)
    }
    
    /// Inclusive range of calendar days: `[fromDay, throughDay]`.
    public static func rangeTotals(
        sessions: [(timestamp: Date, minutes: Int)],
        from fromDay: Date,
        through throughDay: Date,
        calendar: Calendar = .current
    ) -> DayFocusTotals {
        let start = calendar.startOfDay(for: fromDay)
        let end = calendar.startOfDay(for: throughDay)
        let lo = min(start, end)
        let hi = max(start, end)
        var pomos = 0
        var mins = 0
        for s in sessions {
            let d = calendar.startOfDay(for: s.timestamp)
            guard d >= lo && d <= hi else { continue }
            pomos += 1
            mins += max(0, s.minutes)
        }
        return DayFocusTotals(pomodoros: pomos, minutes: mins)
    }
    
    /// Integer percent change. `nil` when baseline is 0 (undefined / avoid fake ∞).
    public static func percentChange(from previous: Int, to current: Int) -> Int? {
        guard previous > 0 else { return nil }
        return Int(((Double(current - previous) / Double(previous)) * 100.0).rounded())
    }
    
    /// Human label for day-over-day minutes, e.g. "较昨日 +20%" / "与昨日持平" / "昨日无记录".
    public static func dayOverDayMinutesLabel(todayMinutes: Int, yesterdayMinutes: Int) -> String {
        if yesterdayMinutes <= 0 {
            return todayMinutes > 0 ? "昨日无记录" : "暂无对比"
        }
        guard let pct = percentChange(from: yesterdayMinutes, to: todayMinutes) else {
            return "暂无对比"
        }
        if pct == 0 { return "与昨日持平" }
        if pct > 0 { return "较昨日 +\(pct)%" }
        return "较昨日 \(pct)%"
    }
    
    /// Free-focus share of sessions in `0...1`.
    public static func freeFocusShare(freeCount: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return min(1, max(0, Double(max(0, freeCount)) / Double(totalCount)))
    }
    
    /// 24 bins (hour 0...23) of focus minutes for a single calendar day.
    /// Minutes are attributed to the session start hour (simple, stable model).
    public static func minutesByHourOfDay(
        sessions: [(timestamp: Date, minutes: Int)],
        on day: Date,
        calendar: Calendar = .current
    ) -> [Int] {
        var bins = Array(repeating: 0, count: 24)
        let dayStart = calendar.startOfDay(for: day)
        for s in sessions {
            guard calendar.isDate(s.timestamp, inSameDayAs: dayStart) else { continue }
            let hour = calendar.component(.hour, from: s.timestamp)
            guard (0..<24).contains(hour) else { continue }
            bins[hour] += max(0, s.minutes)
        }
        return bins
    }
    
    /// Peak hour label from a 24-bin minutes array, or nil if all zero.
    public static func peakHourLabel(fromHourMinutes hours: [Int]) -> String? {
        guard hours.count == 24, let maxVal = hours.max(), maxVal > 0,
              let peak = hours.firstIndex(of: maxVal) else { return nil }
        return String(format: "%02d:00–%02d:00", peak, (peak + 1) % 24 == 0 ? 24 : peak + 1)
    }
    
    /// Up to two data-driven tips for the analytics dashboard (Chinese, product tone).
    public static func smartInsights(
        todayPomodoros: Int,
        todayMinutes: Int,
        yesterdayMinutes: Int,
        dailyGoal: Int,
        currentStreak: Int,
        freeFocusShare: Double,
        hasAnyHistory: Bool
    ) -> [String] {
        var tips: [String] = []
        
        if !hasAnyHistory {
            tips.append("还没有专注记录。从清单选一个小任务，或直接开始自由专注。")
            return tips
        }
        
        if todayPomodoros == 0 && todayMinutes == 0 {
            tips.append("今天还没开始。挑一个最小任务，先完成 1 个番茄。")
        } else if dailyGoal > 0, todayPomodoros >= dailyGoal {
            tips.append("今日目标已达成（\(todayPomodoros)/\(dailyGoal)）。可以收工，或做些轻松任务。")
        } else if dailyGoal > 0 {
            let left = dailyGoal - todayPomodoros
            tips.append("距离今日目标还差 \(left) 个番茄，保持节奏即可。")
        }
        
        if freeFocusShare >= 0.6, tips.count < 2 {
            tips.append("近期自由专注偏多。绑定任务后，分类统计会更有意义。")
        }
        
        if currentStreak >= 3, tips.count < 2 {
            tips.append("已连续专注 \(currentStreak) 天，习惯正在成形，继续保持。")
        }
        
        if let pct = percentChange(from: yesterdayMinutes, to: todayMinutes),
           pct <= -30,
           yesterdayMinutes >= 25,
           tips.count < 2 {
            tips.append("今日专注时长明显低于昨天。若太累，不妨把目标调低一点。")
        }
        
        if tips.isEmpty {
            tips.append("专注前先选定任务，统计会更清晰；每 4 个番茄安排一次长休息。")
        }
        
        return Array(tips.prefix(2))
    }
}
