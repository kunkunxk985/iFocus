import Foundation
import Combine
import iFocusCore

class TaskStore: ObservableObject {
    private struct PersistedState: Codable {
        var activeTaskId: UUID?
        var customCategories: [TaskCategory]? = nil
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
    /// Tasks or sessions that could not be read (and were left out) since launch.
    private(set) var skippedItemsOnLoad = 0
    /// One-time notice after an upgrade launch that skipped unreadable items.
    @Published var upgradeNotice: String?
    
    /// User-defined categories. Built-ins are fixed and stay in `TaskCategory.builtIn`.
    /// Definitions live in app_state.json, so existing backups carry them unchanged.
    @Published private(set) var customCategories: [TaskCategory] = [] {
        didSet {
            guard !isLoadingFromDisk else { return }
            scheduleSaveState()
        }
    }

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

    struct StudyPlanImportResult: Equatable {
        let addedCount: Int
        let skippedCount: Int
        let totalCount: Int
    }

    private struct StudyPlanTaskEdits {
        let items: [ChecklistItem]?
        let itemUnit: String?
        let startDate: Date?
    }
    
    struct UndoDeletionBanner: Equatable {
        let token: UUID
        let message: String
    }
    
    /// Override due date when quick-adding (nil = follow list filter defaults).
    enum DueOverride: Equatable {
        case today
        case tomorrow
        case later
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
    
    /// Built-ins followed by user-defined categories, including any category that
    /// only survives inside existing tasks or history (recovery-safe display order).
    var allCategories: [TaskCategory] {
        TaskCategory.builtIn + customCategories
    }

    var categoriesInUse: [TaskCategory] {
        var result = allCategories
        var seenIDs = Set(result.map(\.id))
        for task in tasks where seenIDs.insert(task.category.id).inserted {
            result.append(task.category)
        }
        for session in focusSessions {
            guard let category = session.taskCategory,
                  seenIDs.insert(category.id).inserted else { continue }
            result.append(category)
        }
        return result
    }

    var tasksByCategory: [(category: TaskCategory, tasks: [FocusTask])] {
        let grouped = Dictionary(grouping: incompleteTasks) { $0.category }
        return allCategories.compactMap { cat in
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
            case .later: dueDate = dayAfterTomorrow
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
        // Study is the default every time, not the last category used.
        newTaskCategory = .study
        saveTasksImmediately()
        return task.id
    }

    /// First-run helper: adds one editable task without going through the quick-add fields.
    func addOnboardingSampleTask(title: String = "读完一节书") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        let task = FocusTask(
            title: trimmed,
            category: .study,
            priority: 1,
            estimatedPomodoros: 1,
            dueDate: Calendar.current.startOfDay(for: Date()),
            sortIndex: nextIndex
        )
        tasks.append(task)
        saveTasksImmediately()
    }

    /// Import the built-in route once per stable plan key; never overwrite user progress.
    @discardableResult
    func importAcceleratedStudyPlan(
        startMonday: Date,
        calendar: Calendar = .current
    ) -> StudyPlanImportResult {
        let drafts = PlanTemplates.accelerated4Weeks(startMonday: startMonday, calendar: calendar)
        var existingKeys = Set(tasks.compactMap(\.planKey))
        var nextIndex = (tasks.map(\.sortIndex).max() ?? -1) + 1
        var added = 0

        for draft in drafts {
            guard !draft.planKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  existingKeys.insert(draft.planKey).inserted else {
                continue
            }
            let checklist = draft.items.map { ChecklistItem(title: $0) }
            tasks.append(FocusTask(
                title: draft.title,
                category: .study,
                priority: 2,
                estimatedPomodoros: 1,
                dueDate: draft.dueDate,
                sortIndex: nextIndex,
                recurrence: draft.repeatsDaily ? .daily : .none,
                notes: draft.notes,
                items: checklist.isEmpty ? nil : checklist,
                itemUnit: draft.unit,
                startDate: draft.startDate,
                planKey: draft.planKey
            ))
            nextIndex += 1
            added += 1
        }

        if added > 0 { saveTasksImmediately() }
        return StudyPlanImportResult(
            addedCount: added,
            skippedCount: drafts.count - added,
            totalCount: drafts.count
        )
    }
    
