import XCTest
@testable import iFocus

final class DeepLinkRouterTests: XCTestCase {
    
    func testParseStartPauseToggleSkipReset() {
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://start")), .start)
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://pause")), .pause)
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://toggle")), .toggle)
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://skip")), .skip)
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://reset")), .reset)
    }
    
    func testParseNavigationShortcuts() {
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://timer")), .open(.timer))
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://analytics")), .open(.analytics))
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://today")), .open(.todayTask))
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://inbox")), .open(.inboxTask))
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://profile")), .open(.profile))
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://settings")), .settings)
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://freefocus")), .freeFocus)
    }
    
    func testParseOpenQueryScreen() {
        XCTAssertEqual(
            DeepLinkRouter.parse(url("ifocus://open?screen=today")),
            .open(.todayTask)
        )
        XCTAssertEqual(
            DeepLinkRouter.parse(url("ifocus://goto?page=analytics")),
            .open(.analytics)
        )
        XCTAssertEqual(
            DeepLinkRouter.parse(url("ifocus://open?screen=week")),
            .open(.weekTask)
        )
    }
    
    func testRejectsUnknownSchemeAndCommand() {
        XCTAssertNil(DeepLinkRouter.parse(url("https://example.com")))
        XCTAssertNil(DeepLinkRouter.parse(url("ifocus://unknown-command")))
    }
    
    func testEmptyHostOpensTimer() {
        // ifocus:// with empty host/path
        XCTAssertEqual(DeepLinkRouter.parse(url("ifocus://")), .open(.timer))
    }
    
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }
}
