import XCTest
@testable import iFocusCore

final class TaskSearchTests: XCTestCase {
    func testEmptyOrWhitespaceQueryMatchesAll() {
        XCTAssertTrue(TaskSearch.matches("", in: []))
        XCTAssertTrue(TaskSearch.matches("  \n\t", in: ["anything"]))
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        XCTAssertTrue(TaskSearch.matches("resume", in: ["Résumé draft"]))
        XCTAssertTrue(TaskSearch.matches("SWIFT", in: ["Learn SwiftUI"]))
    }

    func testEveryQueryTokenMayMatchDifferentFields() {
        XCTAssertTrue(TaskSearch.matches("report design", in: ["Design review", "Quarterly report"]))
        XCTAssertFalse(TaskSearch.matches("report finance", in: ["Design review", "Quarterly report"]))
    }

    func testLocalizedSubstringAndWhitespace() {
        XCTAssertTrue(TaskSearch.matches("  番茄钟  备注 ", in: ["完成番茄钟原型", "备注：检查恢复流程"]))
        XCTAssertFalse(TaskSearch.matches("专注", in: ["规划清单"]))
    }
}
