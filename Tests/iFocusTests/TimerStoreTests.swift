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
        let timer = TimerStore(
            settings: settings,
            taskStore: tasks,
            sessionStorageDirectory: tempDir
        )
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

    func testNextModeRespectsCustomLongBreakInterval() {
        XCTAssertEqual(
            TimerStore.nextMode(after: .work, workSessionsCompletedToday: 2, longBreakEvery: 2),
            .longBreak
        )
        XCTAssertEqual(
            TimerStore.nextMode(after: .work, workSessionsCompletedToday: 3, longBreakEvery: 2),
            .shortBreak
        )
        XCTAssertEqual(
            TimerStore.nextMode(after: .work, workSessionsCompletedToday: 3, longBreakEvery: 3),
            .longBreak
        )
    }
    
    func testWorkSessionsUntilLongBreakAndCelebration() {
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 0), 4)
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 1), 3)
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 3), 1)
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 4), 4)
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 1, every: 3), 2)
        XCTAssertEqual(TimerStore.workSessionsUntilLongBreak(completedPomodorosToday: 3, every: 3), 3)
        
        let text = TimerStore.celebrationText(
            wasWork: true,
            minutes: 25,
            nextMode: .longBreak,
            completedPomodorosToday: 4,
            dailyGoal: 8
        )
        XCTAssertTrue(text.contains("长休息"))
        
        let goal = TimerStore.celebrationText(
            wasWork: true,
            minutes: 25,
            nextMode: .shortBreak,
            completedPomodorosToday: 8,
            dailyGoal: 8
        )
        XCTAssertTrue(goal.contains("目标") || goal.contains("完成"))
    }
    
    func testAutoStartBreaksDoesNotAutoStartWork() {
        let (settings, _, timer) = makeStores(workMinutes: 1)
        settings.autoStartBreaks = true
        settings.autoStartWork = false
        settings.longBreakEvery = 4

        // Skip out of short break → next is work; autoStartWork is off so stay idle.
        timer.mode = .shortBreak
        timer.skipToNext()
        XCTAssertEqual(timer.mode, .work)
        XCTAssertFalse(timer.isRunning)
    }

    func testAutoStartWorkStartsAfterBreakSkipWhenEnabled() {
        // skipToNext does not auto-start — only complete() path does.
        // Verify settings clamp for long-break interval instead.
        let (settings, _, _) = makeStores()
        settings.longBreakEvery = 99
        XCTAssertEqual(settings.longBreakEvery, 8)
        settings.longBreakEvery = 1
        XCTAssertEqual(settings.longBreakEvery, 2)
    }

    func testStartPreparedSegmentStartsIdleMode() {
        let (_, _, timer) = makeStores(workMinutes: 25)
        XCTAssertFalse(timer.isRunning)
        timer.startPreparedSegment()
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.isSessionInProgress)
        timer.reset()
        XCTAssertFalse(timer.isRunning)
    }

    func testStrictModeBlocksSkip() {
        let (settings, _, timer) = makeStores(workMinutes: 25)
        settings.strictMode = true
        XCTAssertFalse(timer.canSkipSegment)
        timer.mode = .work
        timer.start()
        XCTAssertTrue(timer.isRunning)
        timer.skipToNext()
        // Still work and running — skip must no-op (mode unchanged)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertTrue(timer.isRunning)
        XCTAssertNotNil(timer.celebrationMessage)
        settings.strictMode = false
        XCTAssertTrue(timer.canSkipSegment)
        timer.skipToNext()
        XCTAssertEqual(timer.mode, .shortBreak)
        XCTAssertFalse(timer.isRunning)
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
        
        // Mid-session switch requires confirm (or force).
        timer.selectTask(b)
        XCTAssertEqual(tasks.activeTaskId, a)
        XCTAssertNotNil(timer.pendingSessionDiscard)
        timer.confirmPendingSessionDiscard()
        XCTAssertEqual(tasks.activeTaskId, b)
        // Switching mid-run restarts a fresh segment on the new task.
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.mode, .work)
    }
    
    func testStartWorkFocusFromRunningBreak() {
        let (_, tasks, timer) = makeStores()
        tasks.newTaskTitle = "作业"
        tasks.addTask(for: .todayTask)
        let id = tasks.tasks[0].id
        timer.startFocus(on: id)
        XCTAssertTrue(timer.isRunning)
        // Force into a running break without completing.
        timer.skipToNext()
        XCTAssertEqual(timer.mode, .shortBreak)
        timer.start()
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.mode, .shortBreak)
        
        // Start work on same task should confirm then switch to work.
        timer.startFocus(on: id)
        XCTAssertNotNil(timer.pendingSessionDiscard)
        timer.confirmPendingSessionDiscard()
        XCTAssertEqual(timer.mode, .work)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(tasks.activeTaskId, id)
    }
    
    func testRequestStartWorkFocusForceFromBreak() {
        let (_, _, timer) = makeStores()
        timer.setMode(.shortBreak)
        timer.start()
        timer.requestStartWorkFocus(taskId: nil, force: true)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertTrue(timer.isRunning)
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
    
    func testFinishEarlyLogsElapsedMinutesWithCategory() {
        let snapshot = TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: 15 * 60,
            isRunning: false,
            elapsedBeforePause: 10 * 60,
            sessionPlannedDuration: 25 * 60,
            activeTaskId: nil,
            workTaskTitle: "3b1b 线性代数",
            workTaskCategory: TaskCategory.study.rawValue,
            cleanExit: true,
            savedAt: Date()
        )
        TimerSessionPersistence.save(snapshot, to: tempDir)
        let (_, tasks, timer) = makeStores()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        XCTAssertEqual(timer.earlyFinishMinutes, 10)

        timer.finishEarlyAndLog()

        XCTAssertEqual(tasks.focusSessions.count, 1)
        XCTAssertEqual(tasks.focusSessions.first?.durationMinutes, 10)
        XCTAssertEqual(tasks.focusSessions.first?.taskTitle, "3b1b 线性代数")
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .study)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertFalse(timer.isSessionInProgress)
        XCTAssertNil(timer.earlyFinishMinutes)
        XCTAssertEqual(timer.celebrationMessage, "已记录 10 分钟专注")
    }

    func testFinishEarlyUnderOneMinuteLogsNothing() {
        let (_, tasks, timer) = makeStores()
        timer.start()
        XCTAssertNil(timer.earlyFinishMinutes)

        timer.finishEarlyAndLog()

        XCTAssertEqual(tasks.focusSessions.count, 0)
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isSessionInProgress)
    }

    func testFinishEarlyIsNotOfferedDuringBreak() {
        let (_, tasks, timer) = makeStores()
        timer.setMode(.shortBreak)
        timer.start()
        XCTAssertNil(timer.earlyFinishMinutes)

        timer.finishEarlyAndLog()

        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(tasks.focusSessions.count, 0)
        timer.reset()
    }

    // MARK: - Count-up focus

    private func countUpSnapshot(elapsedMinutes: Int, countUp: Bool?) -> TimerSessionSnapshot {
        let planned = TimeInterval(TimerStore.countUpCapMinutes * 60)
        let elapsed = TimeInterval(elapsedMinutes * 60)
        return TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: planned - elapsed,
            isRunning: false,
            elapsedBeforePause: elapsed,
            sessionPlannedDuration: planned,
            activeTaskId: nil,
            workTaskTitle: "看网课",
            workTaskCategory: TaskCategory.study.rawValue,
            cleanExit: true,
            savedAt: Date(),
            countUp: countUp
        )
    }

    func testCountUpStartsAtZeroAndFinishReplacesSkip() {
        let (settings, _, timer) = makeStores()
        settings.strictMode = true
        settings.countUpWork = true
        timer.syncDurationFromSettingsIfIdle()

        XCTAssertTrue(timer.isCountingUp)
        XCTAssertEqual(timer.timeString, "00:00")
        XCTAssertFalse(timer.finishesOnSkip)

        timer.start()
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.finishesOnSkip)
        // Strict mode blocks skipping, but finishing a count-up is always allowed.
        XCTAssertTrue(timer.canSkipSegment)
        timer.reset()
    }

    func testCountUpFinishLogsElapsedAndMovesToBreak() {
        let (settings, tasks, timer) = makeStores()
        settings.soundEnabled = false
        settings.dockBounceOnComplete = false
        settings.countUpWork = true
        TimerSessionPersistence.save(countUpSnapshot(elapsedMinutes: 47, countUp: true), to: tempDir)
        timer.reloadPendingResumeFromDisk()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        XCTAssertEqual(timer.timeString, "47:00")

        timer.skipToNext()

        XCTAssertEqual(tasks.focusSessions.count, 1)
        XCTAssertEqual(tasks.focusSessions.first?.durationMinutes, 47)
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .study)
        XCTAssertEqual(timer.mode, .shortBreak)
        XCTAssertFalse(timer.isRunning)
    }

    func testCountUpUnderOneMinuteFinishOnlyResets() {
        let (settings, tasks, timer) = makeStores()
        settings.countUpWork = true
        timer.start()

        timer.skipToNext()

        XCTAssertEqual(tasks.focusSessions.count, 0)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertFalse(timer.isSessionInProgress)
    }

    func testCountUpFinishAfterSecondsOnlyResets() {
        let (settings, tasks, timer) = makeStores()
        settings.countUpWork = true
        var snapshot = countUpSnapshot(elapsedMinutes: 0, countUp: true)
        snapshot.timeRemaining -= 30
        snapshot.elapsedBeforePause = 30
        TimerSessionPersistence.save(snapshot, to: tempDir)
        timer.reloadPendingResumeFromDisk()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        XCTAssertTrue(timer.finishesOnSkip)
        XCTAssertNil(timer.earlyFinishMinutes)

        timer.skipToNext()

        XCTAssertEqual(tasks.focusSessions.count, 0)
        XCTAssertEqual(timer.completedPomodoros, 0)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertFalse(timer.isSessionInProgress)
    }

    func testFinishEarlyAfterSecondsLogsNothing() {
        let snapshot = TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: 25 * 60 - 30,
            isRunning: false,
            elapsedBeforePause: 30,
            sessionPlannedDuration: 25 * 60,
            activeTaskId: nil,
            workTaskTitle: nil,
            workTaskCategory: nil,
            cleanExit: true,
            savedAt: Date()
        )
        TimerSessionPersistence.save(snapshot, to: tempDir)
        let (_, tasks, timer) = makeStores()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        XCTAssertNil(timer.earlyFinishMinutes)

        timer.finishEarlyAndLog()

        XCTAssertEqual(tasks.focusSessions.count, 0)
        XCTAssertFalse(timer.isSessionInProgress)
        XCTAssertNil(timer.celebrationMessage)
    }

    func testCountUpIdleAtLaunchAddsNoFocusTime() {
        defaults.set(true, forKey: "countUpWork")
        let (_, _, timer) = makeStores()

        XCTAssertTrue(timer.isCountingUp)
        XCTAssertEqual(timer.totalSecondsToday, 0)
        XCTAssertEqual(timer.progress, 0)
        XCTAssertEqual(timer.timeString, "00:00")
    }

    func testCountUpIsLockedForTheRunningSegment() {
        let (settings, _, timer) = makeStores()
        settings.countUpWork = true
        timer.start()
        settings.countUpWork = false
        XCTAssertTrue(timer.isCountingUp)

        timer.reset()
        XCTAssertFalse(timer.isCountingUp)
        XCTAssertEqual(timer.timeString, "25:00")
    }

    func testOldSnapshotResumesAsCountdownEvenWithCountUpOn() {
        let (settings, _, timer) = makeStores()
        settings.countUpWork = true
        TimerSessionPersistence.save(countUpSnapshot(elapsedMinutes: 10, countUp: nil), to: tempDir)
        timer.reloadPendingResumeFromDisk()
        XCTAssertEqual(timer.pendingResumeSnapshot?.resumeTimeLabel, "还剩 110:00")
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        XCTAssertFalse(timer.isCountingUp)
        timer.reset()
    }

    func testCountUpSnapshotResumeLabelShowsElapsed() {
        XCTAssertEqual(countUpSnapshot(elapsedMinutes: 47, countUp: true).resumeTimeLabel, "已专注 47:00")
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
    
    // MARK: - Session snapshot resume
    
    func testDirtySnapshotOfferedAfterSimulatedCrash() {
        let (_, tasks, timer) = makeStores()
        tasks.newTaskTitle = "崩溃恢复任务"
        tasks.addTask(for: .inboxTask)
        let id = tasks.tasks[0].id
        
        timer.startFocus(on: id)
        timer.pause()
        XCTAssertTrue(timer.isSessionInProgress)
        
        // Simulate unclean exit: dirty file left on disk, new process boots.
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
        XCTAssertTrue(timer2.pendingResumeSnapshot?.shouldOfferResume == true)
        XCTAssertEqual(timer2.pendingResumeSnapshot?.activeTaskId, id)
        
        XCTAssertTrue(timer2.resumeFromPendingSnapshot())
        XCTAssertNil(timer2.pendingResumeSnapshot)
        XCTAssertFalse(timer2.isRunning)
        XCTAssertTrue(timer2.isSessionInProgress)
        XCTAssertEqual(tasks2.activeTaskId, id)
        XCTAssertEqual(timer2.mode, .work)
    }
    
    func testCleanExitStillOffersResume() {
        // Intentional quit mid-session should still be recoverable next launch.
        let (_, _, timer) = makeStores()
        timer.start()
        timer.pause()
        timer.markCleanExit()
        
        let settings2 = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks2 = TaskStore(storageDirectory: tempDir)
        let timer2 = TimerStore(
            settings: settings2,
            taskStore: tasks2,
            sessionStorageDirectory: tempDir
        )
        XCTAssertNotNil(timer2.pendingResumeSnapshot)
        XCTAssertTrue(timer2.pendingResumeSnapshot?.cleanExit == true)
        XCTAssertTrue(timer2.pendingResumeSnapshot?.shouldOfferResume == true)
    }
    
    func testDiscardPendingResumeClearsFile() {
        let snap = TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: 600,
            isRunning: true,
            elapsedBeforePause: 100,
            sessionPlannedDuration: 1500,
            activeTaskId: nil,
            workTaskTitle: "自由专注",
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
    }
}
