import Foundation

/// Lightweight task snapshot for pure filtering (no SwiftUI).
public struct TaskSnapshot: Equatable, Identifiable {
    public var id: UUID
    public var isCompleted: Bool
    public var dueDate: Date?
    public var priority: Int
    public var createdAt: Date
    /// Series tasks from a study plan: hidden before this day, then in 今天 until done.
    public var startDate: Date?
    /// Checklist / plan tasks show a calm pace instead of 「逾期」, so they never count as overdue.
    public var isPaced: Bool
    
    public init(
        id: UUID = UUID(),
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: Int = 1,
        createdAt: Date = Date(),
        startDate: Date? = nil,
        isPaced: Bool = false
    ) {
        self.id = id
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.createdAt = createdAt
        self.startDate = startDate
        self.isPaced = isPaced
    }
}

public enum TaskListFilter: Equatable {
    case today
    case tomorrow
    case week
    case planned
    case completed
    case inbox
}

public enum TaskFiltering {
    
    public static func isOverdue(
        dueDate: Date?,
        isCompleted: Bool,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let due = dueDate, !isCompleted else { return false }
        let dueDay = calendar.startOfDay(for: due)
        let today = calendar.startOfDay(for: now)
        return dueDay < today
    }
    
    /// Whether a single task belongs in `list` (no sorting — for badges / counts).
    public static func matches(
        _ task: TaskSnapshot,
        list: TaskListFilter,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today.addingTimeInterval(172_800)
        let weekLater = calendar.date(byAdding: .day, value: 7, to: today) ?? today.addingTimeInterval(604_800)
        
        // A task with a start day is in 今天 from that day until it is done, and never in 明天.
        // Without one, the original due-date rules apply unchanged.
        if let start = task.startDate {
            switch list {
            case .today:
                return !task.isCompleted && calendar.startOfDay(for: start) <= today
            case .tomorrow:
                return false
            case .week, .planned, .completed, .inbox:
                break
            }
        }

        switch list {
        case .today:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            return calendar.startOfDay(for: due) <= today
        case .tomorrow:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: tomorrow)
        case .week:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            let dueDay = calendar.startOfDay(for: due)
            return dueDay >= dayAfterTomorrow && dueDay <= weekLater
        case .planned:
            return !task.isCompleted && (task.dueDate != nil || task.startDate != nil)
        case .completed:
            return task.isCompleted
        case .inbox:
            return !task.isCompleted && task.dueDate == nil && task.startDate == nil
        }
    }
    
    /// One O(n) pass for sidebar badges (avoids six full filter+sorts on every body).
    public struct SidebarBadgeCounts: Equatable {
        public var today: Int
        public var overdue: Int
        public var tomorrow: Int
        public var week: Int
        public var planned: Int
        public var inbox: Int
        
        public init(today: Int = 0, overdue: Int = 0, tomorrow: Int = 0, week: Int = 0, planned: Int = 0, inbox: Int = 0) {
            self.today = today
            self.overdue = overdue
            self.tomorrow = tomorrow
            self.week = week
            self.planned = planned
            self.inbox = inbox
        }
    }
    
    public static func sidebarBadgeCounts(
        _ tasks: [TaskSnapshot],
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> SidebarBadgeCounts {
        var counts = SidebarBadgeCounts()
        for task in tasks {
            if matches(task, list: .today, relativeTo: now, calendar: calendar) {
                counts.today += 1
                if !task.isPaced,
                   isOverdue(dueDate: task.dueDate, isCompleted: task.isCompleted, relativeTo: now, calendar: calendar) {
                    counts.overdue += 1
                }
            }
            if matches(task, list: .tomorrow, relativeTo: now, calendar: calendar) { counts.tomorrow += 1 }
            if matches(task, list: .week, relativeTo: now, calendar: calendar) { counts.week += 1 }
            if matches(task, list: .planned, relativeTo: now, calendar: calendar) { counts.planned += 1 }
            if matches(task, list: .inbox, relativeTo: now, calendar: calendar) { counts.inbox += 1 }
        }
        return counts
    }
    
    public static func filter(
        _ tasks: [TaskSnapshot],
        as list: TaskListFilter,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskSnapshot] {
        let result = tasks.filter { matches($0, list: list, relativeTo: now, calendar: calendar) }
        
        return result.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                let lDay = calendar.startOfDay(for: l)
                let rDay = calendar.startOfDay(for: r)
                if lDay != rDay { return lDay < rDay }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
