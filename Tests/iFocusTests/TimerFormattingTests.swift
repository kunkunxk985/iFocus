import XCTest
@testable import iFocusCore

final class TimerFormattingTests: XCTestCase {
    
    func testTimeStringCeil() {
        XCTAssertEqual(TimerFormatting.timeString(remaining: 0), "00:00")
        XCTAssertEqual(TimerFormatting.timeString(remaining: 0.1), "00:01")
        XCTAssertEqual(TimerFormatting.timeString(remaining: 59.1), "01:00")
        XCTAssertEqual(TimerFormatting.timeString(remaining: 25 * 60), "25:00")
        XCTAssertEqual(TimerFormatting.timeString(remaining: 90), "01:30")
    }
    
    func testElapsedStringCountsUpAndAddsHours() {
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: 0), "00:00")
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: 0.9), "00:00")
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: 61), "01:01")
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: 59 * 60 + 59), "59:59")
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: 3600 + 5 * 60 + 7), "1:05:07")
        XCTAssertEqual(TimerFormatting.elapsedString(seconds: -5), "00:00")
    }

    func testTimeStringClampsNegative() {
        XCTAssertEqual(TimerFormatting.timeString(remaining: -5), "00:00")
    }
    
    func testLogMinutes() {
        XCTAssertNil(TimerFormatting.logMinutes(elapsedSeconds: 0))
        XCTAssertNil(TimerFormatting.logMinutes(elapsedSeconds: 0.5))
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 1), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 30), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 89), 1)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 90), 2)
        XCTAssertEqual(TimerFormatting.logMinutes(elapsedSeconds: 1500), 25)
    }

    func testLogMinutesCapsElapsedTimeAfterLateWake() {
        XCTAssertEqual(
            TimerFormatting.logMinutes(elapsedSeconds: 2 * 60 * 60, maximumSeconds: 25 * 60),
            25
        )
    }
    
    func testProgress() {
        XCTAssertEqual(TimerFormatting.progress(remaining: 1500, total: 1500), 0, accuracy: 0.001)
        XCTAssertEqual(TimerFormatting.progress(remaining: 0, total: 1500), 1, accuracy: 0.001)
        XCTAssertEqual(TimerFormatting.progress(remaining: 750, total: 1500), 0.5, accuracy: 0.001)
        XCTAssertEqual(TimerFormatting.progress(remaining: 10, total: 0), 0, accuracy: 0.001)
    }
}
