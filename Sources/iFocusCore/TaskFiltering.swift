import Foundation

/// Lightweight task snapshot for pure filtering (no SwiftUI).
public struct TaskSnapshot: Equatable, Identifiable {
    public var id: UUID
    public var isCompleted: Bool
    public var dueDate: Date?
    public var priority: Int
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.createdAt = createdAt
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
    
    public static func filter(
        _ tasks: [TaskSnapshot],
        as list: TaskListFilter,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskSnapshot] {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today.addingTimeInterval(172_800)
        let weekLater = calendar.date(byAdding: .day, value: 7, to: today) ?? today.addingTimeInterval(604_800)
        
        let result: [TaskSnapshot]
        switch list {
        case .today:
            result = tasks.filter { task in
                guard !task.isCompleted, let due = task.dueDate else { return false }
                let dueDay = calendar.startOfDay(for: due)
                return dueDay <= today
            }
        case .tomorrow:
            result = tasks.filter { task in
                guard !task.isCompleted, let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: tomorrow)
            }
        case .week:
            result = tasks.filter { task in
                guard !task.isCompleted, let due = task.dueDate else { return false }
                let dueDay = calendar.startOfDay(for: due)
                return dueDay >= dayAfterTomorrow && dueDay <= weekLater
            }
        case .planned:
            result = tasks.filter { task in
                !task.isCompleted && task.dueDate != nil
            }
        case .completed:
            result = tasks.filter(\.isCompleted)
        case .inbox:
            result = tasks.filter { task in
                !task.isCompleted && task.dueDate == nil
            }
        }
        
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
