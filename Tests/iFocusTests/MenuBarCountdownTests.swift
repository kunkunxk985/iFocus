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
            isSessionInProgress: true
        )
        XCTAssertEqual(running.trimmingCharacters(in: .whitespaces), "24:59")
        
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
}
