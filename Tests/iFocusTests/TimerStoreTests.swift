import XCTest
@testable import iFocus

final class TimerStoreTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-TimerStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "iFocus.TimerStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }
    
    private func makeStores(workMinutes: Int = 25) -> (SettingsStore, TaskStore, TimerStore) {
        defaults.set(workMinutes, forKey: "workMinutes")
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks = TaskStore(storageDirectory: tempDir)
        let timer = TimerStore(settings: settings, taskStore: tasks)
        return (settings, tasks, timer)
    }
    
    // MARK: - Pure routing helpers
    
    func testNextModeLongBreakEveryFourthWorkSession() {
        XCTAssertEqual(TimerStore.nextMode(after: .work, workSessionsCompletedToday: 1), .shortBreak)
        XCTAssertEqual(TimerStore.nextMode(after: .work, workSessionsCompletedToday: 3), .shortBreak)
        XCTAssertEqual(TimerStore.nextMode(after: .work, workSessionsCompletedToday: 4), .longBreak)
        XCTAssertEqual(TimerStore.nextMode(after: .work, workSessionsCompletedToday: 8), .longBreak)
        XCTAssertEqual(TimerStore.nextMode(after: .shortBreak, workSessionsCompletedToday: 4), .work)
        XCTAssertEqual(TimerStore.nextMode(after: .longBreak, workSessionsCompletedToday: 4), .work)
    }
    
    func testWorkCompletionBodyUsesSessionSnapshotNotLiveTask() {
        let taskId = UUID()
        let body = TimerStore.workCompletionBody(
            taskId: taskId,
            taskTitle: "写深度测试",
            next: .shortBreak
        )
        XCTAssertEqual(body, "「写深度测试」已完成 · 下一个：短休息")
        
        let free = TimerStore.workCompletionBody(
            taskId: nil,
            taskTitle: "自由专注",
            next: .longBreak
        )
        XCTAssertEqual(free, "休息一下吧，下一个：长休息")
        
        // Deleted task still has id in snapshot but empty title falls back.
        let deleted = TimerStore.workCompletionBody(
            taskId: taskId,
            taskTitle: "   ",
            next: .shortBreak
        )
        XCTAssertEqual(deleted, "休息一下吧，下一个：短休息")
    }
    
    // MARK: - Session lifecycle
    
    func testImmediatePauseStillCountsAsSessionInProgress() {
        let (_, _, timer) = makeStores()
        XCTAssertFalse(timer.isSessionInProgress)
        
        timer.start()
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.isSessionInProgress)
        
        timer.pause()
        XCTAssertFalse(timer.isRunning)
        // Critical: previously this could look "idle" if remaining ≈ full duration.
        XCTAssertTrue(timer.isSessionInProgress)
        
        timer.reset()
        XCTAssertFalse(timer.isSessionInProgress)
    }
    
    func testSyncDurationFromSettingsDoesNotWipeActiveSession() {
        let (settings, _, timer) = makeStores(workMinutes: 25)
        timer.start()
        timer.pause()
        let remainingBefore = timer.timeRemaining
        
        settings.workMinutes = 50
        timer.syncDurationFromSettingsIfIdle()
        
        XCTAssertEqual(timer.timeRemaining, remainingBefore, accuracy: 0.5)
        XCTAssertTrue(timer.isSessionInProgress)
    }
    
    func testSyncDurationFromSettingsUpdatesWhenIdle() {
        let (settings, _, timer) = makeStores(workMinutes: 25)
        XCTAssertFalse(timer.isSessionInProgress)
        XCTAssertEqual(timer.timeRemaining, 25 * 60, accuracy: 0.01)
        
        settings.workMinutes = 40
        timer.syncDurationFromSettingsIfIdle()
        
        XCTAssertEqual(timer.timeRemaining, 40 * 60, accuracy: 0.01)
        XCTAssertFalse(timer.isSessionInProgress)
    }
    
    func testProgressUsesPlannedDurationNotLiveSettings() {
        let (settings, _, timer) = makeStores(workMinutes: 25)
        timer.start()
        // Simulate ~half remaining of a 25-minute session without waiting on real clock.
        // pause() freezes remaining from wall clock; force remaining via pause after short run is flaky.
        // Instead: pause immediately then verify progress total basis via public API contract:
        // after start, changing settings must not make progress jump to near-complete.
        timer.pause()
        settings.workMinutes = 1
        let progress = timer.progress
        // Remaining ≈ 25 min, if wrongly using 1 min total, progress would clamp to 1.0.
        XCTAssertLessThan(progress, 0.2, "progress should stay near 0 for a fresh 25m session even if settings become 1m")
    }
    
    func testSelectTaskDoesNotStealOwnershipWithoutResetPath() {
        let (_, tasks, timer) = makeStores()
        tasks.newTaskTitle = "任务A"
        tasks.addTask(for: .inboxTask)
        tasks.newTaskTitle = "任务B"
        tasks.addTask(for: .inboxTask)
        let a = tasks.tasks[0].id
        let b = tasks.tasks[1].id
        
        timer.startFocus(on: a)
        XCTAssertEqual(tasks.activeTaskId, a)
        XCTAssertTrue(timer.isRunning)
        
        timer.selectTask(b)
        XCTAssertEqual(tasks.activeTaskId, b)
        // Switching mid-run restarts a fresh segment on the new task.
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.mode, .work)
    }
    
    func testSkipDoesNotLogSession() {
        let (_, tasks, timer) = makeStores()
        timer.start()
        timer.skipToNext()
        
        XCTAssertEqual(tasks.focusSessions.count, 0)
        XCTAssertEqual(timer.mode, .shortBreak)
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isSessionInProgress)
    }
    
    func testUpdateStatsFromHistoryCountsTodayOnly() {
        let (_, tasks, timer) = makeStores()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        tasks.focusSessions = [
            FocusSession(taskId: nil, taskTitle: "昨", durationMinutes: 25, timestamp: yesterday.addingTimeInterval(3600)),
            FocusSession(taskId: nil, taskTitle: "今", durationMinutes: 25, timestamp: today.addingTimeInterval(3600)),
            FocusSession(taskId: nil, taskTitle: "今2", durationMinutes: 10, timestamp: today.addingTimeInterval(7200)),
        ]
        timer.updateStatsFromHistory(taskStore: tasks)
        
        XCTAssertEqual(timer.completedPomodoros, 2)
        XCTAssertEqual(timer.totalSecondsToday, 35 * 60)
    }
}
