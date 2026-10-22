import XCTest
@testable import iFocus
import iFocusCore

final class TaskStoreTests: XCTestCase {
    private var tempDir: URL!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-TaskStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }
    
    // MARK: - CRUD
    
    func testAddTaskForToday() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "  写单元测试  "
        store.newTaskCategory = .study
        store.newTaskPriority = 3
        store.newTaskPomodoros = 2
        store.addTask(for: .todayTask)
        
        XCTAssertEqual(store.tasks.count, 1)
        let task = store.tasks[0]
        XCTAssertEqual(task.title, "写单元测试")
        XCTAssertEqual(task.category, .study)
        XCTAssertEqual(task.priority, 3)
        XCTAssertEqual(task.estimatedPomodoros, 2)
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(store.newTaskTitle, "")
        XCTAssertNotNil(task.dueDate)
        XCTAssertTrue(Calendar.current.isDateInToday(task.dueDate!))
    }
    
    func testAddTaskIgnoresBlankTitle() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "   "
        store.addTask(for: .todayTask)
        XCTAssertTrue(store.tasks.isEmpty)
    }
    
    func testAddTaskDueOverrideAndRecurrence() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "覆盖到明天"
        store.newTaskRecurrence = .daily
        let id = store.addTask(for: .inboxTask, dueOverride: .tomorrow)
        XCTAssertNotNil(id)
        let task = store.tasks[0]
        XCTAssertNotNil(task.dueDate)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(task.dueDate!))
        XCTAssertEqual(task.recurrence, .daily)
        // Composer recurrence resets after add.
        XCTAssertEqual(store.newTaskRecurrence, .none)
    }
    
    func testMoveTaskBetweenListsUpdatesDueDate() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "搬家"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        XCTAssertNil(store.tasks[0].dueDate)

        store.moveTask(id: id, to: .todayTask)
        XCTAssertTrue(Calendar.current.isDateInToday(store.tasks[0].dueDate!))
        XCTAssertNil(store.tasks[0].startDate)

        store.moveTask(id: id, to: .tomorrowTask)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(store.tasks[0].dueDate!))

        store.moveTask(id: id, to: .inboxTask)
        XCTAssertNil(store.tasks[0].dueDate)

        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertNil(reloaded.tasks[0].dueDate)
    }

    func testMoveTaskToCompletedAndBackReopens() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "收尾"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id

        store.moveTask(id: id, to: .completedTask)
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNotNil(store.tasks[0].completedAt)

        store.moveTask(id: id, to: .todayTask)
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
        XCTAssertTrue(Calendar.current.isDateInToday(store.tasks[0].dueDate!))
    }

    func testAddOnboardingSampleTaskIsDueToday() {
        let store = TaskStore(storageDirectory: tempDir)
        store.addOnboardingSampleTask()

        XCTAssertEqual(store.tasks.count, 1)
        let task = store.tasks[0]
        XCTAssertEqual(task.title, "读完一节书")
        XCTAssertEqual(task.category, .study)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNotNil(task.dueDate)
        XCTAssertTrue(Calendar.current.isDateInToday(task.dueDate!))
    }

    func testDeleteTasksCanUndo() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "可撤销"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id
        store.activeTaskId = id
        
        store.deleteTask(store.tasks[0])
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNil(store.activeTaskId)
        XCTAssertNotNil(store.undoDeletionBanner)
        
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].id, id)
        XCTAssertEqual(store.activeTaskId, id)
        XCTAssertNil(store.undoDeletionBanner)
    }
    
    func testUpdateTask() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "旧标题"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        
        store.updateTask(
            id: id,
            title: "新标题",
            category: .work,
            priority: 4,
            estimatedPomodoros: 5,
            dueDate: Calendar.current.startOfDay(for: Date()),
            notes: "  备忘  ",
            linkURL: " https://example.com/doc "
        )
        
        let task = store.tasks[0]
        XCTAssertEqual(task.title, "新标题")
        XCTAssertEqual(task.category, .work)
        XCTAssertEqual(task.priority, 4)
        XCTAssertEqual(task.estimatedPomodoros, 5)
        XCTAssertNotNil(task.dueDate)
        XCTAssertEqual(task.notes, "备忘")
        XCTAssertEqual(task.linkURL, "https://example.com/doc")
        XCTAssertTrue(task.hasLink)
    }
    
    func testHasLinkRejectsInvalidSchemes() {
        var task = FocusTask(title: "x", category: .work, linkURL: "ftp://example.com")
        XCTAssertFalse(task.hasLink)
        task.linkURL = "not a url"
        XCTAssertFalse(task.hasLink)
        task.linkURL = "https://ok.dev"
        XCTAssertTrue(task.hasLink)
    }
    
    func testUpdateTaskKeepsTitleWhenBlank() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "保留"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        
        store.updateTask(
            id: id,
            title: "   ",
            category: .other,
            priority: 1,
            estimatedPomodoros: 1,
            dueDate: nil
        )
        XCTAssertEqual(store.tasks[0].title, "保留")
    }
    
    func testRapidDoubleDeleteUndoRestoresBoth() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "A"
        store.addTask(for: .inboxTask)
        store.newTaskTitle = "B"
        store.addTask(for: .inboxTask)
        store.deleteTask(store.tasks[0])
        store.deleteTask(store.tasks[0])
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 2)
    }
    
    func testCorruptLoadDoesNotOverwriteFile() throws {
        let url = tempDir.appendingPathComponent("tasks.json")
        try "NOT_JSON".write(to: url, atomically: true, encoding: .utf8)
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertNotNil(store.dataLoadErrorMessage)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "NOT_JSON")
        store.acknowledgeCorruptLoadAndStartFresh()
        XCTAssertNil(store.dataLoadErrorMessage)
    }
    
    func testDeleteTaskByValue() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "A"
        store.addTask(for: .inboxTask)
        store.newTaskTitle = "B"
        store.addTask(for: .inboxTask)
        let toDelete = store.tasks[0]
        
        store.deleteTask(toDelete)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "B")
    }
    
    func testToggleCompletion() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "完成我"
        store.addTask(for: .inboxTask)
        let task = store.tasks[0]
        
        store.toggleCompletion(for: task)
        XCTAssertTrue(store.tasks[0].isCompleted)
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertFalse(store.tasks[0].isCompleted)
    }
    
    // MARK: - Active task
    
    func testDeleteActiveTaskClearsActiveId() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "专注中"
        store.addTask(for: .inboxTask)
        let task = store.tasks[0]
        store.activeTaskId = task.id
        XCTAssertNotNil(store.activeTask)
        
        store.deleteTask(task)
        XCTAssertNil(store.activeTaskId)
        XCTAssertNil(store.activeTask)
    }
    
    func testToggleCompleteActiveTaskClearsActiveId() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "做完清空"
        store.addTask(for: .inboxTask)
        let task = store.tasks[0]
        store.activeTaskId = task.id
        
        store.toggleCompletion(for: task)
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNil(store.activeTaskId)
    }
    
    // MARK: - Persistence
    
    func testSaveAndLoadTasks() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "持久化任务"
        store.newTaskCategory = .work
        store.addTask(for: .todayTask)
        store.flushPendingSaves()
        
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.tasks[0].title, "持久化任务")
        XCTAssertEqual(reloaded.tasks[0].category, .work)
    }

    func testSaveAndLoadActiveTask() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "上次专注任务"
        store.addTask(for: .inboxTask)
        let taskId = store.tasks[0].id
        store.activeTaskId = taskId
        store.flushPendingSaves()

        let reloaded = TaskStore(storageDirectory: tempDir)

        XCTAssertEqual(reloaded.activeTaskId, taskId)
        XCTAssertEqual(reloaded.activeTask?.title, "上次专注任务")
    }

    func testReloadIgnoresCompletedActiveTask() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "已完成任务"
        store.addTask(for: .inboxTask)
        let task = store.tasks[0]
        store.activeTaskId = task.id
        store.toggleCompletion(for: task)
        store.flushPendingSaves()

        let reloaded = TaskStore(storageDirectory: tempDir)

        XCTAssertNil(reloaded.activeTaskId)
    }
    
    func testSaveAndLoadSessions() {
        let store = TaskStore(storageDirectory: tempDir)
        store.logFocusSession(taskId: nil, taskTitle: "自由专注", taskCategory: .study, minutes: 25)
        store.flushPendingSaves()
        
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.focusSessions.count, 1)
        XCTAssertEqual(reloaded.focusSessions[0].taskTitle, "自由专注")
        XCTAssertEqual(reloaded.focusSessions[0].taskCategory, .study)
        XCTAssertEqual(reloaded.focusSessions[0].durationMinutes, 25)
    }
    
    /// Completing a pomodoro must hit disk immediately (no 0.35s debounce window).
    func testLogFocusSessionPersistsImmediatelyWithoutFlush() {
        let store = TaskStore(storageDirectory: tempDir)
        store.logFocusSession(taskId: nil, taskTitle: "即时落盘", minutes: 25)
        
        // Do not call flushPendingSaves — reload should already see the session.
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.focusSessions.count, 1)
        XCTAssertEqual(reloaded.focusSessions[0].taskTitle, "即时落盘")
    }
    
    func testAddFocusTimePersistsImmediatelyWithoutFlush() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "番茄任务"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        store.flushPendingSaves() // baseline task on disk
        
        store.addFocusTime(to: id, minutes: 25)
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.tasks[0].completedPomodoros, 1)
        XCTAssertEqual(reloaded.tasks[0].timeSpentMinutes, 25)
    }

    func testBackupPayloadsThrowInsteadOfReplacingUnreadableTasksWithEmptyArray() throws {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "必须保住的任务"
        store.addTask(for: .inboxTask)
        store.flushPendingSaves()

        let tasksURL = tempDir.appendingPathComponent("tasks.json")
        try FileManager.default.removeItem(at: tasksURL)
        try FileManager.default.createDirectory(at: tasksURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try store.backupFilePayloads()) { error in
            XCTAssertEqual(error as? LocalBackup.BackupError, .readFailed(LocalBackup.tasksFileName))
        }
    }
    
    func testRecurrenceSpawnsNextOnComplete() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "每日复盘"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id
        store.updateTask(
            id: id,
            title: "每日复盘",
            category: .study,
            priority: 2,
            estimatedPomodoros: 1,
            dueDate: Calendar.current.startOfDay(for: Date()),
            recurrence: .daily
        )
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertTrue(store.tasks.contains { $0.isCompleted && $0.title == "每日复盘" })
        let next = store.tasks.first { !$0.isCompleted && $0.title == "每日复盘" }
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.recurrence, .daily)
        if let due = next?.dueDate {
            XCTAssertTrue(due > Calendar.current.startOfDay(for: Date()) || Calendar.current.isDateInTomorrow(due))
        }
    }
    
    func testBatchCompleteAndInbox() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "X"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Y"
        store.addTask(for: .todayTask)
        let ids = Set(store.tasks.map(\.id))
        store.completeTasks(ids: ids)
        XCTAssertTrue(store.tasks.allSatisfy(\.isCompleted))
        
        store.tasks[0].isCompleted = false
        store.tasks[1].isCompleted = false
        store.moveToInbox(ids: ids)
        XCTAssertTrue(store.tasks.allSatisfy { $0.dueDate == nil })
    }
    
    func testPinAndReorderWithinFilter() {
        let store = TaskStore(storageDirectory: tempDir)
        store.newTaskTitle = "A"
        store.addTask(for: .inboxTask)
        store.newTaskTitle = "B"
        store.addTask(for: .inboxTask)
        store.newTaskTitle = "C"
        store.addTask(for: .inboxTask)
        
        let b = store.tasks.first { $0.title == "B" }!
        store.togglePin(for: b)
        XCTAssertEqual(store.tasks(for: .inboxTask).map(\.title).first, "B")
        
        // Unpin then drag first item to end of the list.
        store.togglePin(for: store.tasks.first { $0.title == "B" }!)
        let list = store.tasks(for: .inboxTask)
        store.reorderVisible(list, from: IndexSet(integer: 0), to: list.count, filter: .inboxTask)
        let after = store.tasks(for: .inboxTask).map(\.title)
        XCTAssertEqual(after.last, list[0].title)
    }
    
    func testStudyLogMirrorsSessionsAsCSVAndWeeklyReport() throws {
        let logDir = tempDir.appendingPathComponent("StudyLog", isDirectory: true)
        let store = TaskStore(storageDirectory: tempDir, studyLogDirectory: logDir)
        store.logFocusSession(taskId: nil, taskTitle: "3b1b 线性代数", taskCategory: .study, minutes: 25)
        store.flushPendingSaves()

        let csv = try String(contentsOf: logDir.appendingPathComponent("sessions.csv"), encoding: .utf8)
        XCTAssertTrue(csv.hasPrefix("日期,开始,结束,分钟,分类,任务\n"))
        XCTAssertTrue(csv.contains(",25,学习,3b1b 线性代数"))

        let calendar = StudyLogExport.weekCalendar()
        let week = StudyLogExport.weekStart(for: Date(), calendar: calendar)
        let c = calendar.dateComponents([.year, .month, .day], from: week)
        let name = String(format: "%04d-%02d-%02d.md", c.year!, c.month!, c.day!)
        let report = try String(contentsOf: logDir.appendingPathComponent("weeks/\(name)"), encoding: .utf8)
        XCTAssertTrue(report.contains("- 学习分类：25分钟"))
    }

    func testStudyLogIsOffByDefault() {
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertNil(store.studyLogDirectory)
    }

    func testLoadsLegacySessionsWithoutCategory() throws {
        let legacyJSON = """
        [
          {
            "durationMinutes" : 25,
            "id" : "11111111-1111-1111-1111-111111111111",
            "taskId" : null,
            "taskTitle" : "旧自由专注",
            "timestamp" : "2026-03-10T12:00:00Z"
          }
        ]
        """
        try Data(legacyJSON.utf8).write(to: tempDir.appendingPathComponent("focus_sessions.json"))
        
        let store = TaskStore(storageDirectory: tempDir)
        
        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertEqual(store.focusSessions[0].taskTitle, "旧自由专注")
        XCTAssertNil(store.focusSessions[0].taskCategory)
    }
    
    func testCorruptTasksJSONBacksUpAndStartsEmpty() throws {
        let tasksURL = tempDir.appendingPathComponent("tasks.json")
        try Data("{not-json".utf8).write(to: tasksURL)
        
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertTrue(store.tasks.isEmpty)
        
        let backups = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("corrupt-") && $0.pathExtension == "json" }
        XCTAssertFalse(backups.isEmpty, "corrupt tasks.json should be copied to a backup")
    }
    
    func testCorruptSessionsJSONBacksUpAndStartsEmpty() throws {
        let sessionsURL = tempDir.appendingPathComponent("focus_sessions.json")
        try Data("[[[broken".utf8).write(to: sessionsURL)
        
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertTrue(store.focusSessions.isEmpty)
        
        let backups = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("corrupt-") && $0.pathExtension == "json" }
        XCTAssertFalse(backups.isEmpty, "corrupt focus_sessions.json should be copied to a backup")
    }

    func testSafetySnapshotCreatesDailyBackup() throws {
        let tasksURL = tempDir.appendingPathComponent("tasks.json")
        try Data("[]".utf8).write(to: tasksURL)

        _ = TaskStore(storageDirectory: tempDir)

        let backupsDir = tempDir.appendingPathComponent("backups", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupsDir.path))
        let items = try FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)
        let autoBackups = items.filter { $0.lastPathComponent.hasPrefix("auto_") }
        XCTAssertEqual(autoBackups.count, 1)
        let copiedTasks = autoBackups[0].appendingPathComponent("tasks.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedTasks.path))
    }

    func testResilientArrayDecodingSalvagesGoodItems() throws {
        let mixedSessionsJSON = """
        [
          {
            "id": "AEE6D75B-1C7F-4C79-A1FD-8F501D6439D8",
            "taskTitle": "有效番茄",
            "durationMinutes": 25,
            "timestamp": "2026-07-10T05:21:37Z"
          },
          {
            "invalid_field": true
          }
        ]
        """
        let sessionsURL = tempDir.appendingPathComponent("focus_sessions.json")
        try Data(mixedSessionsJSON.utf8).write(to: sessionsURL)

        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertEqual(store.focusSessions[0].taskTitle, "有效番茄")
    }
}
