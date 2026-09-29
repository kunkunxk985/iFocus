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
    /// Optional longer description (not shown as primary title).
    var notes: String = ""
    /// Optional URL string (opened in browser when valid).
    var linkURL: String = ""
    
    var isOverdue: Bool {
        TaskFiltering.isOverdue(dueDate: dueDate, isCompleted: isCompleted)
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
            createdAt: createdAt
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, isCompleted, priority
        case estimatedPomodoros, completedPomodoros, dueDate, createdAt, timeSpentMinutes
        case isPinned, sortIndex, recurrence, notes, linkURL
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
        linkURL: String = ""
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

class TaskStore: ObservableObject {
    private struct PersistedState: Codable {
        var activeTaskId: UUID?
    }

    private var isLoadingFromDisk = false
    /// Block only the corrupt file's writes so the other channel can still persist.
    private var blockTasksPersistence = false
    private var blockSessionsPersistence = false
    private var saveTasksWorkItem: DispatchWorkItem?
    private var saveSessionsWorkItem: DispatchWorkItem?
    private var saveStateWorkItem: DispatchWorkItem?
    private var undoDeletionWorkItem: DispatchWorkItem?
    /// Soft-deleted tasks awaiting undo (may accumulate multiple deletes in the window).
    private var pendingDeletedTasks: [FocusTask] = []
    /// Only set when a delete actually cleared the active task.
    private var pendingDeletedActiveTaskId: UUID?
    
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
    
    /// Non-nil after a corrupt tasks/sessions load — UI should show recovery options.
    @Published private(set) var dataLoadErrorMessage: String?
    
    @Published var newTaskTitle: String = ""
    @Published var newTaskCategory: TaskCategory = .study
    @Published var newTaskPriority: Int = 2
    @Published var newTaskPomodoros: Int = 1
    /// Optional recurrence applied on next quick-add (reset after add).
    @Published var newTaskRecurrence: TaskRecurrence = .none
    @Published var activeTaskId: UUID? = nil {
        didSet {
            guard !isLoadingFromDisk, oldValue != activeTaskId else { return }
            scheduleSaveState()
        }
    }
    
    /// Toast payload after delete — UI shows 「撤销」 until dismissed / expired.
    @Published private(set) var undoDeletionBanner: UndoDeletionBanner?
    
    struct UndoDeletionBanner: Equatable {
        let token: UUID
        let message: String
    }
    
    /// Override due date when quick-adding (nil = follow list filter defaults).
    enum DueOverride: Equatable {
        case today
        case tomorrow
        case inbox
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
    
    /// Add a task for the given list. Returns the new id, or nil if title blank.
    @discardableResult
    func addTask(for filter: TaskFilter, dueOverride: DueOverride? = nil) -> UUID? {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        
        let category = newTaskCategory
        let today = Calendar.current.startOfDay(for: Date())
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today)
        
        let dueDate: Date?
        if let dueOverride {
            switch dueOverride {
            case .today: dueDate = today
            case .tomorrow: dueDate = Calendar.current.date(byAdding: .day, value: 1, to: today)
            case .inbox: dueDate = nil
            }
        } else {
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
                dueDate = nil
            }
        }
        
        let nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        let recurrence = newTaskRecurrence
        let task = FocusTask(
            title: trimmedTitle,
            category: category,
            priority: min(4, max(1, newTaskPriority)),
            estimatedPomodoros: min(20, max(1, newTaskPomodoros)),
            dueDate: dueDate,
            sortIndex: nextIndex,
            recurrence: recurrence
        )
        tasks.append(task)
        newTaskTitle = ""
        newTaskRecurrence = .none
        saveTasksImmediately()
        return task.id
    }
    
    func toggleCompletion(for task: FocusTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let wasCompleted = tasks[index].isCompleted
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted && activeTaskId == task.id {
                activeTaskId = nil
            }
            // Completing a recurring task spawns the next occurrence (once per cycle).
            if !wasCompleted, tasks[index].isCompleted, tasks[index].recurrence != .none {
                spawnNextRecurrence(from: tasks[index])
            }
            saveTasksImmediately()
            saveStateImmediately()
        }
    }
    
    /// Create the next incomplete instance after completing a recurring task.
    private func spawnNextRecurrence(from completed: FocusTask) {
        guard completed.recurrence != .none else { return }
        let nextDue = FocusTask.nextDueDate(after: completed.dueDate, recurrence: completed.recurrence)
        // Avoid duplicates when user un-completes and completes again.
        if let nextDue {
            let nextDay = Calendar.current.startOfDay(for: nextDue)
            let alreadyOpen = tasks.contains { t in
                !t.isCompleted
                    && t.recurrence == completed.recurrence
                    && t.title == completed.title
                    && t.dueDate.map { Calendar.current.isDate($0, inSameDayAs: nextDay) } == true
            }
            if alreadyOpen { return }
        }
        let nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        let next = FocusTask(
            title: completed.title,
            category: completed.category,
            priority: completed.priority,
            estimatedPomodoros: completed.estimatedPomodoros,
            dueDate: nextDue,
            sortIndex: nextIndex,
            recurrence: completed.recurrence,
            notes: completed.notes,
            linkURL: completed.linkURL
        )
        tasks.append(next)
    }
    
    /// Previously rolled overdue recurring dues forward on launch (hid overdue).
    /// Kept as no-op for API stability — overdue recurring tasks stay visible.
    func rollForwardOverdueRecurringTasks(relativeTo now: Date = Date(), calendar: Calendar = .current) {
        // Intentionally empty: rolling due dates erased "已逾期" signal for daily/weekly tasks.
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

    /// Live storage directory (tasks / sessions / state). Used by backup export/import.
    var storageDirectory: URL { appSupportDir }

    /// Read raw file payloads for backup (empty Data if missing).
    func backupFilePayloads() -> [String: Data] {
        flushPendingSaves()
        var result: [String: Data] = [:]
        let fm = FileManager.default
        let mapping: [(String, URL)] = [
            (LocalBackup.tasksFileName, tasksFileURL),
            (LocalBackup.sessionsFileName, sessionsFileURL),
            (LocalBackup.stateFileName, stateFileURL),
            (
                LocalBackup.timerSessionFileName,
                appSupportDir.appendingPathComponent(LocalBackup.timerSessionFileName)
            )
        ]
        for (name, url) in mapping {
            if fm.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) {
                result[name] = data
            } else {
                // Always include valid empty arrays / objects so restore is consistent.
                switch name {
                case LocalBackup.tasksFileName, LocalBackup.sessionsFileName:
                    result[name] = Data("[]".utf8)
                case LocalBackup.stateFileName:
                    result[name] = Data("{}".utf8)
                default:
                    // A missing timer snapshot means there is no unfinished session.
                    break
                }
            }
        }
        return result
    }

    /// Decode app-owned payloads before a restore touches live files.
    static func validateBackupPayloads(in package: LocalBackup.Package) throws {
        for name in package.presentDataFiles {
            let url = package.directory.appendingPathComponent(name)
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw LocalBackup.BackupError.readFailed(name)
            }
            do {
                switch name {
                case LocalBackup.tasksFileName:
                    _ = try decodeList([FocusTask].self, from: data)
                case LocalBackup.sessionsFileName:
                    _ = try decodeList([FocusSession].self, from: data)
                case LocalBackup.stateFileName:
                    _ = try decodeList(PersistedState.self, from: data)
                case LocalBackup.timerSessionFileName:
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    _ = try decoder.decode(TimerSessionSnapshot.self, from: data)
                default:
                    break
                }
            } catch {
                throw LocalBackup.BackupError.invalidFile(name)
            }
        }
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

    /// Resilient array decoding that preserves existing items even if individual entries are damaged.
    private static func decodeResilientArray<T: Decodable>(_ itemType: T.Type, from data: Data) throws -> [T] {
        if let direct = try? decodeList([T].self, from: data) {
            return direct
        }
        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return try decodeList([T].self, from: data)
        }
        var salvaged: [T] = []
        for dict in jsonArray {
            guard let itemData = try? JSONSerialization.data(withJSONObject: dict) else { continue }
            if let item = try? decodeList(T.self, from: itemData) {
                salvaged.append(item)
            }
        }
        guard !salvaged.isEmpty || jsonArray.isEmpty else {
            return try decodeList([T].self, from: data)
        }
        return salvaged
    }
    
    private func scheduleSaveTasks() {
        guard !blockTasksPersistence else { return }
        saveTasksWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveTasks() }
        saveTasksWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    
    private func scheduleSaveSessions() {
        guard !blockSessionsPersistence else { return }
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
    
    /// User accepts empty state after corrupt load — re-enable writes for blocked files.
    func acknowledgeCorruptLoadAndStartFresh() {
        blockTasksPersistence = false
        blockSessionsPersistence = false
        dataLoadErrorMessage = nil
        saveTasksImmediately()
        saveSessionsImmediately()
        saveStateImmediately()
    }
    
    /// Re-read disk after user repairs files in Finder. Clears errors on success.
    @discardableResult
    func reloadFromDisk() -> Bool {
        isLoadingFromDisk = true
        var tasksOK = true
        var sessionsOK = true
        
        if FileManager.default.fileExists(atPath: tasksFileURL.path) {
            do {
                let data = try Data(contentsOf: tasksFileURL)
                tasks = try Self.decodeResilientArray(FocusTask.self, from: data)
                blockTasksPersistence = false
            } catch {
                tasksOK = false
                AppLog.tasks.error("reload tasks failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            tasks = []
            blockTasksPersistence = false
        }
        
        if FileManager.default.fileExists(atPath: sessionsFileURL.path) {
            do {
                let data = try Data(contentsOf: sessionsFileURL)
                focusSessions = try Self.decodeResilientArray(FocusSession.self, from: data)
                blockSessionsPersistence = false
            } catch {
                sessionsOK = false
                AppLog.tasks.error("reload sessions failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            focusSessions = []
            blockSessionsPersistence = false
        }
        
        loadState()
        isLoadingFromDisk = false
        
        if tasksOK && sessionsOK {
            dataLoadErrorMessage = nil
            return true
        }
        if !tasksOK && !sessionsOK {
            dataLoadErrorMessage = "任务与专注记录仍无法读取。请检查数据文件夹中的备份，或从空白开始。"
        } else if !tasksOK {
            dataLoadErrorMessage = "任务数据仍无法读取。专注记录可正常写入；请修复 tasks.json 或从空白开始。"
            blockTasksPersistence = true
        } else {
            dataLoadErrorMessage = "专注记录仍无法读取。任务可正常写入；请修复 focus_sessions.json 或从空白开始。"
            blockSessionsPersistence = true
        }
        return false
    }
    
    private func saveTasksImmediately() {
        guard !blockTasksPersistence else { return }
        saveTasksWorkItem?.cancel()
        saveTasks()
    }
    
    private func saveSessionsImmediately() {
        guard !blockSessionsPersistence else { return }
        saveSessionsWorkItem?.cancel()
        saveSessions()
    }
    
    private func saveStateImmediately() {
        saveStateWorkItem?.cancel()
        saveState()
    }
    
    private func saveTasks() {
        guard !blockTasksPersistence else { return }
        do {
            let data = try Self.makeEncoder().encode(tasks)
            try data.write(to: tasksFileURL, options: .atomic)
        } catch {
            AppLog.tasks.error("saveTasks failed: \(error.localizedDescription, privacy: .public)")
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
            self.tasks = try Self.decodeResilientArray(FocusTask.self, from: data)
        } catch {
            AppLog.tasks.error("loadTasks failed: \(error.localizedDescription, privacy: .public)")
            backupCorruptFile(at: fileURL)
            // Keep original file on disk — do not overwrite with empty until user confirms.
            blockTasksPersistence = true
            dataLoadErrorMessage = "任务数据文件损坏，已备份到同目录。未写入空数据。可打开数据文件夹、重新加载，或从空白开始。"
            self.tasks = []
        }
    }
    
    private func saveSessions() {
        guard !blockSessionsPersistence else { return }
        do {
            let data = try Self.makeEncoder().encode(focusSessions)
            try data.write(to: sessionsFileURL, options: .atomic)
        } catch {
            AppLog.tasks.error("saveSessions failed: \(error.localizedDescription, privacy: .public)")
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
            self.focusSessions = try Self.decodeResilientArray(FocusSession.self, from: data)
        } catch {
            AppLog.tasks.error("loadSessions failed: \(error.localizedDescription, privacy: .public)")
            backupCorruptFile(at: fileURL)
            blockSessionsPersistence = true
            if dataLoadErrorMessage == nil {
                dataLoadErrorMessage = "专注记录文件损坏，已备份。未覆盖原文件。可打开数据文件夹、重新加载，或从空白开始。"
            }
            self.focusSessions = []
        }
    }

    private func saveState() {
        do {
            let state = PersistedState(activeTaskId: activeTaskId)
            let data = try Self.makeEncoder().encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            AppLog.tasks.error("saveState failed: \(error.localizedDescription, privacy: .public)")
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
            AppLog.tasks.error("loadState failed: \(error.localizedDescription, privacy: .public)")
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
        createSafetySnapshotIfNeeded()
        isLoadingFromDisk = true
        loadTasks()
        loadSessions()
        loadState()
        isLoadingFromDisk = false
        // Roll incomplete recurring tasks whose due date is already past.
        rollForwardOverdueRecurringTasks()
    }

    /// Safeguard existing user data on app launch before reading or mutating.
    private func createSafetySnapshotIfNeeded() {
        let fm = FileManager.default
        let hasTasks = fm.fileExists(atPath: tasksFileURL.path)
        let hasSessions = fm.fileExists(atPath: sessionsFileURL.path)
        guard hasTasks || hasSessions else { return }

        let backupsDir = appSupportDir.appendingPathComponent("backups", isDirectory: true)
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateTag = formatter.string(from: Date())
        let snapshotDir = backupsDir.appendingPathComponent("auto_\(dateTag)", isDirectory: true)

        // Only snapshot once per day unless snapshotDir is missing
        if !fm.fileExists(atPath: snapshotDir.path) {
            try? fm.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
            let filesToBackup = [tasksFileURL, sessionsFileURL, stateFileURL]
            for file in filesToBackup where fm.fileExists(atPath: file.path) {
                let dest = snapshotDir.appendingPathComponent(file.lastPathComponent)
                try? fm.copyItem(at: file, to: dest)
            }
        }

        // Retain only the latest 5 snapshots to avoid unlimited disk growth
        if let contents = try? fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) {
            let autoBackups = contents.filter { $0.lastPathComponent.hasPrefix("auto_") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if autoBackups.count > 5 {
                for old in autoBackups.prefix(autoBackups.count - 5) {
                    try? fm.removeItem(at: old)
                }
            }
        }
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
        recurrence: TaskRecurrence = .none,
        notes: String = "",
        linkURL: String = ""
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
            tasks[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            tasks[index].linkURL = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            // Normalize to start-of-day so list filters stay consistent.
            if let dueDate {
                tasks[index].dueDate = Calendar.current.startOfDay(for: dueDate)
            } else {
                tasks[index].dueDate = nil
            }
            saveTasksImmediately()
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
        saveTasksImmediately()
        saveStateImmediately()
    }
    
    func setDueDate(ids: Set<UUID>, to date: Date?) {
        let normalized = date.map { Calendar.current.startOfDay(for: $0) }
        for id in ids {
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].dueDate = normalized
            }
        }
        saveTasksImmediately()
    }
    
    func moveToInbox(ids: Set<UUID>) {
        setDueDate(ids: ids, to: nil)
    }
    
    func deleteTasks(ids: Set<UUID>) {
        let removed = tasks.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        // Accumulate soft-deletes so rapid multi-delete can still undo all.
        pendingDeletedTasks.append(contentsOf: removed)
        if let active = activeTaskId, ids.contains(active) {
            pendingDeletedActiveTaskId = active
            activeTaskId = nil
        }
        tasks.removeAll { ids.contains($0.id) }
        saveTasksImmediately()
        saveStateImmediately()
        presentUndoDeletionBanner(count: pendingDeletedTasks.count)
    }
    
    func deleteTask(_ task: FocusTask) {
        deleteTasks(ids: [task.id])
    }
    
    /// Restore soft-deleted tasks (if still within the undo window).
    @discardableResult
    func undoLastDeletion() -> Bool {
        guard !pendingDeletedTasks.isEmpty else { return false }
        let restore = pendingDeletedTasks
        let priorActive = pendingDeletedActiveTaskId
        pendingDeletedTasks = []
        pendingDeletedActiveTaskId = nil
        undoDeletionWorkItem?.cancel()
        undoDeletionWorkItem = nil
        undoDeletionBanner = nil
        
        let existing = Set(tasks.map(\.id))
        let toInsert = restore.filter { !existing.contains($0.id) }
        tasks.append(contentsOf: toInsert)
        // Only restore active id when delete had cleared it.
        if let priorActive, tasks.contains(where: { $0.id == priorActive }) {
            activeTaskId = priorActive
        }
        saveTasksImmediately()
        saveStateImmediately()
        return !toInsert.isEmpty
    }
    
    func dismissUndoDeletionBanner() {
        // Expire undo window without restoring.
        pendingDeletedTasks = []
        pendingDeletedActiveTaskId = nil
        undoDeletionWorkItem?.cancel()
        undoDeletionWorkItem = nil
        undoDeletionBanner = nil
    }
    
    private func presentUndoDeletionBanner(count: Int) {
        let token = UUID()
        let message = count == 1 ? "已删除 1 项任务" : "已删除 \(count) 项任务"
        undoDeletionBanner = UndoDeletionBanner(token: token, message: message)
        undoDeletionWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Only clear if this is still the same banner generation.
            if self.undoDeletionBanner?.token == token {
                self.pendingDeletedTasks = []
                self.pendingDeletedActiveTaskId = nil
                self.undoDeletionBanner = nil
            }
        }
        undoDeletionWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5, execute: work)
    }
    
    func togglePin(for task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isPinned.toggle()
        if tasks[index].isPinned {
            // New pins float to the top of the pinned group.
            let minPinned = tasks.filter(\.isPinned).map(\.sortIndex).min() ?? 0
            tasks[index].sortIndex = minPinned - 1
        }
        saveTasksImmediately()
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
        saveTasksImmediately()
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