    func toggleCompletion(for task: FocusTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let wasCompleted = tasks[index].isCompleted
            tasks[index].isCompleted.toggle()
            tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
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

    /// Toggle a checklist item and complete its parent task once every item is checked.
    func toggleChecklistItem(taskID: UUID, itemID: UUID, at date: Date = Date()) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        var items = tasks[index].checklist
        guard let itemIndex = items.firstIndex(where: { $0.id == itemID }) else { return }

        items[itemIndex].doneAt = items[itemIndex].isDone ? nil : date
        tasks[index].items = items.isEmpty ? nil : items
        synchronizeChecklistCompletion(forTaskAt: index, at: date)
        saveTasksImmediately()
        saveStateImmediately()
    }

    /// Keep parent completion, active-task state, and recurrence consistent with checklist edits.
    private func synchronizeChecklistCompletion(forTaskAt index: Int, at date: Date = Date()) {
        let items = tasks[index].checklist
        guard !items.isEmpty else { return }

        let allDone = items.allSatisfy(\.isDone)
        guard allDone != tasks[index].isCompleted else { return }

        let taskID = tasks[index].id
        tasks[index].isCompleted = allDone
        tasks[index].completedAt = allDone ? date : nil

        guard allDone else { return }
        if activeTaskId == taskID { activeTaskId = nil }
        if tasks[index].recurrence != .none {
            spawnNextRecurrence(from: tasks[index])
        }
    }

    func toggleChecklistFlag(taskID: UUID, itemID: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }),
              let itemIndex = tasks[taskIndex].checklist.firstIndex(where: { $0.id == itemID }) else { return }
        var items = tasks[taskIndex].checklist
        items[itemIndex].flagged = !items[itemIndex].isFlagged
        tasks[taskIndex].items = items
        saveTasksImmediately()
    }
    
