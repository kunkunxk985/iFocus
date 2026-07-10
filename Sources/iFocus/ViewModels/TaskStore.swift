import Foundation
import SwiftUI
import iFocusCore

enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case work = "工作"
    case study = "学习"
    case life = "生活"
    case important = "重要"
    case home = "家"
    case other = "其他"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .work: return Color(hex: "#E65C40")
        case .study: return Color(hex: "#3B82F6")
        case .life: return Color(hex: "#10B981")
        case .important: return Color(hex: "#8B5CF6")
        case .home: return Color(hex: "#F59E0B")
        case .other: return Color(hex: "#6B7280")
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .life: return "heart.fill"
        case .important: return "flag.fill"
        case .home: return "house.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

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
    
    var isOverdue: Bool {
        TaskFiltering.isOverdue(dueDate: dueDate, isCompleted: isCompleted)
    }
    
    var snapshot: TaskSnapshot {
        TaskSnapshot(
            id: id,
            isCompleted: isCompleted,
            dueDate: dueDate,
            priority: priority,
            createdAt: createdAt
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, isCompleted, priority
        case estimatedPomodoros, completedPomodoros, dueDate, createdAt, timeSpentMinutes
        case isPinned, sortIndex, recurrence
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
        recurrence: TaskRecurrence = .none
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
    var id = UUID()
    var taskId: UUID?
    var taskTitle: String
    var taskCategory: TaskCategory?
    var durationMinutes: Int
    var timestamp: Date
}

class TaskStore: ObservableObject {
    private struct PersistedState: Codable {
        var activeTaskId: UUID?
    }

    private var isLoadingFromDisk = false
    private var saveTasksWorkItem: DispatchWorkItem?
    private var saveSessionsWorkItem: DispatchWorkItem?
    private var saveStateWorkItem: DispatchWorkItem?
    
    @Published var tasks: [FocusTask] = [] {
        didSet {
            guard !isLoadingFromDisk else { return }
            scheduleSaveTasks()
        }
    }
    @Published var focusSessions: [FocusSession] = [] {
        didSet {
            guard !isLoadingFromDisk else { return }
            scheduleSaveSessions()
        }
    }
    
    @Published var newTaskTitle: String = ""
    @Published var newTaskCategory: TaskCategory = .study
    @Published var newTaskPriority: Int = 2
    @Published var newTaskPomodoros: Int = 1
    @Published var activeTaskId: UUID? = nil {
        didSet {
            guard !isLoadingFromDisk, oldValue != activeTaskId else { return }
            scheduleSaveState()
        }
    }
    
    var activeTask: FocusTask? {
        guard let id = activeTaskId else { return nil }
        return tasks.first { $0.id == id }
    }
    
    enum TaskFilter {
        case todayTask
        case tomorrowTask
        case weekTask
        case plannedTask
        case completedTask
        case inboxTask
    }
    
    func tasks(for filter: TaskFilter) -> [FocusTask] {
        let kind: TaskListFilter
        switch filter {
        case .todayTask: kind = .today
        case .tomorrowTask: kind = .tomorrow
        case .weekTask: kind = .week
        case .plannedTask: kind = .planned
        case .completedTask: kind = .completed
        case .inboxTask: kind = .inbox
        }
        
        let orderedIDs = TaskFiltering.filter(tasks.map(\.snapshot), as: kind).map(\.id)
        // Prefer first occurrence if corrupt data ever duplicates ids (never crash).
        var byID: [UUID: FocusTask] = [:]
        byID.reserveCapacity(tasks.count)
        for task in tasks where byID[task.id] == nil {
            byID[task.id] = task
        }
        let base = orderedIDs.compactMap { byID[$0] }
        // Pin first, then user sortIndex, then keep filter order as tie-breaker.
        return base.enumerated().sorted { a, b in
            if a.element.isPinned != b.element.isPinned {
                return a.element.isPinned && !b.element.isPinned
            }
            if a.element.sortIndex != b.element.sortIndex {
                return a.element.sortIndex < b.element.sortIndex
            }
            return a.offset < b.offset
        }.map(\.element)
    }
    
    /// Sidebar badges in one pass (no six sorted filters).
    func sidebarBadgeCounts() -> TaskFiltering.SidebarBadgeCounts {
        TaskFiltering.sidebarBadgeCounts(tasks.map(\.snapshot))
    }
    
    func addFocusTime(to taskId: UUID, minutes: Int) {
        guard minutes >= 1 else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].completedPomodoros += 1
        tasks[index].timeSpentMinutes += minutes
        // Pomodoro attribution is high-value — flush tasks promptly (don't wait 0.35s debounce).
        saveTasksWorkItem?.cancel()
        saveTasks()
    }
    
    var incompleteTasks: [FocusTask] {
        tasks.filter { !$0.isCompleted }
    }
    
    var completedTasks: [FocusTask] {
        tasks.filter { $0.isCompleted }
    }
    
    var totalCompletedPomodoros: Int {
        tasks.reduce(0) { $0 + $1.completedPomodoros }
    }
    
    var totalFocusMinutes: Int {
        tasks.reduce(0) { $0 + $1.timeSpentMinutes }
    }
    
    var tasksByCategory: [(category: TaskCategory, tasks: [FocusTask])] {
        let grouped = Dictionary(grouping: incompleteTasks) { $0.category }
        return TaskCategory.allCases.compactMap { cat in
            let group = grouped[cat] ?? []
            return group.isEmpty ? nil : (cat, group)
        }
    }
    
    func addTask(for filter: TaskFilter) {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let category = newTaskCategory
        var dueDate: Date? = nil
        let today = Calendar.current.startOfDay(for: Date())
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today)
        
        switch filter {
        case .todayTask:
            dueDate = today
        case .tomorrowTask:
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: today)
        case .weekTask:
            dueDate = dayAfterTomorrow
        case .plannedTask:
            dueDate = today
        case .inboxTask:
            dueDate = nil
        case .completedTask:
            break
        }
        
        let nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        let task = FocusTask(
            title: trimmedTitle,
            category: category,
            priority: min(4, max(1, newTaskPriority)),
            estimatedPomodoros: min(20, max(1, newTaskPomodoros)),
            dueDate: dueDate,
            sortIndex: nextIndex
        )
        tasks.append(task)
        newTaskTitle = ""
    }
    
    func toggleCompletion(for task: FocusTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let wasCompleted = tasks[index].isCompleted
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted && activeTaskId == task.id {
                activeTaskId = nil
            }
            // Completing a recurring task spawns the next occurrence.
            if !wasCompleted, tasks[index].isCompleted, tasks[index].recurrence != .none {
                spawnNextRecurrence(from: tasks[index])
            }
        }
    }
    
    /// Create the next incomplete instance after completing a recurring task.
    private func spawnNextRecurrence(from completed: FocusTask) {
        guard completed.recurrence != .none else { return }
        let nextDue = FocusTask.nextDueDate(after: completed.dueDate, recurrence: completed.recurrence)
        let nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        let next = FocusTask(
            title: completed.title,
            category: completed.category,
            priority: completed.priority,
            estimatedPomodoros: completed.estimatedPomodoros,
            dueDate: nextDue,
            sortIndex: nextIndex,
            recurrence: completed.recurrence
        )
        tasks.append(next)
    }
    
    /// Incomplete recurring tasks with past due dates roll to the next cycle (keeps lists current).
    func rollForwardOverdueRecurringTasks(relativeTo now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        var changed = false
        for index in tasks.indices {
            guard !tasks[index].isCompleted, tasks[index].recurrence != .none else { continue }
            guard let due = tasks[index].dueDate else { continue }
            var cursor = calendar.startOfDay(for: due)
            var guardCount = 0
            while cursor < today, guardCount < 400 {
                guard let next = FocusTask.nextDueDate(after: cursor, recurrence: tasks[index].recurrence, calendar: calendar) else { break }
                cursor = calendar.startOfDay(for: next)
                guardCount += 1
            }
            if cursor != calendar.startOfDay(for: due) {
                tasks[index].dueDate = cursor
                changed = true
            }
        }
        if changed {
            saveTasksWorkItem?.cancel()
            saveTasks()
        }
    }
    
    // MARK: - Persistence
    
    /// Directory for `tasks.json` / `focus_sessions.json`. Injectable for unit tests.
    private let appSupportDir: URL
    
    private var tasksFileURL: URL {
        appSupportDir.appendingPathComponent("tasks.json")
    }
    
    private var sessionsFileURL: URL {
        appSupportDir.appendingPathComponent("focus_sessions.json")
    }

    private var stateFileURL: URL {
        appSupportDir.appendingPathComponent("app_state.json")
    }
    
    /// Production location: `~/Library/Application Support/iFocus/`.
    static func defaultStorageDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let url = base.appendingPathComponent("iFocus", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
    
    private static func decodeList<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        // Prefer ISO-8601; fall back to legacy deferred dates for older installs.
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            return try decoder.decode(type, from: data)
        }
    }
    
    private func scheduleSaveTasks() {
        saveTasksWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveTasks() }
        saveTasksWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    
    private func scheduleSaveSessions() {
        saveSessionsWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveSessions() }
        saveSessionsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func scheduleSaveState() {
        saveStateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveState() }
        saveStateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    
    /// Flush pending debounced writes (call before quit if needed).
    func flushPendingSaves() {
        saveTasksWorkItem?.cancel()
        saveSessionsWorkItem?.cancel()
        saveStateWorkItem?.cancel()
        saveTasks()
        saveSessions()
        saveState()
    }
    
    private func saveTasks() {
        do {
            let data = try Self.makeEncoder().encode(tasks)
            try data.write(to: tasksFileURL, options: .atomic)
        } catch {
            print("[TaskStore] saveTasks failed: \(error)")
        }
    }
    
    private func loadTasks() {
        let fileURL = tasksFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.tasks = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            self.tasks = try Self.decodeList([FocusTask].self, from: data)
        } catch {
            print("[TaskStore] loadTasks failed: \(error)")
            backupCorruptFile(at: fileURL)
            self.tasks = []
        }
    }
    
    private func saveSessions() {
        do {
            let data = try Self.makeEncoder().encode(focusSessions)
            try data.write(to: sessionsFileURL, options: .atomic)
        } catch {
            print("[TaskStore] saveSessions failed: \(error)")
        }
    }
    
    private func loadSessions() {
        let fileURL = sessionsFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.focusSessions = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            self.focusSessions = try Self.decodeList([FocusSession].self, from: data)
        } catch {
            print("[TaskStore] loadSessions failed: \(error)")
            backupCorruptFile(at: fileURL)
            self.focusSessions = []
        }
    }

    private func saveState() {
        do {
            let state = PersistedState(activeTaskId: activeTaskId)
            let data = try Self.makeEncoder().encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("[TaskStore] saveState failed: \(error)")
        }
    }

    private func loadState() {
        let fileURL = stateFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            activeTaskId = nil
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try Self.decodeList(PersistedState.self, from: data)
            if let id = state.activeTaskId,
               tasks.contains(where: { $0.id == id && !$0.isCompleted }) {
                activeTaskId = id
            } else {
                activeTaskId = nil
            }
        } catch {
            print("[TaskStore] loadState failed: \(error)")
            backupCorruptFile(at: fileURL)
            activeTaskId = nil
        }
    }
    
    /// - Parameter storageDirectory: Override for tests. `nil` uses Application Support.
    init(storageDirectory: URL? = nil) {
        if let storageDirectory {
            try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            self.appSupportDir = storageDirectory
        } else {
            self.appSupportDir = Self.defaultStorageDirectory()
        }
        isLoadingFromDisk = true
        loadTasks()
        loadSessions()
        loadState()
        isLoadingFromDisk = false
        // Roll incomplete recurring tasks whose due date is already past.
        rollForwardOverdueRecurringTasks()
    }
    
    private func backupCorruptFile(at url: URL) {
        let backupURL = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: url, to: backupURL)
    }
    
    // MARK: - Task Manipulation Helpers
    
    func updatePriority(for task: FocusTask, to priority: Int) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].priority = min(4, max(1, priority))
        }
    }
    
    func updateCategory(for task: FocusTask, to category: TaskCategory) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].category = category
        }
    }
    
    func updateDueDate(for task: FocusTask, to date: Date?) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].dueDate = date
        }
    }
    
    func updateTask(
        id: UUID,
        title: String,
        category: TaskCategory,
        priority: Int,
        estimatedPomodoros: Int,
        dueDate: Date?,
        recurrence: TaskRecurrence = .none
    ) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            // Keep previous title if the editor submitted blanks.
            if !trimmed.isEmpty {
                tasks[index].title = trimmed
            }
            tasks[index].category = category
            tasks[index].priority = min(4, max(1, priority))
            tasks[index].estimatedPomodoros = min(20, max(1, estimatedPomodoros))
            tasks[index].recurrence = recurrence
            // Normalize to start-of-day so list filters stay consistent.
            if let dueDate {
                tasks[index].dueDate = Calendar.current.startOfDay(for: dueDate)
            } else {
                tasks[index].dueDate = nil
            }
        }
    }
    
    // MARK: - Batch operations
    
    func completeTasks(ids: Set<UUID>) {
        for id in ids {
            guard let index = tasks.firstIndex(where: { $0.id == id }), !tasks[index].isCompleted else { continue }
            tasks[index].isCompleted = true
            if activeTaskId == id { activeTaskId = nil }
            if tasks[index].recurrence != .none {
                spawnNextRecurrence(from: tasks[index])
            }
        }
    }
    
    func setDueDate(ids: Set<UUID>, to date: Date?) {
        let normalized = date.map { Calendar.current.startOfDay(for: $0) }
        for id in ids {
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].dueDate = normalized
            }
        }
    }
    
    func moveToInbox(ids: Set<UUID>) {
        setDueDate(ids: ids, to: nil)
    }
    
    func deleteTasks(ids: Set<UUID>) {
        tasks.removeAll { ids.contains($0.id) }
        if let active = activeTaskId, ids.contains(active) {
            activeTaskId = nil
        }
    }
    
    func deleteTask(_ task: FocusTask) {
        tasks.removeAll { $0.id == task.id }
        if activeTaskId == task.id {
            activeTaskId = nil
        }
    }
    
    func togglePin(for task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isPinned.toggle()
        if tasks[index].isPinned {
            // New pins float to the top of the pinned group.
            let minPinned = tasks.filter(\.isPinned).map(\.sortIndex).min() ?? 0
            tasks[index].sortIndex = minPinned - 1
        }
    }
    
    /// Drag-reorder a visible section (e.g. overdue-only) inside a filter list.
    func reorderVisible(_ visible: [FocusTask], from source: IndexSet, to destination: Int, filter: TaskFilter) {
        guard !visible.isEmpty else { return }
        var section = visible
        section.move(fromOffsets: source, toOffset: destination)
        let sectionIDs = Set(visible.map(\.id))
        let full = tasks(for: filter)
        var rebuilt: [FocusTask] = []
        rebuilt.reserveCapacity(full.count)
        var sectionIndex = 0
        for task in full {
            if sectionIDs.contains(task.id) {
                if sectionIndex < section.count {
                    rebuilt.append(section[sectionIndex])
                    sectionIndex += 1
                }
            } else {
                rebuilt.append(task)
            }
        }
        for (offset, item) in rebuilt.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == item.id }) {
                tasks[idx].sortIndex = offset
            }
        }
    }
    
    func logFocusSession(
        taskId: UUID?,
        taskTitle: String,
        taskCategory: TaskCategory? = nil,
        minutes: Int
    ) {
        guard minutes >= 1 else { return }
        let session = FocusSession(
            taskId: taskId,
            taskTitle: taskTitle,
            taskCategory: taskCategory,
            durationMinutes: minutes,
            timestamp: Date()
        )
        focusSessions.append(session)
        // Completing a pomodoro must survive force-quit — write sessions immediately.
        saveSessionsWorkItem?.cancel()
        saveSessions()
    }
}
