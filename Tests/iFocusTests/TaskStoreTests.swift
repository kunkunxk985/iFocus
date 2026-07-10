import XCTest
@testable import iFocus

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
            dueDate: Calendar.current.startOfDay(for: Date())
        )
        
        let task = store.tasks[0]
        XCTAssertEqual(task.title, "新标题")
        XCTAssertEqual(task.category, .work)
        XCTAssertEqual(task.priority, 4)
        XCTAssertEqual(task.estimatedPomodoros, 5)
        XCTAssertNotNil(task.dueDate)
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
}
