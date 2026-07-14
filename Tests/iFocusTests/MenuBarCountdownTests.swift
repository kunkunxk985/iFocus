import XCTest
@testable import iFocus

final class MenuBarCountdownTests: XCTestCase {
    
    func testBarTitleAlwaysShowsTimeFirst() {
        let idle = MenuBarController.barTitle(
            timeString: "25:00",
            mode: .work,
            isRunning: false,
            isSessionInProgress: false
        )
        XCTAssertTrue(idle.contains("25:00"))
        
        let running = MenuBarController.barTitle(
            timeString: "24:59",
            mode: .work,
            isRunning: true,
            isSessionInProgress: true,
            completed: 3,
            goal: 8
        )
        XCTAssertTrue(running.contains("24:59"))
        
        let progress = MenuBarController.barTitle(
            timeString: "24:59",
            mode: .work,
            isRunning: true,
            isSessionInProgress: true,
            completed: 3,
            goal: 8,
            displayStyle: .iconProgress
        )
        XCTAssertTrue(progress.contains("3/8"))
        
        let iconOnly = MenuBarController.barTitle(
            timeString: "25:00",
            mode: .work,
            isRunning: false,
            isSessionInProgress: false,
            displayStyle: .iconOnly
        )
        XCTAssertEqual(iconOnly, "")
        
        let paused = MenuBarController.barTitle(
            timeString: "12:34",
            mode: .work,
            isRunning: false,
            isSessionInProgress: true
        )
        XCTAssertTrue(paused.contains("12:34"))
        XCTAssertTrue(paused.contains("⏸"))
    }
    
    func testAttributedTitleNonEmpty() {
        let text = MenuBarController.barTitle(
            timeString: "05:00",
            mode: .shortBreak,
            isRunning: true,
            isSessionInProgress: true
        )
        let attr = MenuBarController.attributedBarTitle(
            text,
            mode: .shortBreak,
            isRunning: true,
            isSessionInProgress: true
        )
        XCTAssertEqual(attr.string, text)
        XCTAssertGreaterThan(attr.length, 0)
    }

    func testToggleAndRunStateLabels() {
        XCTAssertEqual(MenuBarController.toggleTitle(mode: .work, isRunning: false), "开始专注")
        XCTAssertEqual(MenuBarController.toggleTitle(mode: .work, isRunning: true), "暂停专注")
        XCTAssertEqual(MenuBarController.toggleTitle(mode: .shortBreak, isRunning: true), "暂停休息")
        XCTAssertEqual(
            MenuBarController.runStateLabel(isRunning: true, isSessionInProgress: true, pauseIdleTooLong: false),
            "进行中"
        )
        XCTAssertEqual(
            MenuBarController.runStateLabel(isRunning: false, isSessionInProgress: true, pauseIdleTooLong: true),
            "暂停过久"
        )
        XCTAssertEqual(
            MenuBarController.runStateLabel(isRunning: false, isSessionInProgress: false, pauseIdleTooLong: false),
            "待开始"
        )
    }

    func testModeImageRenders() {
        let idle = MenuBarController.modeImage(for: .work, isRunning: false)
        let work = MenuBarController.modeImage(for: .work, isRunning: true)
        let brk = MenuBarController.modeImage(for: .shortBreak, isRunning: true)
        XCTAssertEqual(idle.size.width, 18)
        XCTAssertEqual(work.size.width, 18)
        XCTAssertEqual(brk.size.width, 18)
    }
}
