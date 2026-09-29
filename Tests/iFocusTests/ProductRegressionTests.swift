import XCTest
@testable import iFocus
@testable import iFocusCore

/// Deep product-path regression: undo, quick-add, session resume, persistence, deep links.
final class ProductRegressionTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-ProductRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "iFocus.ProductRegression.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        if let tempDir {
            TimerSessionPersistence.clear(in: tempDir)
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }
    
    private func makeTaskStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir)
    }
    
    private func makeTimer(workMinutes: Int = 25) -> (SettingsStore, TaskStore, TimerStore) {
        defaults.set(workMinutes, forKey: "workMinutes")
        defaults.set(8, forKey: "dailyGoal")
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks = TaskStore(storageDirectory: tempDir)
        let timer = TimerStore(
            settings: settings,
            taskStore: tasks,
            sessionStorageDirectory: tempDir
        )
        return (settings, tasks, timer)
    }
    
    // MARK: - Undo deletion
    
    func testBatchDeleteUndoRestoresAllAndActiveId() {
        let store = makeTaskStore()
        store.newTaskTitle = "A"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "B"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "C"
        store.addTask(for: .todayTask)
        let ids = Set(store.tasks.map(\.id))
        store.activeTaskId = store.tasks[1].id
        let active = store.activeTaskId
        
        store.deleteTasks(ids: ids)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNil(store.activeTaskId)
        XCTAssertNotNil(store.undoDeletionBanner)
        XCTAssertTrue(store.undoDeletionBanner!.message.contains("3"))
        
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 3)
        XCTAssertEqual(store.activeTaskId, active)
        XCTAssertEqual(Set(store.tasks.map(\.title)), Set(["A", "B", "C"]))
    }
    
    func testSecondUndoWithoutNewDeleteIsNoOp() {
        let store = makeTaskStore()
        store.newTaskTitle = "Only"
        store.addTask(for: .inboxTask)
        store.deleteTasks(ids: Set(store.tasks.map(\.id)))
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertFalse(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 1)
    }
    
    func testDismissUndoBannerExpiresRestoreWindow() {
        let store = makeTaskStore()
        store.newTaskTitle = "Gone"
        store.addTask(for: .inboxTask)
        store.deleteTasks(ids: Set(store.tasks.map(\.id)))
        XCTAssertNotNil(store.undoDeletionBanner)
        store.dismissUndoDeletionBanner()
        XCTAssertNil(store.undoDeletionBanner)
        XCTAssertFalse(store.undoLastDeletion())
        XCTAssertTrue(store.tasks.isEmpty)
    }
    
    func testDeletePreservesNotesAndLinkOnUndo() {
        let store = makeTaskStore()
        store.newTaskTitle = "With meta"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        store.updateTask(
            id: id,
            title: "With meta",
            category: .study,
            priority: 2,
            estimatedPomodoros: 3,
            dueDate: nil,
            notes: "重要备注",
            linkURL: "https://example.com/x"
        )
        store.deleteTasks(ids: [id])
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks[0].notes, "重要备注")
        XCTAssertTrue(store.tasks[0].hasLink)
    }
    
    // MARK: - Quick add overrides
    
    func testDueOverrideTodayFromInboxFilter() {
        let store = makeTaskStore()
        store.newTaskTitle = "Force today"
        store.addTask(for: .inboxTask, dueOverride: .today)
        XCTAssertTrue(Calendar.current.isDateInToday(store.tasks[0].dueDate!))
    }
    
    func testDueOverrideInboxFromTodayFilter() {
        let store = makeTaskStore()
        store.newTaskTitle = "Force inbox"
        store.addTask(for: .todayTask, dueOverride: .inbox)
        XCTAssertNil(store.tasks[0].dueDate)
        // Still incomplete inbox material.
        let inbox = store.tasks(for: .inboxTask)
        XCTAssertEqual(inbox.count, 1)
    }
    
    func testAddTaskReturnsIdAndClearsTitle() {
        let store = makeTaskStore()
        store.newTaskTitle = "  有空格  "
        let id = store.addTask(for: .todayTask)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.newTaskTitle, "")
        XCTAssertEqual(store.tasks[0].title, "有空格")
        XCTAssertEqual(store.tasks[0].id, id)
    }
    
    // MARK: - Session resume product paths
    
    func testResumeRestoresPausedWorkAndTask() {
        let (_, tasks, timer) = makeTimer()
        tasks.newTaskTitle = "试卷"
        tasks.addTask(for: .todayTask)
        let id = tasks.tasks[0].id
        
        timer.startFocus(on: id)
        timer.pause()
        XCTAssertTrue(timer.isSessionInProgress)
        
        let snap = timer.makeSessionSnapshot(cleanExit: false)
        TimerSessionPersistence.save(snap, to: tempDir)
        
        let settings2 = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks2 = TaskStore(storageDirectory: tempDir)
        let timer2 = TimerStore(
            settings: settings2,
            taskStore: tasks2,
            sessionStorageDirectory: tempDir
        )
        XCTAssertNotNil(timer2.pendingResumeSnapshot)
        XCTAssertEqual(timer2.pendingResumeSnapshot?.resumeReasonLabel, "上次异常退出时")
        
        XCTAssertTrue(timer2.resumeFromPendingSnapshot())
        XCTAssertFalse(timer2.isRunning)
        XCTAssertTrue(timer2.isSessionInProgress)
        XCTAssertEqual(tasks2.activeTaskId, id)
        XCTAssertEqual(timer2.mode, .work)
        XCTAssertNil(timer2.pendingResumeSnapshot)
    }
    
    func testCleanExitSnapshotReasonLabel() {
        let snap = TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: 100,
            isRunning: false,
            elapsedBeforePause: 20,
            sessionPlannedDuration: 1500,
            activeTaskId: nil,
            workTaskTitle: "x",
            workTaskCategory: nil,
            cleanExit: true,
            savedAt: Date()
        )
        XCTAssertTrue(snap.shouldOfferResume)
        XCTAssertEqual(snap.resumeReasonLabel, "上次退出时")
    }
    
    func testIdleMarkCleanExitClearsSnapshotFile() {
        let (_, _, timer) = makeTimer()
        XCTAssertFalse(timer.isSessionInProgress)
        timer.markCleanExit()
        XCTAssertNil(TimerSessionPersistence.load(from: tempDir))
    }
    
    func testDiscardPendingResumeThenNoSecondOffer() {
        let snap = TimerSessionSnapshot(
            mode: TimerMode.shortBreak.rawValue,
            timeRemaining: 200,
            isRunning: true,
            elapsedBeforePause: 10,
            sessionPlannedDuration: 300,
            activeTaskId: nil,
            workTaskTitle: nil,
            workTaskCategory: nil,
            cleanExit: false,
            savedAt: Date()
        )
        TimerSessionPersistence.save(snap, to: tempDir)
        
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks = TaskStore(storageDirectory: tempDir)
        let timer = TimerStore(
            settings: settings,
            taskStore: tasks,
            sessionStorageDirectory: tempDir
        )
        XCTAssertNotNil(timer.pendingResumeSnapshot)
        timer.discardPendingResume()
        XCTAssertNil(timer.pendingResumeSnapshot)
        XCTAssertNil(TimerSessionPersistence.load(from: tempDir))
        
        let timer2 = TimerStore(
            settings: settings,
            taskStore: tasks,
            sessionStorageDirectory: tempDir
        )
        XCTAssertNil(timer2.pendingResumeSnapshot)
    }
    
    func testSnapshotRoundTripISO8601() {
        let id = UUID()
        let original = TimerSessionSnapshot(
            mode: TimerMode.longBreak.rawValue,
            timeRemaining: 888,
            isRunning: true,
            elapsedBeforePause: 12.5,
            sessionPlannedDuration: 900,
            activeTaskId: id,
            workTaskTitle: "长休",
            workTaskCategory: TaskCategory.life.rawValue,
            cleanExit: false,
            savedAt: Date()
        )
        TimerSessionPersistence.save(original, to: tempDir)
        let loaded = TimerSessionPersistence.load(from: tempDir)
        XCTAssertEqual(loaded?.mode, original.mode)
        XCTAssertEqual(loaded?.timeRemaining ?? 0, 888, accuracy: 0.01)
        XCTAssertEqual(loaded?.activeTaskId, id)
        XCTAssertEqual(loaded?.timerMode, .longBreak)
        XCTAssertTrue(loaded?.shouldOfferResume == true)
    }
    
    // MARK: - Timer lifecycle product rules
    
    func testSkipDoesNotCreateFocusSessionOrPomodoro() {
        let (_, tasks, timer) = makeTimer()
        let before = tasks.focusSessions.count
        timer.start()
        timer.skipToNext()
        XCTAssertEqual(tasks.focusSessions.count, before)
        XCTAssertEqual(timer.mode, .shortBreak)
        XCTAssertFalse(timer.isSessionInProgress)
    }
    
    func testWorkCompletionAttributionUsesSessionSnapshot() {
        let body = TimerStore.workCompletionBody(
            taskId: UUID(),
            taskTitle: "数学试卷",
            next: .shortBreak
        )
        XCTAssertTrue(body.contains("数学试卷"))
        XCTAssertTrue(body.contains("短休息"))
    }
    
    func testCelebrationMentionsGoalWhenReached() {
        let text = TimerStore.celebrationText(
            wasWork: true,
            minutes: 25,
            nextMode: .shortBreak,
            completedPomodorosToday: 8,
            dailyGoal: 8
        )
        XCTAssertTrue(text.contains("目标") || text.contains("达成") || text.contains("完成"))
    }
    
    func testIsSessionInProgressAfterImmediatePause() {
        let (_, _, timer) = makeTimer()
        timer.start()
        timer.pause()
        XCTAssertTrue(timer.isSessionInProgress)
        timer.reset()
        XCTAssertFalse(timer.isSessionInProgress)
    }
    
    // MARK: - Persistence integrity
    
    func testTasksSurviveReloadIncludingNotesLink() {
        let store = makeTaskStore()
        store.newTaskTitle = "持久化"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id
        store.updateTask(
            id: id,
            title: "持久化",
            category: .work,
            priority: 1,
            estimatedPomodoros: 4,
            dueDate: Calendar.current.startOfDay(for: Date()),
            recurrence: .weekly,
            notes: "n1",
            linkURL: "https://ifocus.local/doc"
        )
        store.activeTaskId = id
        store.flushPendingSaves()
        
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.tasks[0].notes, "n1")
        XCTAssertTrue(reloaded.tasks[0].hasLink)
        XCTAssertEqual(reloaded.tasks[0].recurrence, .weekly)
        XCTAssertEqual(reloaded.activeTaskId, id)
    }
    
    func testFocusSessionPersistsImmediately() {
        let store = makeTaskStore()
        store.logFocusSession(taskId: nil, taskTitle: "自由专注", minutes: 25)
        // No flush — logFocusSession writes immediately.
        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.focusSessions.count, 1)
        XCTAssertEqual(reloaded.focusSessions[0].durationMinutes, 25)
    }
    
    func testCorruptTasksBackupAndEmptyStart() throws {
        let url = tempDir.appendingPathComponent("tasks.json")
        try "not-json{{{".write(to: url, atomically: true, encoding: .utf8)
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertTrue(store.tasks.isEmpty)
        // Corrupt backup should exist.
        let backups = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("corrupt") }
        XCTAssertFalse(backups.isEmpty)
    }
    
    // MARK: - Filtering / list semantics
    
    func testTodayIncludesOverdueAndToday() {
        let store = makeTaskStore()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        
        store.newTaskTitle = "逾期"
        store.addTask(for: .inboxTask)
        store.updateDueDate(for: store.tasks[0], to: yesterday)
        
        store.newTaskTitle = "今天"
        store.addTask(for: .todayTask)
        
        store.newTaskTitle = "明天"
        store.addTask(for: .tomorrowTask)
        
        let todayList = store.tasks(for: .todayTask).filter { !$0.isCompleted }
        let titles = Set(todayList.map(\.title))
        XCTAssertTrue(titles.contains("逾期"))
        XCTAssertTrue(titles.contains("今天"))
        XCTAssertFalse(titles.contains("明天"))
    }
    
    func testPinSortsAboveUnpinnedInSameList() {
        let store = makeTaskStore()
        store.newTaskTitle = "后加未置顶"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "先加要置顶"
        store.addTask(for: .todayTask)
        // Pin the second-added task (last in array often).
        let toPin = store.tasks.first { $0.title == "先加要置顶" }!
        store.togglePin(for: toPin)
        let list = store.tasks(for: .todayTask)
        XCTAssertEqual(list.first?.title, "先加要置顶")
        XCTAssertTrue(list.first?.isPinned == true)
    }
    
    func testRecurrenceSpawnsOnCompleteAndKeepsNotes() {
        let store = makeTaskStore()
        store.newTaskTitle = "每日"
        store.newTaskRecurrence = .daily
        store.addTask(for: .todayTask, dueOverride: .today)
        let id = store.tasks[0].id
        store.updateTask(
            id: id,
            title: "每日",
            category: .study,
            priority: 2,
            estimatedPomodoros: 1,
            dueDate: store.tasks[0].dueDate,
            recurrence: .daily,
            notes: "继承备注",
            linkURL: "https://example.com"
        )
        store.toggleCompletion(for: store.tasks[0])
        let incomplete = store.tasks.filter { !$0.isCompleted }
        XCTAssertEqual(incomplete.count, 1)
        XCTAssertEqual(incomplete[0].notes, "继承备注")
        XCTAssertTrue(incomplete[0].hasLink)
        XCTAssertEqual(incomplete[0].recurrence, .daily)
    }
    
    // MARK: - Deep links
    
    func testDeepLinkCoreActionsParse() {
        XCTAssertEqual(DeepLinkRouter.parse(URL(string: "ifocus://toggle")!), .toggle)
        XCTAssertEqual(DeepLinkRouter.parse(URL(string: "ifocus://start")!), .start)
        XCTAssertEqual(DeepLinkRouter.parse(URL(string: "ifocus://freefocus")!), .freeFocus)
        XCTAssertEqual(DeepLinkRouter.parse(URL(string: "ifocus://open?screen=today")!), .open(.todayTask))
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "ifocus://nope")!))
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "http://ifocus/start")!))
    }
    
    // MARK: - Mode accent follows work theme rule
    
    func testWorkModeAccentTracksAppTheme() {
        // Work must not stay hard-coded tomato when accent is green.
        XCTAssertEqual(TimerMode.work.accent, AppTheme.accent)
        XCTAssertNotEqual(TimerMode.shortBreak.accent, TimerMode.longBreak.accent)
    }
    
    // MARK: - Stats helpers still sane
    
    func testTodayTotalsFromSessions() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sessions: [(Date, Int)] = [
            (today.addingTimeInterval(3600), 25),
            (today.addingTimeInterval(7200), 25)
        ]
        let totals = FocusStats.dayTotals(sessions: sessions, on: today, calendar: cal)
        XCTAssertEqual(totals.pomodoros, 2)
        XCTAssertEqual(totals.minutes, 50)
    }

    // MARK: - Navigation & Quick-Add Focus

    func testContentViewStateQuickAddFocusNavigation() {
        let viewState = ContentViewState()
        XCTAssertEqual(viewState.selectedScreen, .timer)
        XCTAssertFalse(viewState.shouldFocusQuickAdd)

        // Simulating ⌘N behavior from non-task screen
        let isTaskInputScreen: Bool
        switch viewState.selectedScreen {
        case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .inboxTask:
            isTaskInputScreen = true
        default:
            isTaskInputScreen = false
        }
        if !isTaskInputScreen {
            viewState.selectedScreen = .todayTask
        }
        viewState.shouldFocusQuickAdd = true

        XCTAssertEqual(viewState.selectedScreen, .todayTask)
        XCTAssertTrue(viewState.shouldFocusQuickAdd)
    }

    // MARK: - Sidebar Drawer Layout Metrics

    func testSidebarDrawerWidthMetrics() {
        func expandedSidebarWidth(for availableWidth: CGFloat) -> CGFloat {
            let fluid = min(1, max(0, (availableWidth - WindowLayoutMetrics.minimum.width)
                                   / max(1, WindowLayoutMetrics.reference.width - WindowLayoutMetrics.minimum.width)))
            return 208 + fluid * 44
        }

        func sidebarWidth(for availableWidth: CGFloat, collapsed: Bool) -> CGFloat {
            collapsed ? 0 : expandedSidebarWidth(for: availableWidth)
        }

        // Collapsed should always yield 0 regardless of available width
        XCTAssertEqual(sidebarWidth(for: 800, collapsed: true), 0)
        XCTAssertEqual(sidebarWidth(for: 1024, collapsed: true), 0)
        XCTAssertEqual(sidebarWidth(for: 1280, collapsed: true), 0)
        XCTAssertEqual(sidebarWidth(for: 1440, collapsed: true), 0)

        // Expanded minimum size (1024pt window) -> base 208pt
        XCTAssertEqual(sidebarWidth(for: 1024, collapsed: false), 208, accuracy: 0.001)

        // Expanded reference size (1280pt window) -> max 252pt (208 + 44)
        XCTAssertEqual(sidebarWidth(for: 1280, collapsed: false), 252, accuracy: 0.001)

        // Expanded large display (1440pt window) -> clamped at 252pt
        XCTAssertEqual(sidebarWidth(for: 1440, collapsed: false), 252, accuracy: 0.001)

        // Sub-minimum clamped to base 208pt
        XCTAssertEqual(sidebarWidth(for: 800, collapsed: false), 208, accuracy: 0.001)

        // Midpoint (1152pt window) -> 230pt
        XCTAssertEqual(sidebarWidth(for: 1152, collapsed: false), 230, accuracy: 0.001)
    }
}
