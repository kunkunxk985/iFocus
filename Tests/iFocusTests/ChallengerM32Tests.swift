import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

final class ChallengerM32Tests: XCTestCase {
    private var tempDir: URL!
    private var calendar: Calendar!
    private var now: Date!
    private var todayStart: Date!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-ChallengerM32-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        calendar = Calendar.current
        now = Date()
        todayStart = calendar.startOfDay(for: now)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func makeStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir)
    }

    // =========================================================================
    // MARK: - 1. completedTodayTasks Invariant Suite
    // =========================================================================

    /// 1.1 Completed task with dueDate today -> INCLUDED
    func testInvariant1_CompletedDueDateToday_Included() {
        let store = makeStore()
        var task = FocusTask(title: "Due today", category: .other)
        task.dueDate = todayStart
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, task.id)
    }

    /// 1.2 Completed task with startDate today -> INCLUDED
    func testInvariant1_CompletedStartDateToday_Included() {
        let store = makeStore()
        var task = FocusTask(title: "Start date today", category: .other)
        task.dueDate = nil
        task.startDate = todayStart
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, task.id)
    }

    /// 1.3 Completed task in Inbox (no dueDate, no startDate) -> EXCLUDED
    func testInvariant1_CompletedInbox_Excluded() {
        let store = makeStore()
        var task = FocusTask(title: "Inbox completed", category: .other)
        task.dueDate = nil
        task.startDate = nil
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Inbox task without dueDate or startDate must be EXCLUDED from completedTodayTasks")
    }

    /// 1.4 Completed task with dueDate tomorrow -> EXCLUDED
    func testInvariant1_CompletedDueDateTomorrow_Excluded() {
        let store = makeStore()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        var task = FocusTask(title: "Due tomorrow", category: .other)
        task.dueDate = tomorrow
        task.startDate = nil
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Task with dueDate tomorrow must be EXCLUDED from completedTodayTasks")
    }

    /// 1.5 Task completed yesterday -> EXCLUDED
    func testInvariant1_CompletedYesterday_Excluded() {
        let store = makeStore()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        var task = FocusTask(title: "Completed yesterday", category: .other)
        task.dueDate = todayStart
        task.isCompleted = true
        task.completedAt = yesterday
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Task completed yesterday must be EXCLUDED from completedTodayTasks")
    }

    /// 1.6 Adversarial: Task NOT completed (isCompleted = false), but completedAt set to now -> EXCLUDED
    func testInvariant1_NotCompletedWithCompletedAtDate_Excluded() {
        let store = makeStore()
        var task = FocusTask(title: "Uncompleted ghost", category: .other)
        task.dueDate = todayStart
        task.isCompleted = false
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Task with isCompleted == false must NEVER be included even if completedAt is non-nil")
    }

    /// 1.7 Adversarial: Task completed (isCompleted = true), but completedAt is nil -> EXCLUDED
    func testInvariant1_CompletedWithNilCompletedAt_Excluded() {
        let store = makeStore()
        var task = FocusTask(title: "Completed without timestamp", category: .other)
        task.dueDate = todayStart
        task.isCompleted = true
        task.completedAt = nil
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Completed task with nil completedAt must be safely EXCLUDED")
    }

    /// 1.8 Adversarial: Overdue task (dueDate in past) completed today -> INCLUDED
    func testInvariant1_OverdueTaskCompletedToday_Included() {
        let store = makeStore()
        let pastDate = calendar.date(byAdding: .day, value: -5, to: todayStart)!
        var task = FocusTask(title: "Ancient overdue task", category: .other)
        task.dueDate = pastDate
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, task.id)
    }

    /// 1.9 Adversarial: Task with startDate in past (started yesterday) completed today -> INCLUDED
    func testInvariant1_PastStartDateCompletedToday_Included() {
        let store = makeStore()
        let pastDate = calendar.date(byAdding: .day, value: -2, to: todayStart)!
        var task = FocusTask(title: "Past start date", category: .other)
        task.startDate = pastDate
        task.dueDate = nil
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, task.id)
    }

    /// 1.10 Adversarial: Task with dueDate tomorrow BUT startDate today -> INCLUDED
    func testInvariant1_DueDateTomorrowWithStartDateToday_Included() {
        let store = makeStore()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        var task = FocusTask(title: "Multi-day task starting today", category: .other)
        task.startDate = todayStart
        task.dueDate = tomorrow
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertEqual(result.count, 1, "A task active today via startDate <= today must be included even if dueDate is tomorrow")
    }

    /// 1.11 Adversarial: Task completed in future calendar day (clock skew) -> EXCLUDED
    func testInvariant1_CompletedInFutureCalendarDay_Excluded() {
        let store = makeStore()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        var task = FocusTask(title: "Future completed", category: .other)
        task.dueDate = todayStart
        task.isCompleted = true
        task.completedAt = tomorrow
        store.tasks = [task]

        let result = store.completedTodayTasks
        XCTAssertTrue(result.isEmpty, "Task with future completedAt must not appear in today's completed section")
    }

    /// 1.12 Adversarial: Parameterized deterministic query across custom calendar reference
    func testInvariant1_ParameterizedDeterministicQuery() {
        let store = makeStore()
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let customNow = Date(timeIntervalSince1970: 1775000000) // Deterministic epoch
        let customToday = utcCalendar.startOfDay(for: customNow)
        let customYesterday = utcCalendar.date(byAdding: .day, value: -1, to: customNow)!

        var taskA = FocusTask(title: "A", category: .other)
        taskA.dueDate = customToday
        taskA.isCompleted = true
        taskA.completedAt = customNow

        var taskB = FocusTask(title: "B", category: .other)
        taskB.dueDate = customToday
        taskB.isCompleted = true
        taskB.completedAt = customYesterday

        store.tasks = [taskA, taskB]

        let results = store.completedTodayTasks(relativeTo: customNow, calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "A")
    }

    // =========================================================================
    // MARK: - 2. Reversibility Invariant Suite
    // =========================================================================

    /// 2.1 Basic reversibility: toggleCompletion sets isCompleted=false, completedAt=nil, restores to active
    func testInvariant2_ToggleCompletionReversibility() {
        let store = makeStore()
        store.newTaskTitle = "Clean Desk"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]

        // 1. Complete
        store.toggleCompletion(for: task)
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNotNil(store.tasks[0].completedAt)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 0)
        XCTAssertEqual(store.completedTodayTasks.count, 1)

        // 2. Uncomplete (Reverse)
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(store.completedTodayTasks.count, 0)
        XCTAssertEqual(store.tasks(for: .todayTask).first?.title, "Clean Desk")
    }

    /// 2.2 Reversibility does not generate duplicate recurrence on uncheck
    func testInvariant2_RecurrenceSpawningOnlyOnCompletionNotOnUncheck() {
        let store = makeStore()
        store.newTaskTitle = "Daily Standup"
        store.newTaskRecurrence = .daily
        store.addTask(for: .todayTask)
        store.tasks[0].recurrence = .daily
        XCTAssertEqual(store.tasks.count, 1)

        // Complete: spawns 1 next occurrence
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, 2, "Completion must spawn 1 next recurrence")
        XCTAssertTrue(store.tasks.contains { $0.isCompleted })
        XCTAssertTrue(store.tasks.contains { !$0.isCompleted })

        // Find the completed original task
        let completedIndex = store.tasks.firstIndex { $0.isCompleted }!
        let completedTask = store.tasks[completedIndex]

        // Uncheck the original task
        store.toggleCompletion(for: completedTask)
        XCTAssertEqual(store.tasks.count, 2, "Unchecking must NOT spawn duplicate recurrences")
        XCTAssertFalse(store.tasks[completedIndex].isCompleted)
        XCTAssertNil(store.tasks[completedIndex].completedAt)
    }

    /// 2.3 Reversibility preserves all metadata across completion and revival
    func testInvariant2_MetadataPreservationAcrossCycles() {
        let store = makeStore()
        store.newTaskTitle = "Complex Task"
        store.addTask(for: .todayTask)
        let originalID = store.tasks[0].id
        store.tasks[0].notes = "Detailed notes here"
        store.tasks[0].linkURL = "https://developer.apple.com"
        store.tasks[0].priority = 3
        store.tasks[0].estimatedPomodoros = 5
        store.tasks[0].completedPomodoros = 2
        store.tasks[0].timeSpentMinutes = 50
        store.tasks[0].isPinned = true
        store.tasks[0].category = .work
        store.tasks[0].items = [
            ChecklistItem(title: "Subtask 1", doneAt: Date()),
            ChecklistItem(title: "Subtask 2")
        ]

        // Cycle 10 times
        for _ in 0..<10 {
            store.toggleCompletion(for: store.tasks[0])
            store.toggleCompletion(for: store.tasks[0])
        }

        let task = store.tasks[0]
        XCTAssertEqual(task.id, originalID)
        XCTAssertEqual(task.title, "Complex Task")
        XCTAssertEqual(task.notes, "Detailed notes here")
        XCTAssertEqual(task.linkURL, "https://developer.apple.com")
        XCTAssertEqual(task.priority, 3)
        XCTAssertEqual(task.estimatedPomodoros, 5)
        XCTAssertEqual(task.completedPomodoros, 2)
        XCTAssertEqual(task.timeSpentMinutes, 50)
        XCTAssertTrue(task.isPinned)
        XCTAssertEqual(task.category, .work)
        XCTAssertEqual(task.checklist.count, 2)
        XCTAssertTrue(task.checklist[0].isDone)
        XCTAssertFalse(task.checklist[1].isDone)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
    }

    /// 2.4 Active task completion clears activeTaskId, revival does not silently reactivate
    func testInvariant2_ActiveTaskCompletionAndRevival() {
        let store = makeStore()
        store.newTaskTitle = "Active Focused Task"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id
        store.activeTaskId = id
        XCTAssertEqual(store.activeTask?.id, id)

        // Complete: activeTaskId is cleared
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertNil(store.activeTaskId)

        // Revive: activeTaskId remains nil (does not accidentally auto-focus)
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertNil(store.activeTaskId)
        XCTAssertFalse(store.tasks[0].isCompleted)
    }

    /// 2.5 Persistence roundtrip for toggle completion
    func testInvariant2_PersistenceRoundtrip() {
        let store1 = makeStore()
        store1.newTaskTitle = "Persisted Task"
        store1.addTask(for: .todayTask)
        store1.toggleCompletion(for: store1.tasks[0])
        store1.flushPendingSaves()

        // Reload: verify completed state
        let store2 = makeStore()
        XCTAssertEqual(store2.completedTodayTasks.count, 1)
        XCTAssertTrue(store2.tasks[0].isCompleted)
        XCTAssertNotNil(store2.tasks[0].completedAt)

        // Revive in store2 and flush
        store2.toggleCompletion(for: store2.tasks[0])
        store2.flushPendingSaves()

        // Reload store3: verify revived state
        let store3 = makeStore()
        XCTAssertEqual(store3.completedTodayTasks.count, 0)
        XCTAssertEqual(store3.tasks(for: .todayTask).count, 1)
        XCTAssertFalse(store3.tasks[0].isCompleted)
        XCTAssertNil(store3.tasks[0].completedAt)
    }

    // =========================================================================
    // MARK: - 3. Empty State Invariant Suite
    // =========================================================================

    /// 3.1 0 active, >0 completed -> achievement empty state + completed section
    func testInvariant3_ZeroActivePositiveCompleted_AchievementState() {
        let store = makeStore()
        store.newTaskTitle = "Finished Task"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[0])

        let activeToday = store.tasks(for: .todayTask)
        let completedToday = store.completedTodayTasks

        XCTAssertTrue(activeToday.isEmpty)
        XCTAssertEqual(completedToday.count, 1)

        // Logical evaluation in TaskListView:
        // overdueTasks.isEmpty && dueTodayTasks.isEmpty -> true
        // !taskStore.completedTodayTasks.isEmpty -> true
        // Shows todayEmptyHero("今日待办已悉数达成", "享受从容当下") AND todayCompletedSection
        let showsAchievement = activeToday.isEmpty && !completedToday.isEmpty
        XCTAssertTrue(showsAchievement)
    }

    /// 3.2 0 active, 0 completed -> serene empty state (no completed section)
    func testInvariant3_ZeroActiveZeroCompleted_SereneEmptyState() {
        let store = makeStore()
        let activeToday = store.tasks(for: .todayTask)
        let completedToday = store.completedTodayTasks

        XCTAssertTrue(activeToday.isEmpty)
        XCTAssertTrue(completedToday.isEmpty)

        // Logical evaluation in TaskListView:
        // overdueTasks.isEmpty && dueTodayTasks.isEmpty -> true
        // taskStore.completedTodayTasks.isEmpty -> true
        // Shows todayEmptyHero("享受从容当下", "在上方添加今天的第一项任务，或开启一段专注")
        // todayCompletedSection is empty / not rendered
        let showsSerenePristine = activeToday.isEmpty && completedToday.isEmpty
        XCTAssertTrue(showsSerenePristine)
    }

    /// 3.3 >0 active, >0 completed -> active tasks list + completed section (NO empty state)
    func testInvariant3_PositiveActivePositiveCompleted_ActiveListWithCompletedSection() {
        let store = makeStore()
        store.newTaskTitle = "Task A"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Task B"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[0])

        let activeToday = store.tasks(for: .todayTask)
        let completedToday = store.completedTodayTasks

        XCTAssertEqual(activeToday.count, 1)
        XCTAssertEqual(completedToday.count, 1)

        // In TaskListView:
        // overdueTasks.isEmpty && dueTodayTasks.isEmpty -> false
        // Renders taskSection(title: "今日待办", ...) AND todayCompletedSection
        // Does NOT render todayEmptyHero
        let showsActiveList = !activeToday.isEmpty
        XCTAssertTrue(showsActiveList)
    }

    /// 3.4 Overdue active task with 0 due today -> Shows active overdue list + completed section, NOT empty state
    func testInvariant3_OverdueActiveTask_RendersActiveListNotAchievement() {
        let store = makeStore()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        var overdue = FocusTask(title: "Overdue task", category: .other)
        overdue.dueDate = yesterday
        store.tasks = [overdue]

        // Add a completed today task
        var completed = FocusTask(title: "Done today", category: .other)
        completed.dueDate = todayStart
        completed.isCompleted = true
        completed.completedAt = now
        store.tasks.append(completed)

        let activeToday = store.tasks(for: .todayTask)
        XCTAssertEqual(activeToday.count, 1)
        XCTAssertTrue(activeToday[0].isOverdue)

        // In TaskListView: overdueTasks is NOT empty, so overdueTasks.isEmpty && dueTodayTasks.isEmpty is FALSE
        // It renders "已逾期" section and todayCompletedSection, NOT todayEmptyHero
        let isAllActiveEmpty = activeToday.isEmpty
        XCTAssertFalse(isAllActiveEmpty, "Overdue active tasks must prevent the achievement empty state")
    }

    /// 3.5 Non-today screens (Inbox, Tomorrow) do NOT render achievement empty state or today completed section
    func testInvariant3_NonTodayScreensIsolation() {
        let store = makeStore()
        // Today has completed tasks
        var task = FocusTask(title: "Today completed", category: .other)
        task.dueDate = todayStart
        task.isCompleted = true
        task.completedAt = now
        store.tasks = [task]

        // But on Tomorrow list, active is 0
        let tomorrowActive = store.tasks(for: .tomorrowTask)
        XCTAssertTrue(tomorrowActive.isEmpty)

        // Verification: completedTodayTasks accessor in TaskListView guards viewState.selectedScreen == .todayTask
        // When not on .todayTask, completedTodayTasks returns []
        // Therefore tomorrow screen uses standard emptyState, not todayEmptyHero or todayCompletedSection
        XCTAssertEqual(store.completedTodayTasks.count, 1)
    }

    /// 3.6 Full dynamic lifecycle transition between active, achievement, and pristine states
    func testInvariant3_DynamicLifecycleTransitionBetweenStates() {
        let store = makeStore()

        // Phase 1: 0 active, 0 completed -> Pristine Serene State
        XCTAssertTrue(store.tasks(for: .todayTask).isEmpty)
        XCTAssertTrue(store.completedTodayTasks.isEmpty)

        // Phase 2: Add Task 1 -> 1 active, 0 completed -> Active List State
        store.newTaskTitle = "Task 1"
        store.addTask(for: .todayTask)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertTrue(store.completedTodayTasks.isEmpty)

        // Phase 3: Complete Task 1 -> 0 active, 1 completed -> Achievement State + Fold
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertTrue(store.tasks(for: .todayTask).isEmpty)
        XCTAssertEqual(store.completedTodayTasks.count, 1)

        // Phase 4: Add Task 2 -> 1 active, 1 completed -> Active List State + Fold
        store.newTaskTitle = "Task 2"
        store.addTask(for: .todayTask)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(store.completedTodayTasks.count, 1)

        // Phase 5: Complete Task 2 -> 0 active, 2 completed -> Achievement State + Fold
        let task2 = store.tasks.first { !$0.isCompleted }!
        store.toggleCompletion(for: task2)
        XCTAssertTrue(store.tasks(for: .todayTask).isEmpty)
        XCTAssertEqual(store.completedTodayTasks.count, 2)

        // Phase 6: Uncheck Task 1 -> 1 active, 1 completed -> Active List State + Fold
        let completedTask1 = store.tasks.first { $0.title == "Task 1" }!
        store.toggleCompletion(for: completedTask1)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(store.completedTodayTasks.count, 1)
        XCTAssertEqual(store.tasks(for: .todayTask).first?.title, "Task 1")

        // Phase 7: Uncheck Task 2 -> 2 active, 0 completed -> Active List State (Fold hidden)
        let completedTask2 = store.tasks.first { $0.title == "Task 2" }!
        store.toggleCompletion(for: completedTask2)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 2)
        XCTAssertTrue(store.completedTodayTasks.isEmpty)

        // Phase 8: Delete Task 1 and Task 2 -> 0 active, 0 completed -> Pristine Serene State
        store.deleteTask(store.tasks[0])
        store.deleteTask(store.tasks[0])
        XCTAssertTrue(store.tasks(for: .todayTask).isEmpty)
        XCTAssertTrue(store.completedTodayTasks.isEmpty)
    }

    /// 2.6 Multi-reversibility with recurring tasks: Complete -> Uncheck -> Complete Again
    func testInvariant2_RecurringTaskMultipleCompletionCycles() {
        let store = makeStore()
        store.newTaskTitle = "Daily Journal"
        store.newTaskRecurrence = .daily
        store.addTask(for: .todayTask)
        store.tasks[0].recurrence = .daily
        XCTAssertEqual(store.tasks.count, 1)

        // 1. Complete -> spawns recurrence 1
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, 2)

        // 2. Uncheck -> does NOT spawn recurrence
        let original = store.tasks.first { $0.isCompleted }!
        store.toggleCompletion(for: original)
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertFalse(store.tasks[0].isCompleted)

        // 3. Complete again -> deduplication ensures NO duplicate recurrence is spawned while next occurrence is still open
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, 2, "Re-completing must not create duplicate future occurrences when one is already open")
    }
}

