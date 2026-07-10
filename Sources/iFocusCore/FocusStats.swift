import Foundation

/// Pure focus analytics helpers used by Profile / Analytics / reports.
public enum FocusStats {
    
    // MARK: - Formatting
    
    public static func formatTotalMinutes(_ totalMins: Int) -> String {
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
        let rate = (completed * 100) / total
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
}
