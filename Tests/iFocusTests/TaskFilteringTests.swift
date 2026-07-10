import XCTest
@testable import iFocusCore

final class TaskFilteringTests: XCTestCase {
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return calendar.date(from: c)!
    }
    
    private let now = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 10; c.hour = 12
        return cal.date(from: c)!
    }()
    
    private func task(
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
    
    func testTodayIncludesTodayAndOverdue() {
        let tasks = [
            task(due: day(2026, 3, 10)),           // today
            task(due: day(2026, 3, 8)),            // overdue
            task(due: day(2026, 3, 11)),           // tomorrow — exclude
            task(due: nil),                         // inbox — exclude
            task(completed: true, due: day(2026, 3, 10)),
        ]
        let result = TaskFiltering.filter(tasks, as: .today, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 2)
        // Overdue first
        XCTAssertEqual(calendar.startOfDay(for: result[0].dueDate!), calendar.startOfDay(for: day(2026, 3, 8)))
    }
    
    func testTomorrowOnly() {
        let tasks = [
            task(due: day(2026, 3, 11)),
            task(due: day(2026, 3, 10)),
            task(due: day(2026, 3, 12)),
        ]
        let result = TaskFiltering.filter(tasks, as: .tomorrow, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 1)
    }
    
    func testInboxHasNoDueDate() {
        let tasks = [
            task(due: nil),
            task(due: day(2026, 3, 10)),
            task(completed: true, due: nil),
        ]
        let result = TaskFiltering.filter(tasks, as: .inbox, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result[0].dueDate)
    }
    
    func testCompletedList() {
        let tasks = [
            task(completed: true, due: day(2026, 3, 1)),
            task(completed: false, due: day(2026, 3, 10)),
        ]
        let result = TaskFiltering.filter(tasks, as: .completed, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isCompleted)
    }
    
    func testPlannedRequiresDueDate() {
        let tasks = [
            task(due: day(2026, 3, 15)),
            task(due: nil),
            task(completed: true, due: day(2026, 3, 15)),
        ]
        let result = TaskFiltering.filter(tasks, as: .planned, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 1)
    }
    
    func testWeekExcludesTodayAndTomorrow() {
        let tasks = [
            task(due: day(2026, 3, 10)), // today
            task(due: day(2026, 3, 11)), // tomorrow
            task(due: day(2026, 3, 12)), // week
            task(due: day(2026, 3, 17)), // week end
            task(due: day(2026, 3, 18)), // beyond weekLater
        ]
        let result = TaskFiltering.filter(tasks, as: .week, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.count, 2)
    }
    
    func testSortsByPriorityWhenSameDue() {
        let tasks = [
            task(due: day(2026, 3, 10), priority: 1, created: day(2026, 3, 1)),
            task(due: day(2026, 3, 10), priority: 4, created: day(2026, 3, 2)),
        ]
        let result = TaskFiltering.filter(tasks, as: .today, relativeTo: now, calendar: calendar)
        XCTAssertEqual(result.first?.priority, 4)
    }
    
    func testIsOverdue() {
        XCTAssertTrue(
            TaskFiltering.isOverdue(
                dueDate: day(2026, 3, 9),
                isCompleted: false,
                relativeTo: now,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            TaskFiltering.isOverdue(
                dueDate: day(2026, 3, 10),
                isCompleted: false,
                relativeTo: now,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            TaskFiltering.isOverdue(
                dueDate: day(2026, 3, 1),
                isCompleted: true,
                relativeTo: now,
                calendar: calendar
            )
        )
    }
}
