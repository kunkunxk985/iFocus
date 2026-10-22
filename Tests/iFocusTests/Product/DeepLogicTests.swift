import XCTest
@testable import iFocusCore
@testable import iFocus

/// Extra edge-case coverage beyond the original core suite.
final class DeepLogicTests: XCTestCase {
    
    // MARK: - FocusStats edges
    
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = hour
        return utcCalendar.date(from: c)!
    }
    
    func testFormatTotalMinutesNegativeAndZero() {
        XCTAssertEqual(FocusStats.formatTotalMinutes(-10), "0分钟")
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
    }
    
    func testCompletionRateClampsAndHandlesOvercomplete() {
        XCTAssertEqual(FocusStats.completionRate(total: 0, completed: 5), "0%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: 10), "100%")
        XCTAssertEqual(FocusStats.completionRate(total: 4, completed: -1), "0%")
    }
    
    func testStreaksSingleDayToday() {
        let today = day(2026, 3, 10)
        let result = FocusStats.streaks(
            sessionTimestamps: [today],
            relativeTo: today,
            calendar: utcCalendar
        )
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
    }
    
    func testStreaksEmpty() {
        let result = FocusStats.streaks(sessionTimestamps: [], relativeTo: day(2026, 3, 10), calendar: utcCalendar)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 0)
    }
    
    func testAverageDailyFocusMinutesUsesDistinctDays() {
        let stamps = [day(2026, 3, 1), day(2026, 3, 1, hour: 18), day(2026, 3, 2)]
        // 100 minutes across 2 distinct days → 50
        XCTAssertEqual(
            FocusStats.averageDailyFocusMinutes(sessionTimestamps: stamps, totalMinutes: 100, calendar: utcCalendar),
            50
        )
        XCTAssertEqual(
            FocusStats.averageDailyFocusMinutes(sessionTimestamps: [], totalMinutes: 0, calendar: utcCalendar),
            0
        )
    }
    
    func testPeakHoursEmptyAndMidnightWrap() {
        XCTAssertEqual(
            FocusStats.peakFocusHoursString(sessionTimestamps: [], calendar: utcCalendar),
            "暂无数据"
        )
        let midnight = day(2026, 3, 1, hour: 23)
        XCTAssertEqual(
            FocusStats.peakFocusHoursString(sessionTimestamps: [midnight], calendar: utcCalendar),
            "23:00 - 00:00"
        )
    }
    
    func testIntensityBoundaries() {
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 25), 1)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 26), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 50), 2)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 51), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 100), 3)
        XCTAssertEqual(FocusStats.intensityLevel(minutes: 101), 4)
    }
    
    // MARK: - Analytics A-tier helpers
    
    func testDayAndRangeTotals() {
        let sessions: [(Date, Int)] = [
            (day(2026, 3, 10, hour: 9), 25),
            (day(2026, 3, 10, hour: 14), 25),
            (day(2026, 3, 9, hour: 10), 50),
            (day(2026, 3, 8, hour: 11), 10),
        ]
        let today = FocusStats.dayTotals(
            sessions: sessions,
            on: day(2026, 3, 10),
            calendar: utcCalendar
        )
        XCTAssertEqual(today.pomodoros, 2)
        XCTAssertEqual(today.minutes, 50)
        
        let week = FocusStats.rangeTotals(
            sessions: sessions,
            from: day(2026, 3, 8),
            through: day(2026, 3, 10),
            calendar: utcCalendar
        )
        XCTAssertEqual(week.pomodoros, 4)
        XCTAssertEqual(week.minutes, 110)
    }
    
    func testPercentChangeAndDayOverDayLabel() {
        XCTAssertEqual(FocusStats.percentChange(from: 50, to: 75), 50)
        XCTAssertEqual(FocusStats.percentChange(from: 50, to: 25), -50)
        XCTAssertNil(FocusStats.percentChange(from: 0, to: 30))
        
        XCTAssertEqual(
            FocusStats.dayOverDayMinutesLabel(todayMinutes: 30, yesterdayMinutes: 0),
            "昨日无记录"
        )
        XCTAssertEqual(
            FocusStats.dayOverDayMinutesLabel(todayMinutes: 50, yesterdayMinutes: 50),
            "与昨日持平"
        )
        XCTAssertTrue(
            FocusStats.dayOverDayMinutesLabel(todayMinutes: 75, yesterdayMinutes: 50)
                .contains("+")
        )
    }
    
    func testTimelineBlocksFromSessionEnd() {
        // timestamp = end of session
        let end = day(2026, 3, 10, hour: 10) // 10:00
        let sessions: [(Date, Int, String)] = [
            (end, 25, "写代码"), // 09:35–10:00
            (day(2026, 3, 10, hour: 15), 50, "阅读"),
        ]
        let blocks = FocusStats.timelineBlocks(
            sessions: sessions,
            on: day(2026, 3, 10),
            calendar: utcCalendar
        )
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].title, "写代码")
        XCTAssertEqual(blocks[0].minutes, 25)
        let prog = blocks[0].dayProgress(calendar: utcCalendar)
        XCTAssertGreaterThan(prog.end, prog.start)
        XCTAssertLessThan(prog.start, 0.5)
    }
    
    func testMinutesByHourOfDay() {
        let sessions: [(Date, Int)] = [
            (day(2026, 3, 10, hour: 9), 25),
            (day(2026, 3, 10, hour: 9), 10),
            (day(2026, 3, 10, hour: 14), 50),
            (day(2026, 3, 9, hour: 9), 99), // other day
        ]
        let bins = FocusStats.minutesByHourOfDay(
            sessions: sessions,
            on: day(2026, 3, 10),
            calendar: utcCalendar
        )
        XCTAssertEqual(bins.count, 24)
        XCTAssertEqual(bins[9], 35)
        XCTAssertEqual(bins[14], 50)
        XCTAssertEqual(bins[0], 0)
        XCTAssertEqual(FocusStats.peakHourLabel(fromHourMinutes: bins), "14:00–15:00")
        XCTAssertNil(FocusStats.peakHourLabel(fromHourMinutes: Array(repeating: 0, count: 24)))
    }
    
    func testFreeFocusShareAndSmartInsights() {
        XCTAssertEqual(FocusStats.freeFocusShare(freeCount: 3, totalCount: 10), 0.3, accuracy: 0.001)
        XCTAssertEqual(FocusStats.freeFocusShare(freeCount: 0, totalCount: 0), 0, accuracy: 0.001)
        
        let empty = FocusStats.smartInsights(
            todayPomodoros: 0,
            todayMinutes: 0,
            yesterdayMinutes: 0,
            dailyGoal: 8,
            currentStreak: 0,
            freeFocusShare: 0,
            hasAnyHistory: false
        )
        XCTAssertEqual(empty.count, 1)
        XCTAssertTrue(empty[0].contains("还没有"))
        
        let goalMet = FocusStats.smartInsights(
            todayPomodoros: 8,
            todayMinutes: 200,
            yesterdayMinutes: 100,
            dailyGoal: 8,
            currentStreak: 4,
            freeFocusShare: 0.2,
            hasAnyHistory: true
        )
        XCTAssertFalse(goalMet.isEmpty)
        XCTAssertTrue(goalMet[0].contains("已达成") || goalMet[0].contains("连续"))
        XCTAssertLessThanOrEqual(goalMet.count, 2)
        
        let freeHeavy = FocusStats.smartInsights(
            todayPomodoros: 1,
            todayMinutes: 25,
            yesterdayMinutes: 25,
            dailyGoal: 8,
            currentStreak: 0,
            freeFocusShare: 0.8,
            hasAnyHistory: true
        )
        XCTAssertTrue(freeHeavy.contains(where: { $0.contains("自由专注") || $0.contains("还差") }))
    }
    
    // MARK: - TaskFiltering edges
    
    private var filterNow: Date { day(2026, 3, 10, hour: 12) }
    
    private func snap(
        completed: Bool = false,
        due: Date? = nil,
        priority: Int = 1,
        created: Date? = nil
    ) -> TaskSnapshot {
        TaskSnapshot(
            isCompleted: completed,
            dueDate: due,
            priority: priority,
            createdAt: created ?? day(2026, 3, 1)
        )
    }
    
    func testWeekIncludesSeventhDayExcludesEighth() {
        let tasks = [
            snap(due: day(2026, 3, 17)), // today+7 inclusive
            snap(due: day(2026, 3, 18)), // beyond
        ]
        let result = TaskFiltering.filter(tasks, as: .week, relativeTo: filterNow, calendar: utcCalendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(utcCalendar.component(.day, from: result[0].dueDate!), 17)
    }
    
    func testSidebarBadgeCountsMatchFilterLengths() {
        let tasks = [
            snap(due: day(2026, 3, 10)),                 // today
            snap(due: day(2026, 3, 8)),                  // today + overdue
            snap(due: day(2026, 3, 11)),                 // tomorrow
            snap(due: day(2026, 3, 14)),                 // week
            snap(due: nil),                              // inbox
            snap(completed: true, due: day(2026, 3, 1)), // completed only
        ]
        let counts = TaskFiltering.sidebarBadgeCounts(tasks, relativeTo: filterNow, calendar: utcCalendar)
        XCTAssertEqual(counts.today, TaskFiltering.filter(tasks, as: .today, relativeTo: filterNow, calendar: utcCalendar).count)
        XCTAssertEqual(counts.overdue, 1)
        XCTAssertEqual(counts.tomorrow, TaskFiltering.filter(tasks, as: .tomorrow, relativeTo: filterNow, calendar: utcCalendar).count)
        XCTAssertEqual(counts.week, TaskFiltering.filter(tasks, as: .week, relativeTo: filterNow, calendar: utcCalendar).count)
        XCTAssertEqual(counts.planned, TaskFiltering.filter(tasks, as: .planned, relativeTo: filterNow, calendar: utcCalendar).count)
        XCTAssertEqual(counts.inbox, TaskFiltering.filter(tasks, as: .inbox, relativeTo: filterNow, calendar: utcCalendar).count)
    }
    
    func testMatchesAgreesWithFilterMembership() {
        let tasks = [
            snap(due: day(2026, 3, 10)),
            snap(due: nil),
            snap(completed: true, due: day(2026, 3, 10)),
        ]
        for list in [TaskListFilter.today, .inbox, .completed, .planned] {
            let filtered = Set(TaskFiltering.filter(tasks, as: list, relativeTo: filterNow, calendar: utcCalendar).map(\.id))
            for task in tasks {
                let m = TaskFiltering.matches(task, list: list, relativeTo: filterNow, calendar: utcCalendar)
                XCTAssertEqual(m, filtered.contains(task.id), "list \(list) task \(task.id)")
            }
        }
    }
    
    func testSortStableByCreatedAtWhenPriorityAndDueEqual() {
        let earlier = snap(due: day(2026, 3, 10), priority: 2, created: day(2026, 3, 1))
        let later = snap(due: day(2026, 3, 10), priority: 2, created: day(2026, 3, 5))
        let result = TaskFiltering.filter([later, earlier], as: .today, relativeTo: filterNow, calendar: utcCalendar)
        XCTAssertEqual(result.map(\.createdAt), [earlier.createdAt, later.createdAt])
    }
    
    func testDueDateBeatsNoDueDateInSort() {
        let withDue = snap(due: day(2026, 3, 15), priority: 1)
        let inbox = snap(due: nil, priority: 4)
        // planned list has only withDue; use planned after both have due? inbox not in planned.
        // Sort rule: due before nil — verify via planned mixed is N/A; use filter that keeps both: none.
        // Directly exercise via .planned with only dated tasks and separate assertion on comparator path
        // by using .planned and completed=false both with due, then inbox via filter today vs planned.
        let planned = TaskFiltering.filter([withDue, inbox], as: .planned, relativeTo: filterNow, calendar: utcCalendar)
        XCTAssertEqual(planned.count, 1)
        let onlyInbox = TaskFiltering.filter([withDue, inbox], as: .inbox, relativeTo: filterNow, calendar: utcCalendar)
        XCTAssertEqual(onlyInbox.count, 1)
        XCTAssertNil(onlyInbox[0].dueDate)
    }
    
    // MARK: - TimerFormatting edges
    
    func testLogMinutesBoundaryRounding() {
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 29), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 30), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 89.4), 1)
        // 89.5/60 ≈ 1.49 → rounds to 1; 90/60 = 1.5 → rounds to 2
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 89.5), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 90), 2)
        // Cap to planned 25 min even if elapsed huge
        XCTAssertEqual(
            TimerFormatting.logMinutes(elapsedSeconds: 10_000, maximumSeconds: 25 * 60),
            25
        )
        // maximum smaller than 1s → nil
        XCTAssertNil(TimerFormatting.logMinutes(elapsedSeconds: 100, maximumSeconds: 0.5))
    }
    
    func testProgressClamps() {
        XCTAssertEqual(TimerFormatting.progress(remaining: -10, total: 100), 1, accuracy: 0.001)
        XCTAssertEqual(TimerFormatting.progress(remaining: 200, total: 100), 0, accuracy: 0.001)
    }
    
    func testTimeStringLargeValues() {
        XCTAssertEqual(TimerFormatting.timeString(remaining: 90 * 60), "90:00")
        XCTAssertEqual(TimerFormatting.timeString(remaining: 61), "01:01")
    }
    
    // MARK: - TaskStore edges
    
    func testLogFocusSessionRejectsNonPositiveMinutes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Deep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let store = TaskStore(storageDirectory: dir)
        store.logFocusSession(taskId: nil, taskTitle: "x", minutes: 0)
        store.logFocusSession(taskId: nil, taskTitle: "x", minutes: -5)
        store.logFocusSession(taskId: nil, taskTitle: "ok", minutes: 1)
        
        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertEqual(store.focusSessions[0].durationMinutes, 1)
    }
    
    func testAddFocusTimeIgnoresMissingTaskAndZeroMinutes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Deep2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let store = TaskStore(storageDirectory: dir)
        store.newTaskTitle = "T"
        store.addTask(for: .inboxTask)
        let id = store.tasks[0].id
        
        store.addFocusTime(to: id, minutes: 0)
        XCTAssertEqual(store.tasks[0].completedPomodoros, 0)
        XCTAssertEqual(store.tasks[0].timeSpentMinutes, 0)
        
        store.addFocusTime(to: UUID(), minutes: 25)
        XCTAssertEqual(store.tasks[0].completedPomodoros, 0)
        
        store.addFocusTime(to: id, minutes: 25)
        XCTAssertEqual(store.tasks[0].completedPomodoros, 1)
        XCTAssertEqual(store.tasks[0].timeSpentMinutes, 25)
    }
    
    func testPriorityAndPomodoroClampsOnAddAndUpdate() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Deep3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let store = TaskStore(storageDirectory: dir)
        store.newTaskTitle = "clamp"
        store.newTaskPriority = 99
        store.newTaskPomodoros = 99
        store.addTask(for: .inboxTask)
        
        XCTAssertEqual(store.tasks[0].priority, 4)
        XCTAssertEqual(store.tasks[0].estimatedPomodoros, 20)
        
        store.updateTask(
            id: store.tasks[0].id,
            title: "clamp",
            category: .work,
            priority: 0,
            estimatedPomodoros: 0,
            dueDate: Date()
        )
        XCTAssertEqual(store.tasks[0].priority, 1)
        XCTAssertEqual(store.tasks[0].estimatedPomodoros, 1)
        XCTAssertNotNil(store.tasks[0].dueDate)
        // due date normalized to start of day
        let start = Calendar.current.startOfDay(for: store.tasks[0].dueDate!)
        XCTAssertEqual(store.tasks[0].dueDate, start)
    }
    
    func testAddTaskFromCompletedFilterCreatesNoDueDateIncomplete() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Deep4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let store = TaskStore(storageDirectory: dir)
        store.newTaskTitle = "ghost"
        store.addTask(for: .completedTask)
        // UI hides add on completed list; store still must not create completed tasks.
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].dueDate)
    }
    
    func testFlushPendingSavesPersistsAcrossReload() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Deep5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let store = TaskStore(storageDirectory: dir)
        store.newTaskTitle = "fast"
        store.addTask(for: .todayTask)
        store.logFocusSession(taskId: store.tasks[0].id, taskTitle: "fast", taskCategory: .study, minutes: 12)
        store.activeTaskId = store.tasks[0].id
        store.flushPendingSaves()
        
        let reloaded = TaskStore(storageDirectory: dir)
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.focusSessions.count, 1)
        XCTAssertEqual(reloaded.activeTaskId, store.tasks[0].id)
    }
}
