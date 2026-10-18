import XCTest
@testable import iFocus

/// F1: every save path commits through one place, task-less time counts as 学习,
/// and a count-up block stops (logged) at the 2-hour cap.
final class CommitSessionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempDir: URL!

    override func setUpWithError() throws {
        suiteName = "iFocus.CommitSessionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-CommitSession-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeSettings() -> SettingsStore {
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        settings.soundEnabled = false
        settings.dockBounceOnComplete = false
        settings.autoStartBreaks = false
        settings.autoStartWork = false
        return settings
    }

    private func makeStores(tasks seed: [FocusTask] = []) -> (SettingsStore, TaskStore, TimerStore) {
        let settings = makeSettings()
        let tasks = TaskStore(storageDirectory: tempDir)
        if !seed.isEmpty { tasks.tasks = seed }
        let timer = TimerStore(settings: settings, taskStore: tasks, sessionStorageDirectory: tempDir)
        return (settings, tasks, timer)
    }

    private func snapshot(
        elapsed: TimeInterval,
        planned: TimeInterval,
        countUp: Bool?,
        running: Bool = false,
        taskId: UUID? = nil,
        title: String? = nil,
        category: String? = nil,
        savedAt: Date = Date()
    ) -> TimerSessionSnapshot {
        TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: planned - elapsed,
            isRunning: running,
            elapsedBeforePause: elapsed,
            sessionPlannedDuration: planned,
            activeTaskId: taskId,
            workTaskTitle: title,
            workTaskCategory: category,
            cleanExit: true,
            savedAt: savedAt,
            countUp: countUp
        )
    }

    /// Resume a paused snapshot and run it to its deadline (start() completes synchronously at 0).
    private func runToEnd(_ timer: TimerStore) {
        XCTAssertTrue(timer.resumeFromPendingSnapshot())
        timer.start()
    }

    // MARK: - One commit per path, task-less = 学习

    func testPomodoroEndCommitsOnceAndTasklessCountsAsStudy() {
        TimerSessionPersistence.save(snapshot(elapsed: 1500, planned: 1500, countUp: false, title: "自由专注"), to: tempDir)
        let (_, tasks, timer) = makeStores()
        runToEnd(timer)

        XCTAssertEqual(tasks.focusSessions.count, 1)
        XCTAssertEqual(tasks.focusSessions.first?.durationMinutes, 25)
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .study)
        XCTAssertEqual(tasks.focusSessions.first?.taskTitle, "自由专注")
        XCTAssertEqual(timer.lastCommittedSessionID, tasks.focusSessions.first?.id)
        XCTAssertEqual(timer.mode, .shortBreak)
    }

    func testCountUpFinishCommitsOnceAsStudy() {
        TimerSessionPersistence.save(snapshot(elapsed: 47 * 60, planned: 7200, countUp: true, title: "自由专注"), to: tempDir)
        let (_, tasks, timer) = makeStores()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())

        timer.skipToNext()

        XCTAssertEqual(tasks.focusSessions.map(\.durationMinutes), [47])
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .study)
        XCTAssertEqual(timer.lastCommittedSessionID, tasks.focusSessions.first?.id)
    }

    func testFinishEarlyCommitsOnceAsStudy() {
        TimerSessionPersistence.save(snapshot(elapsed: 10 * 60, planned: 1500, countUp: false, title: "自由专注"), to: tempDir)
        let (_, tasks, timer) = makeStores()
        XCTAssertTrue(timer.resumeFromPendingSnapshot())

        timer.finishEarlyAndLog()

        XCTAssertEqual(tasks.focusSessions.map(\.durationMinutes), [10])
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .study)
        XCTAssertEqual(timer.lastCommittedSessionID, tasks.focusSessions.first?.id)
    }

    func testTaskSessionKeepsItsCategory() {
        let task = FocusTask(title: "组会", category: .work)
        TimerSessionPersistence.save(
            snapshot(elapsed: 1500, planned: 1500, countUp: false, taskId: task.id, title: task.title, category: "工作"),
            to: tempDir
        )
        let (_, tasks, timer) = makeStores(tasks: [task])
        runToEnd(timer)

        XCTAssertEqual(tasks.focusSessions.count, 1)
        XCTAssertEqual(tasks.focusSessions.first?.taskCategory, .work)
        XCTAssertEqual(tasks.focusSessions.first?.taskId, task.id)
    }

    func testEmptyTasklessTitleBecomesUnnamed() {
        TimerSessionPersistence.save(snapshot(elapsed: 1500, planned: 1500, countUp: false, title: "  "), to: tempDir)
        let (_, tasks, timer) = makeStores()
        runToEnd(timer)
        XCTAssertEqual(tasks.focusSessions.first?.taskTitle, "未指定任务")
    }

    // MARK: - 2-hour cap

    func testCountUpCapCommits120OnceAndStops() {
        let task = FocusTask(title: "3b1b 线性代数的本质", category: .study)
        TimerSessionPersistence.save(
            snapshot(elapsed: 7200, planned: 7200, countUp: true, taskId: task.id, title: task.title, category: "学习"),
            to: tempDir
        )
        let (_, tasks, timer) = makeStores(tasks: [task])
        runToEnd(timer)

        XCTAssertEqual(tasks.focusSessions.map(\.durationMinutes), [120])
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isSessionInProgress)
        XCTAssertEqual(timer.mode, .work)
        XCTAssertEqual(timer.capRestart, TimerStore.CapRestart(taskId: task.id, taskTitle: task.title))
        XCTAssertNil(TimerSessionPersistence.load(from: tempDir))
    }

    func testRestartAfterCapStartsCountUpOnSameTask() {
        let task = FocusTask(title: "3b1b 线性代数的本质", category: .study)
        TimerSessionPersistence.save(
            snapshot(elapsed: 7200, planned: 7200, countUp: true, taskId: task.id, title: task.title, category: "学习"),
            to: tempDir
        )
        let (settings, tasks, timer) = makeStores(tasks: [task])
        settings.countUpWork = false
        runToEnd(timer)

        timer.restartAfterCap()

        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.isCountingUp, "「再开一段」 is a count-up even with the setting off")
        XCTAssertEqual(tasks.activeTaskId, task.id)
        XCTAssertNil(timer.capRestart)
        XCTAssertEqual(tasks.focusSessions.count, 1)
        timer.reset()
    }

    func testResumeAfterCapWouldHavePassedCommits120AtCapTime() throws {
        let task = FocusTask(title: "Python 基础", category: .study)
        let savedAt = Date(timeIntervalSince1970: floor(Date().addingTimeInterval(-3 * 3600).timeIntervalSince1970))
        TimerSessionPersistence.save(
            snapshot(elapsed: 90 * 60, planned: 7200, countUp: true, running: true,
                     taskId: task.id, title: task.title, category: "学习", savedAt: savedAt),
            to: tempDir
        )
        let (_, tasks, timer) = makeStores(tasks: [task])

        XCTAssertEqual(tasks.focusSessions.map(\.durationMinutes), [120])
        let session = try XCTUnwrap(tasks.focusSessions.first)
        XCTAssertEqual(session.timestamp.timeIntervalSince1970, savedAt.addingTimeInterval(30 * 60).timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(session.taskId, task.id)
        XCTAssertNil(timer.pendingResumeSnapshot)
        XCTAssertEqual(timer.capRestart?.taskId, task.id)
        XCTAssertNil(TimerSessionPersistence.load(from: tempDir))
    }

    func testResumeBeforeCapKeepsExistingResumeRules() {
        TimerSessionPersistence.save(
            snapshot(elapsed: 90 * 60, planned: 7200, countUp: true, running: true,
                     title: "自由专注", savedAt: Date().addingTimeInterval(-10 * 60)),
            to: tempDir
        )
        let (_, tasks, timer) = makeStores()
        XCTAssertTrue(tasks.focusSessions.isEmpty)
        XCTAssertNotNil(timer.pendingResumeSnapshot)
        XCTAssertNil(timer.capRestart)
    }

    // MARK: - Quick-add and upgrade guard

    func testQuickAddDefaultIsAlwaysStudy() {
        let (_, tasks, _) = makeStores()
        tasks.newTaskCategory = .work
        tasks.newTaskTitle = "组会"
        tasks.addTask(for: .todayTask)
        XCTAssertEqual(tasks.tasks.last?.category, .work)
        XCTAssertEqual(tasks.newTaskCategory, .study)
    }

    func testPreUpgradeCopyOnlyWhenVersionChanges() throws {
        let fm = FileManager.default
        try Data("[]".utf8).write(to: tempDir.appendingPathComponent("tasks.json"))
        try Data("[]".utf8).write(to: tempDir.appendingPathComponent("focus_sessions.json"))
        try Data("x".utf8).write(to: tempDir.appendingPathComponent("avatar-1.png"))
        let now = ISO8601DateFormatter().date(from: "2026-10-18T14:05:00Z")!

        let first = try XCTUnwrap(PreUpgradeGuard.run(storageDirectory: tempDir, currentVersion: "1.14.0", defaults: defaults, now: now))
        XCTAssertTrue(first.lastPathComponent.hasPrefix("unknown-2026101"))
        XCTAssertEqual(Set(try fm.contentsOfDirectory(atPath: first.path)), ["tasks.json", "focus_sessions.json"])

        XCTAssertNil(PreUpgradeGuard.run(storageDirectory: tempDir, currentVersion: "1.14.0", defaults: defaults, now: now))
        let folders = try fm.contentsOfDirectory(atPath: tempDir.appendingPathComponent("pre-upgrade").path)
        XCTAssertEqual(folders.count, 1)

        let second = try XCTUnwrap(PreUpgradeGuard.run(storageDirectory: tempDir, currentVersion: "1.15.0", defaults: defaults, now: now))
        XCTAssertTrue(second.lastPathComponent.hasPrefix("1.14.0-"))
    }

    func testSkippedItemsAreCounted() throws {
        let good = FocusTask(title: "能读的", category: .study)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var array = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode([good])) as? [[String: Any]])
        var bad = array[0]
        bad["id"] = UUID().uuidString
        bad["category"] = "未来的分类"
        array.append(bad)
        try JSONSerialization.data(withJSONObject: array).write(to: tempDir.appendingPathComponent("tasks.json"))

        let tasks = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(tasks.tasks.map(\.title), ["能读的"])
        XCTAssertEqual(tasks.skippedItemsOnLoad, 1)
    }
}
