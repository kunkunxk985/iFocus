import XCTest
@testable import iFocus
@testable import iFocusCore

final class StudyPlanTests: XCTestCase {
    private var tempDir: URL!

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-StudyPlanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return utcCalendar.date(from: components)!
    }

    func testDefaultStartDateAlwaysResolvesToMonday() {
        XCTAssertTrue(utcCalendar.isDate(
            PlanTemplates.defaultStartMonday(today: day(2026, 3, 11), calendar: utcCalendar),
            inSameDayAs: day(2026, 3, 9)
        ))
        XCTAssertTrue(utcCalendar.isDate(
            PlanTemplates.defaultStartMonday(today: day(2026, 3, 15), calendar: utcCalendar),
            inSameDayAs: day(2026, 3, 16)
        ))
        XCTAssertTrue(utcCalendar.isDate(
            PlanTemplates.monday(onOrBefore: day(2026, 3, 12), calendar: utcCalendar),
            inSameDayAs: day(2026, 3, 9)
        ))
    }

    func testAcceleratedRouteHasExpectedWeeksAndDailyPractice() {
        let start = day(2026, 3, 9)
        let drafts = PlanTemplates.accelerated4Weeks(startMonday: start, calendar: utcCalendar)
        XCTAssertEqual(drafts.count, 10)

        let linalg = try! XCTUnwrap(drafts.first { $0.planKey == "accel.linalg" })
        XCTAssertEqual(linalg.items.count, 16)
        XCTAssertEqual(linalg.unit, "集")
        XCTAssertTrue(utcCalendar.isDate(linalg.startDate!, inSameDayAs: day(2026, 3, 9)))
        XCTAssertTrue(utcCalendar.isDate(linalg.dueDate!, inSameDayAs: day(2026, 3, 15)))

        let weekFour = try! XCTUnwrap(drafts.first { $0.planKey == "accel.nn2" })
        XCTAssertTrue(utcCalendar.isDate(weekFour.startDate!, inSameDayAs: day(2026, 3, 30)))
        XCTAssertTrue(utcCalendar.isDate(weekFour.dueDate!, inSameDayAs: day(2026, 4, 5)))

        let daily = try! XCTUnwrap(drafts.first { $0.planKey == "accel.leetcode" })
        XCTAssertTrue(daily.repeatsDaily)
        XCTAssertNil(daily.startDate)
        XCTAssertTrue(drafts.allSatisfy { !$0.planKey.isEmpty })
    }

    func testChecklistProgressAndPaceCopy() {
        let items = [
            ChecklistItem(title: "第 1 集", doneAt: day(2026, 3, 10)),
            ChecklistItem(title: "第 2 集"),
            ChecklistItem(title: "第 3 集")
        ]
        XCTAssertEqual(ChecklistProgress.done(items), 1)
        XCTAssertEqual(ChecklistProgress.nextUnchecked(items, limit: 1).map(\.title), ["第 2 集"])
        XCTAssertEqual(ChecklistProgress.nextUnchecked(items, limit: 0), [])
        XCTAssertEqual(
            ChecklistProgress.paceText(done: 1, total: 3, unit: "集", due: day(2026, 3, 11), today: day(2026, 3, 10), calendar: utcCalendar),
            "还剩 2 集 · 每天 1 集就能按时完成"
        )
        XCTAssertEqual(
            ChecklistProgress.paceText(done: 3, total: 3, unit: "集", due: nil, today: day(2026, 3, 10), calendar: utcCalendar),
            "全部完成"
        )
    }

    func testLegacyTaskJSONDefaultsNewStudyFields() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"旧版任务","category":"学习"}
        """
        let task = try JSONDecoder().decode(FocusTask.self, from: Data(json.utf8))
        XCTAssertEqual(task.id, id)
        XCTAssertEqual(task.title, "旧版任务")
        XCTAssertTrue(task.checklist.isEmpty)
        XCTAssertNil(task.itemUnit)
        XCTAssertNil(task.startDate)
        XCTAssertNil(task.planKey)
        XCTAssertNil(task.completedAt)
        XCTAssertFalse(task.isPaced)
    }

    func testStartDateControlsTodayAndTomorrowListsWithoutOverdueBadge() {
        let now = day(2026, 3, 10)
        let started = TaskSnapshot(
            isCompleted: false,
            dueDate: day(2026, 3, 8),
            createdAt: day(2026, 3, 1),
            startDate: day(2026, 3, 10),
            isPaced: true
        )
        let future = TaskSnapshot(
            dueDate: day(2026, 3, 18),
            createdAt: day(2026, 3, 1),
            startDate: day(2026, 3, 11),
            isPaced: true
        )
        XCTAssertTrue(TaskFiltering.matches(started, list: .today, relativeTo: now, calendar: utcCalendar))
        XCTAssertFalse(TaskFiltering.matches(started, list: .tomorrow, relativeTo: now, calendar: utcCalendar))
        XCTAssertFalse(TaskFiltering.matches(future, list: .today, relativeTo: now, calendar: utcCalendar))
        XCTAssertTrue(TaskFiltering.matches(future, list: .planned, relativeTo: now, calendar: utcCalendar))
        XCTAssertEqual(TaskFiltering.sidebarBadgeCounts([started], relativeTo: now, calendar: utcCalendar).overdue, 0)
    }

    func testPlanImportIsIdempotentAndPreservesChecklistProgressAcrossReload() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let start = day(2026, 3, 9)
        let first = store.importAcceleratedStudyPlan(startMonday: start, calendar: utcCalendar)
        XCTAssertEqual(first.addedCount, 10)
        XCTAssertEqual(first.skippedCount, 0)
        XCTAssertEqual(store.tasks.count, 10)

        let linalg = try XCTUnwrap(store.tasks.first { $0.planKey == "accel.linalg" })
        XCTAssertEqual(linalg.category, .study)
        XCTAssertEqual(linalg.checklist.count, 16)
        XCTAssertEqual(linalg.unitLabel, "集")
        XCTAssertTrue(utcCalendar.isDate(linalg.startDate!, inSameDayAs: day(2026, 3, 9)))

        store.toggleChecklistItem(taskID: linalg.id, itemID: linalg.checklist[0].id, at: day(2026, 3, 10))
        store.toggleChecklistFlag(taskID: linalg.id, itemID: linalg.checklist[1].id)
        store.updateTask(
            id: linalg.id,
            title: "我自己的课程标题",
            category: .study,
            priority: 2,
            estimatedPomodoros: 1,
            dueDate: linalg.dueDate,
            recurrence: .none,
            notes: "已写下笔记",
            linkURL: "",
            items: store.tasks.first(where: { $0.id == linalg.id })?.checklist,
            itemUnit: "集",
            startDate: linalg.startDate
        )

        let second = store.importAcceleratedStudyPlan(startMonday: day(2026, 3, 16), calendar: utcCalendar)
        XCTAssertEqual(second.addedCount, 0)
        XCTAssertEqual(second.skippedCount, 10)
        XCTAssertEqual(store.tasks.count, 10)

        store.flushPendingSaves()
        let reloaded = TaskStore(storageDirectory: tempDir)
        let restored = try XCTUnwrap(reloaded.tasks.first { $0.planKey == "accel.linalg" })
        XCTAssertEqual(restored.title, "我自己的课程标题")
        XCTAssertEqual(restored.notes, "已写下笔记")
        XCTAssertEqual(restored.checklist[0].doneAt, day(2026, 3, 10))
        XCTAssertTrue(restored.checklist[1].isFlagged)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: try XCTUnwrap(restored.startDate)),
            Calendar.current.startOfDay(for: try XCTUnwrap(linalg.startDate))
        )
    }

    func testChecklistCompletesParentAndCanReopenIt() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let first = ChecklistItem(title: "第一项")
        let second = ChecklistItem(title: "第二项")
        let task = FocusTask(title: "章节学习", category: .study, items: [first, second], itemUnit: "章")
        store.tasks = [task]

        store.toggleChecklistItem(taskID: task.id, itemID: first.id, at: day(2026, 3, 10))
        XCTAssertFalse(store.tasks[0].isCompleted)
        store.toggleChecklistItem(taskID: task.id, itemID: second.id, at: day(2026, 3, 11))
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertEqual(store.tasks[0].completedAt, day(2026, 3, 11))

        store.toggleChecklistItem(taskID: task.id, itemID: second.id, at: day(2026, 3, 12))
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testOverdueDailyRouteTaskSpawnsNextOccurrenceAfterToday() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let today = Calendar.current.startOfDay(for: Date())
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today)!
        let monday = PlanTemplates.monday(onOrBefore: twoWeeksAgo, calendar: .current)
        _ = store.importAcceleratedStudyPlan(startMonday: monday)
        let daily = try XCTUnwrap(store.tasks.first { $0.planKey == "accel.leetcode" })

        store.toggleCompletion(for: daily)
        let next = try XCTUnwrap(store.tasks.first { $0.title == daily.title && $0.planKey == daily.planKey && !$0.isCompleted })
        XCTAssertEqual(next.planKey, "accel.leetcode")
        XCTAssertTrue(Calendar.current.isDateInTomorrow(next.dueDate!))

        let reimported = store.importAcceleratedStudyPlan(startMonday: monday)
        XCTAssertEqual(reimported.addedCount, 0)
        XCTAssertEqual(reimported.skippedCount, 10)
        XCTAssertEqual(store.tasks.filter { $0.planKey == "accel.leetcode" }.count, 2)
    }
}