    /// Create the next incomplete instance after completing a recurring task.
    private func spawnNextRecurrence(from completed: FocusTask) {
        guard completed.recurrence != .none else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let priorDue = completed.dueDate.map { calendar.startOfDay(for: $0) } ?? today
        let nextDue = FocusTask.nextDueDate(after: max(priorDue, today), recurrence: completed.recurrence, calendar: calendar)
        // Avoid duplicates when user un-completes and completes again.
        if let nextDue {
            let nextDay = calendar.startOfDay(for: nextDue)
            let alreadyOpen = tasks.contains { t in
                !t.isCompleted
                    && t.recurrence == completed.recurrence
                    && t.title == completed.title
                    && t.dueDate.map { calendar.isDate($0, inSameDayAs: nextDay) } == true
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
            linkURL: completed.linkURL,
            items: completed.items?.map { ChecklistItem(title: $0.title) },
            itemUnit: completed.itemUnit,
            planKey: completed.planKey
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
    /// Readable CSV / weekly Markdown mirror of `focusSessions`; nil disables it (tests).
    private let studyLog: StudyLogWriter?

    /// Folder holding the readable study log, if export is on.
    var studyLogDirectory: URL? { studyLog?.directory }
    
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

    /// Read raw file payloads for backup; missing files use valid defaults, unreadable files fail.
    func backupFilePayloads() throws -> [String: Data] {
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
            if fm.fileExists(atPath: url.path) {
                do {
                    result[name] = try Data(contentsOf: url)
                } catch {
                    throw LocalBackup.BackupError.readFailed(name)
                }
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
    /// `skipped` gains the number of entries that could not be read.
    private static func decodeResilientArray<T: Decodable>(
        _ itemType: T.Type,
        from data: Data,
        skipped: inout Int
    ) throws -> [T] {
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
        skipped += jsonArray.count - salvaged.count
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
        studyLog?.waitUntilIdle()
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
                tasks = try Self.decodeResilientArray(FocusTask.self, from: data, skipped: &skippedItemsOnLoad)
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
                focusSessions = try Self.decodeResilientArray(FocusSession.self, from: data, skipped: &skippedItemsOnLoad)
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
        reconcileCategoriesAfterLoad()
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
            self.tasks = try Self.decodeResilientArray(FocusTask.self, from: data, skipped: &skippedItemsOnLoad)
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
            studyLog?.export(focusSessions)
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
            self.focusSessions = try Self.decodeResilientArray(FocusSession.self, from: data, skipped: &skippedItemsOnLoad)
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
            let state = PersistedState(
                activeTaskId: activeTaskId,
                customCategories: customCategories.isEmpty ? nil : customCategories
            )
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
            customCategories = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try Self.decodeList(PersistedState.self, from: data)
            customCategories = Self.sanitizedCategories(state.customCategories ?? [])
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
            customCategories = []
        }
    }

    private static func sanitizedCategories(_ raw: [TaskCategory]) -> [TaskCategory] {
        var result: [TaskCategory] = []
        var ids = Set<String>()
        var names = Set<String>()
        for category in raw {
            let trimmed = category.name
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            guard !trimmed.isEmpty else { continue }
            guard !TaskCategory.builtIn.contains(where: { $0.id == category.id || $0.name == trimmed }) else {
                continue
            }
            let nameKey = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard ids.insert(category.id).inserted, names.insert(nameKey).inserted else { continue }
            result.append(TaskCategory(
                id: category.id,
                name: trimmed,
                colorHex: category.colorHex.isEmpty ? TaskCategory.fallbackColorHex : category.colorHex,
                icon: category.icon.isEmpty ? "tag.fill" : category.icon
            ))
        }
        return result
    }

    /// Applies the loaded catalog to existing tasks/history and recovers a custom
    /// definition that only survived inside old records.
    private func reconcileCategoriesAfterLoad() {
        var categories = allCategories
        var byID: [String: TaskCategory] = [:]
        var byName: [String: TaskCategory] = [:]
        for category in categories {
            if byID[category.id] == nil { byID[category.id] = category }
            if byName[category.name] == nil { byName[category.name] = category }
        }
        var recovered: [TaskCategory] = []

        func resolved(_ category: TaskCategory) -> TaskCategory {
            if let match = byID[category.id] ?? byName[category.name] {
                return match
            }
            guard !category.isBuiltIn else { return category }
            recovered.append(category)
            categories.append(category)
            byID[category.id] = category
            byName[category.name] = category
            return category
        }

        var tasksChanged = false
        for index in tasks.indices {
            let category = resolved(tasks[index].category)
            if tasks[index].category != category {
                tasks[index].category = category
                tasksChanged = true
            }
        }

        var sessionsChanged = false
        for index in focusSessions.indices {
            guard let stored = focusSessions[index].taskCategory else { continue }
            let category = resolved(stored)
            if focusSessions[index].taskCategory != category {
                focusSessions[index].taskCategory = category
                sessionsChanged = true
            }
        }

        if !recovered.isEmpty {
            customCategories.append(contentsOf: recovered)
            saveStateImmediately()
        }
        if tasksChanged { saveTasksImmediately() }
        if sessionsChanged { saveSessionsImmediately() }
    }
    
    /// - Parameters:
    ///   - storageDirectory: Override for tests. `nil` uses Application Support.
    ///   - studyLogDirectory: Where to mirror sessions as CSV / weekly Markdown. `nil` turns it off.
    init(storageDirectory: URL? = nil, studyLogDirectory: URL? = nil) {
        if let storageDirectory {
            try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            self.appSupportDir = storageDirectory
        } else {
            self.appSupportDir = Self.defaultStorageDirectory()
        }
        self.studyLog = studyLogDirectory.map { StudyLogWriter(directory: $0) }
        createSafetySnapshotIfNeeded()
        isLoadingFromDisk = true
        loadTasks()
        loadSessions()
        loadState()
        reconcileCategoriesAfterLoad()
        isLoadingFromDisk = false
        // Roll incomplete recurring tasks whose due date is already past.
        rollForwardOverdueRecurringTasks()
        // Refresh the readable log on launch so this week's report exists before the first session.
        if !blockSessionsPersistence {
            studyLog?.export(focusSessions)
        }
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

    // MARK: - Custom categories

    func category(withID id: String) -> TaskCategory? {
        allCategories.first { $0.id == id }
    }

    func category(named raw: String) -> TaskCategory? {
        allCategories.first { $0.name == raw || $0.id == raw }
            ?? TaskCategory.resolveBuiltIn(raw)
    }

    @discardableResult
    func addCustomCategory(
        name: String,
        colorHex: String,
        icon: String
    ) -> Result<TaskCategory, CategoryValidationError> {
        do {
            let trimmed = try normalizedCategoryName(name)
            guard customCategories.count < TaskCategory.maxCustomCount else {
                return .failure(.limitReached)
            }
            let category = TaskCategory(
                id: "custom-\(UUID().uuidString)",
                name: trimmed,
                colorHex: normalizedColorHex(colorHex),
                icon: normalizedIcon(icon)
            )
            customCategories.append(category)
            saveStateImmediately()
            return .success(category)
        } catch let error as CategoryValidationError {
            return .failure(error)
        } catch {
            return .failure(.emptyName)
        }
    }

    @discardableResult
    func updateCustomCategory(
        id: String,
        name: String,
        colorHex: String,
        icon: String
    ) -> Result<TaskCategory, CategoryValidationError> {
        guard let index = customCategories.firstIndex(where: { $0.id == id }) else {
            return .failure(.notFound)
        }
        do {
            let trimmed = try normalizedCategoryName(name, excluding: id)
            let updated = TaskCategory(
                id: id,
                name: trimmed,
                colorHex: normalizedColorHex(colorHex),
                icon: normalizedIcon(icon)
            )
            customCategories[index] = updated
            applyCategoryDefinition(updated)
            return .success(updated)
        } catch let error as CategoryValidationError {
            return .failure(error)
        } catch {
            return .failure(.emptyName)
        }
    }

    /// Deletes a custom category and moves its tasks and history to 其他.
    @discardableResult
    func deleteCustomCategory(id: String) -> Bool {
        guard customCategories.contains(where: { $0.id == id }) else { return false }
        customCategories.removeAll { $0.id == id }

        let fallback = TaskCategory.other
        var tasksChanged = false
        for index in tasks.indices where tasks[index].category.id == id {
            tasks[index].category = fallback
            tasksChanged = true
        }
        if tasksChanged { saveTasksImmediately() }

        var sessionsChanged = false
        for index in focusSessions.indices where focusSessions[index].taskCategory?.id == id {
            focusSessions[index].taskCategory = fallback
            sessionsChanged = true
        }
        if sessionsChanged { saveSessionsImmediately() }

        if newTaskCategory.id == id { newTaskCategory = .study }
        saveStateImmediately()
        return true
    }

    private func applyCategoryDefinition(_ category: TaskCategory) {
        var tasksChanged = false
        for index in tasks.indices where tasks[index].category.id == category.id {
            tasks[index].category = category
            tasksChanged = true
        }
        if tasksChanged { saveTasksImmediately() }

        var sessionsChanged = false
        for index in focusSessions.indices where focusSessions[index].taskCategory?.id == category.id {
            focusSessions[index].taskCategory = category
            sessionsChanged = true
        }
        if sessionsChanged { saveSessionsImmediately() }

        if newTaskCategory.id == category.id { newTaskCategory = category }
        saveStateImmediately()
    }

    private func normalizedCategoryName(
        _ raw: String,
        excluding id: String? = nil
    ) throws -> String {
        let trimmed = raw
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !trimmed.isEmpty else { throw CategoryValidationError.emptyName }
        guard trimmed.count <= TaskCategory.maxNameLength else {
            throw CategoryValidationError.nameTooLong
        }
        let isDuplicate: (TaskCategory) -> Bool = { category in
            guard category.id != id else { return false }
            return category.name.compare(
                trimmed,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
        if TaskCategory.builtIn.contains(where: isDuplicate)
            || customCategories.contains(where: isDuplicate) {
            throw CategoryValidationError.duplicateName
        }
        return trimmed
    }

    private func normalizedColorHex(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TaskCategory.fallbackColorHex : trimmed
    }

    private func normalizedIcon(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "tag.fill" : trimmed
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
        updateTask(
            id: id,
            title: title,
            category: category,
            priority: priority,
            estimatedPomodoros: estimatedPomodoros,
            dueDate: dueDate,
            recurrence: recurrence,
            notes: notes,
            linkURL: linkURL,
            studyPlanEdits: nil
        )
    }

    func updateTask(
        id: UUID,
        title: String,
        category: TaskCategory,
        priority: Int,
        estimatedPomodoros: Int,
        dueDate: Date?,
        recurrence: TaskRecurrence,
        notes: String,
        linkURL: String,
        items: [ChecklistItem]?,
        itemUnit: String?,
        startDate: Date?
    ) {
        updateTask(
            id: id,
            title: title,
            category: category,
            priority: priority,
            estimatedPomodoros: estimatedPomodoros,
            dueDate: dueDate,
            recurrence: recurrence,
            notes: notes,
            linkURL: linkURL,
            studyPlanEdits: StudyPlanTaskEdits(items: items, itemUnit: itemUnit, startDate: startDate)
        )
    }

    private func updateTask(
        id: UUID,
        title: String,
        category: TaskCategory,
        priority: Int,
        estimatedPomodoros: Int,
        dueDate: Date?,
        recurrence: TaskRecurrence,
        notes: String,
        linkURL: String,
        studyPlanEdits: StudyPlanTaskEdits?
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
            if let studyPlanEdits {
                if let items = studyPlanEdits.items, !items.isEmpty {
                    tasks[index].items = items
                    let unit = studyPlanEdits.itemUnit?.trimmingCharacters(in: .whitespacesAndNewlines)
                    tasks[index].itemUnit = unit?.isEmpty == false ? unit : nil
                } else {
                    tasks[index].items = nil
                    tasks[index].itemUnit = nil
                }
                tasks[index].startDate = studyPlanEdits.startDate.map { Calendar.current.startOfDay(for: $0) }
                synchronizeChecklistCompletion(forTaskAt: index)
            }
            saveTasksImmediately()
            saveStateImmediately()
        }
    }
    
    // MARK: - Batch operations
    
    func completeTasks(ids: Set<UUID>) {
        for id in ids {
            guard let index = tasks.firstIndex(where: { $0.id == id }), !tasks[index].isCompleted else { continue }
            tasks[index].isCompleted = true
            tasks[index].completedAt = Date()
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

    /// Cross-list move used by quick actions and sidebar drops. Plan tasks carry a
    /// start date in addition to a due date, so clear it when they leave their plan slot.
    func moveTask(id: UUID, to filter: TaskFilter) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch filter {
        case .todayTask:
            tasks[index].dueDate = today
        case .tomorrowTask:
            tasks[index].dueDate = calendar.date(byAdding: .day, value: 1, to: today)
        case .weekTask:
            // 稍后 is the day-after-tomorrow list, same date as adding with the 稍后 chip.
            tasks[index].dueDate = calendar.date(byAdding: .day, value: 2, to: today)
        case .inboxTask:
            tasks[index].dueDate = nil
        case .completedTask:
            let task = tasks[index]
            if !task.isCompleted { toggleCompletion(for: task) }
            return
        default:
            return
        }
        tasks[index].startDate = nil
        // Dragging a completed task back into an active list is an explicit reopen.
        tasks[index].isCompleted = false
        tasks[index].completedAt = nil
        saveTasksImmediately()
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
    
    @discardableResult
    func logFocusSession(
        taskId: UUID?,
        taskTitle: String,
        taskCategory: TaskCategory? = nil,
        minutes: Int,
        endedAt: Date = Date()
    ) -> FocusSession? {
        guard minutes >= 1 else { return nil }
        let session = FocusSession(
            taskId: taskId,
            taskTitle: taskTitle,
            taskCategory: taskCategory,
            durationMinutes: minutes,
            timestamp: endedAt
        )
        focusSessions.append(session)
        // Completing a pomodoro must survive force-quit — write sessions immediately.
        saveSessionsWorkItem?.cancel()
        saveSessions()
        return session
    }
}
