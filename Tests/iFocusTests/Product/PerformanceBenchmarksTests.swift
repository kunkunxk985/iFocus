import XCTest
@testable import iFocus
@testable import iFocusCore

/// Micro-benchmarks for large local datasets (thousands of sessions / tasks).
///
/// Run only when checking scale:
///   swift test --disable-sandbox --filter PerformanceBenchmarks
///
/// Thresholds are soft guards for regressions on Apple Silicon laptops — not CI hard fails
/// unless grossly exceeded (see `assertUnder`).
final class PerformanceBenchmarksTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Perf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }
    
    // MARK: - Fixtures
    
    private func makeSessions(count: Int, spreadDays: Int = 365) -> [(timestamp: Date, minutes: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [(Date, Int)] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let dayOffset = -(i % max(1, spreadDays))
            let hour = 8 + (i % 10)
            let day = cal.date(byAdding: .day, value: dayOffset, to: today)!
            let ts = cal.date(bySettingHour: hour, minute: (i * 7) % 60, second: 0, of: day) ?? day
            out.append((ts, 15 + (i % 3) * 10)) // 15 / 25 / 35
        }
        return out
    }
    
    private func seedTaskStore(tasks: Int, sessions: Int) -> TaskStore {
        let store = TaskStore(storageDirectory: tempDir)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Bulk-append without thrashing didSet debounce too heavily: still realistic path.
        var built: [FocusTask] = []
        built.reserveCapacity(tasks)
        for i in 0..<tasks {
            let due: Date? = (i % 5 == 0) ? nil : cal.date(byAdding: .day, value: -(i % 14), to: today)
            built.append(
                FocusTask(
                    title: "任务 \(i)",
                    category: TaskCategory.allCases[i % TaskCategory.allCases.count],
                    priority: (i % 4) + 1,
                    estimatedPomodoros: (i % 5) + 1,
                    completedPomodoros: i % 3,
                    dueDate: due,
                    timeSpentMinutes: (i % 10) * 25,
                    isPinned: i % 17 == 0,
                    sortIndex: i,
                    notes: i % 9 == 0 ? "备注 \(i)" : "",
                    linkURL: i % 11 == 0 ? "https://example.com/\(i)" : ""
                )
            )
        }
        store.tasks = built
        
        var sess: [FocusSession] = []
        sess.reserveCapacity(sessions)
        let pairs = makeSessions(count: sessions)
        for (idx, p) in pairs.enumerated() {
            let task = built.isEmpty ? nil : built[idx % built.count]
            sess.append(
                FocusSession(
                    taskId: task?.id,
                    taskTitle: task?.title ?? "自由专注",
                    taskCategory: task?.category,
                    durationMinutes: p.minutes,
                    timestamp: p.timestamp
                )
            )
        }
        store.focusSessions = sess
        store.flushPendingSaves()
        return store
    }
    
    private func assertUnder(
        _ seconds: TimeInterval,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        work: () -> Void
    ) {
        let t0 = CFAbsoluteTimeGetCurrent()
        work()
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        // Always print so `swift test` log shows real numbers.
        print(String(format: "[perf] %@ = %.3f ms (limit %.0f ms)", label, elapsed * 1000, seconds * 1000))
        XCTAssertLessThan(
            elapsed,
            seconds,
            "\(label) took \(String(format: "%.3f", elapsed * 1000))ms, limit \(String(format: "%.0f", seconds * 1000))ms",
            file: file,
            line: line
        )
    }
    
    // MARK: - FocusStats pure (2k / 5k)
    
    func testPerf_minutesByDay_2kSessions() {
        let sessions = makeSessions(count: 2_000)
        assertUnder(0.050, "minutesByDay 2k") {
            _ = FocusStats.minutesByDay(sessions: sessions)
        }
    }
    
    func testPerf_minutesByDay_5kSessions() {
        let sessions = makeSessions(count: 5_000)
        assertUnder(0.120, "minutesByDay 5k") {
            _ = FocusStats.minutesByDay(sessions: sessions)
        }
    }
    
    func testPerf_streaks_5kTimestamps() {
        let stamps = makeSessions(count: 5_000).map(\.timestamp)
        assertUnder(0.080, "streaks 5k") {
            _ = FocusStats.streaks(sessionTimestamps: stamps)
        }
    }
    
    func testPerf_contributionGrid_from5k() {
        let sessions = makeSessions(count: 5_000)
        assertUnder(0.150, "heatmap grid from 5k") {
            let byDay = FocusStats.minutesByDay(sessions: sessions)
            _ = FocusStats.contributionGrid(minutesByDay: byDay)
        }
    }
    
    func testPerf_rangeTotals_5k() {
        let sessions = makeSessions(count: 5_000)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -29, to: today)!
        assertUnder(0.080, "rangeTotals 30d over 5k") {
            _ = FocusStats.rangeTotals(sessions: sessions, from: from, through: today, calendar: cal)
        }
    }
    
    func testPerf_timelineBlocks_todayFrom5k() {
        let sessions = makeSessions(count: 5_000).map {
            (timestamp: $0.timestamp, minutes: $0.minutes, title: "t")
        }
        assertUnder(0.100, "timelineBlocks today 5k scan") {
            _ = FocusStats.timelineBlocks(sessions: sessions, on: Date())
        }
    }
    
    // MARK: - TaskStore scale
    
    func testPerf_filterAllLists_500Tasks() {
        let store = seedTaskStore(tasks: 500, sessions: 0)
        assertUnder(0.080, "tasks(for:) ×6 filters @500 tasks") {
            _ = store.tasks(for: .todayTask)
            _ = store.tasks(for: .tomorrowTask)
            _ = store.tasks(for: .weekTask)
            _ = store.tasks(for: .plannedTask)
            _ = store.tasks(for: .completedTask)
            _ = store.tasks(for: .inboxTask)
        }
    }

    func testPerf_filterAllLists_500Tasks_cachedSecondPass() {
        let store = seedTaskStore(tasks: 500, sessions: 0)
        _ = store.tasks(for: .todayTask)
        _ = store.tasks(for: .tomorrowTask)
        _ = store.tasks(for: .weekTask)
        _ = store.tasks(for: .plannedTask)
        _ = store.tasks(for: .completedTask)
        _ = store.tasks(for: .inboxTask)
        assertUnder(0.012, "tasks(for:) ×6 filters @500 cached") {
            _ = store.tasks(for: .todayTask)
            _ = store.tasks(for: .tomorrowTask)
            _ = store.tasks(for: .weekTask)
            _ = store.tasks(for: .plannedTask)
            _ = store.tasks(for: .completedTask)
            _ = store.tasks(for: .inboxTask)
        }
    }

    func testPerf_analyticsPageSnapshot_5kSessions500Tasks() {
        let store = seedTaskStore(tasks: 500, sessions: 5_000)
        assertUnder(0.220, "AnalyticsPageSnapshot 5k sessions + 500 tasks") {
            _ = AnalyticsPageSnapshot.build(
                range: .today,
                focusSessions: store.focusSessions,
                tasks: store.tasks,
                categoriesInUse: store.categoriesInUse,
                dailyGoal: 4,
                completedPomodoros: 2,
                totalSecondsToday: 3_600,
                isWorkMode: true,
                sessionLive: true
            )
        }
    }
    
    func testPerf_sidebarBadgeCounts_500Tasks() {
        let store = seedTaskStore(tasks: 500, sessions: 0)
        assertUnder(0.020, "sidebarBadgeCounts @500") {
            _ = store.sidebarBadgeCounts()
        }
    }
    
    func testPerf_filterToday_2000Tasks() {
        let store = seedTaskStore(tasks: 2_000, sessions: 0)
        assertUnder(0.150, "tasks(for: .today) @2000") {
            _ = store.tasks(for: .todayTask)
        }
    }
    
    func testPerf_reload2000TasksAnd2000SessionsFromDisk() {
        _ = seedTaskStore(tasks: 2_000, sessions: 2_000)
        assertUnder(0.500, "TaskStore init reload 2k+2k from disk") {
            _ = TaskStore(storageDirectory: tempDir)
        }
    }
    
    func testPerf_saveFlush_1000Tasks() {
        let store = seedTaskStore(tasks: 1_000, sessions: 500)
        // Touch to dirty save path.
        store.tasks[0].title = "renamed-for-bench"
        assertUnder(0.400, "flushPendingSaves 1k tasks + 500 sessions") {
            store.flushPendingSaves()
        }
    }
    
    /// XCTest `measure` block — prints average over iterations in test log.
    func testPerf_measure_minutesByDay_2k_x10() {
        let sessions = makeSessions(count: 2_000)
        measure {
            _ = FocusStats.minutesByDay(sessions: sessions)
        }
    }
}
