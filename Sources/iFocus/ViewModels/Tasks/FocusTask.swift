import Foundation
import SwiftUI
import iFocusCore

/// How a task repeats after completion (or rolls forward when overdue).
enum TaskRecurrence: String, CaseIterable, Identifiable, Codable {
    case none = "不重复"
    case daily = "每天"
    case weekly = "每周"
    
    var id: String { rawValue }
}

struct FocusTask: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var category: TaskCategory
    var isCompleted: Bool = false
    var priority: Int = 1 // 1-4 red dots
    var estimatedPomodoros: Int = 1
    var completedPomodoros: Int = 0
    var dueDate: Date?
    var createdAt: Date = Date()
    var timeSpentMinutes: Int = 0 // accumulated focus time
    /// Manual pin — always sorts above unpinned in the same list.
    var isPinned: Bool = false
    /// Lower = higher in list after pin. User drag-reorder updates this.
    var sortIndex: Int = 0
    var recurrence: TaskRecurrence = .none
    /// Optional longer description (not shown as primary title).
    var notes: String = ""
    /// Optional URL string (opened in browser when valid).
    var linkURL: String = ""
    // Added in 1.14. All optional: nil means 1.13 behaviour, and old files decode unchanged.
    /// Series checklist (episodes, chapters…). Use `checklist` to read it.
    var items: [ChecklistItem]? = nil
    /// 集 / 章 / 项 / 篇 for progress copy; nil = 项.
    var itemUnit: String? = nil
    /// Plan tasks: hidden from 今天 before this day, then shown until done.
    var startDate: Date? = nil
    /// Identifies a task created by a plan import, so re-importing never duplicates it.
    var planKey: String? = nil
    /// When the task was last marked complete.
    var completedAt: Date? = nil

    var checklist: [ChecklistItem] { items ?? [] }

    var unitLabel: String { itemUnit ?? ChecklistProgress.defaultUnit }

    /// Checklist / plan tasks show a calm pace instead of 「逾期」.
    var isPaced: Bool { planKey != nil || startDate != nil || !checklist.isEmpty }
    
    var isOverdue: Bool {
        !isPaced && TaskFiltering.isOverdue(dueDate: dueDate, isCompleted: isCompleted)
    }
    
    var hasLink: Bool {
        guard let url = URL(string: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    var snapshot: TaskSnapshot {
        TaskSnapshot(
            id: id,
            isCompleted: isCompleted,
            dueDate: dueDate,
            priority: priority,
            createdAt: createdAt,
            startDate: startDate,
            isPaced: isPaced
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, isCompleted, priority
        case estimatedPomodoros, completedPomodoros, dueDate, createdAt, timeSpentMinutes
        case isPinned, sortIndex, recurrence, notes, linkURL
        case items, itemUnit, startDate, planKey, completedAt
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        category: TaskCategory,
        isCompleted: Bool = false,
        priority: Int = 1,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        timeSpentMinutes: Int = 0,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        recurrence: TaskRecurrence = .none,
        notes: String = "",
        linkURL: String = "",
        items: [ChecklistItem]? = nil,
        itemUnit: String? = nil,
        startDate: Date? = nil,
        planKey: String? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.isCompleted = isCompleted
        self.priority = priority
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.timeSpentMinutes = timeSpentMinutes
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.recurrence = recurrence
        self.notes = notes
        self.linkURL = linkURL
        self.items = items
        self.itemUnit = itemUnit
        self.startDate = startDate
        self.planKey = planKey
        self.completedAt = completedAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        category = try c.decode(TaskCategory.self, forKey: .category)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        estimatedPomodoros = try c.decodeIfPresent(Int.self, forKey: .estimatedPomodoros) ?? 1
        completedPomodoros = try c.decodeIfPresent(Int.self, forKey: .completedPomodoros) ?? 0
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        timeSpentMinutes = try c.decodeIfPresent(Int.self, forKey: .timeSpentMinutes) ?? 0
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        recurrence = try c.decodeIfPresent(TaskRecurrence.self, forKey: .recurrence) ?? .none
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        linkURL = try c.decodeIfPresent(String.self, forKey: .linkURL) ?? ""
        // 1.14 fields: never let one of them make the whole task unreadable.
        items = try? c.decodeIfPresent([ChecklistItem].self, forKey: .items)
        itemUnit = try? c.decodeIfPresent(String.self, forKey: .itemUnit)
        startDate = try? c.decodeIfPresent(Date.self, forKey: .startDate)
        planKey = try? c.decodeIfPresent(String.self, forKey: .planKey)
        completedAt = try? c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
    
    /// Next due date after completing (or rolling) a recurring task.
    static func nextDueDate(
        after due: Date?,
        recurrence: TaskRecurrence,
        calendar: Calendar = .current
    ) -> Date? {
        guard recurrence != .none else { return nil }
        let base = calendar.startOfDay(for: due ?? Date())
        switch recurrence {
        case .none: return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: base)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: base)
        }
    }
}

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var taskId: UUID?
    var taskTitle: String
    var taskCategory: TaskCategory?
    var durationMinutes: Int
    var timestamp: Date

    init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        taskTitle: String,
        taskCategory: TaskCategory? = nil,
        durationMinutes: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.taskCategory = taskCategory
        self.durationMinutes = durationMinutes
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, taskId, taskTitle, taskCategory, durationMinutes, timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.taskId = try? c.decodeIfPresent(UUID.self, forKey: .taskId)
        self.taskTitle = try c.decode(String.self, forKey: .taskTitle)
        self.taskCategory = try? c.decodeIfPresent(TaskCategory.self, forKey: .taskCategory)
        self.durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
    }
}
