import XCTest
@testable import iFocus

final class AppUpdateCheckerTests: XCTestCase {
    func testNewerReleaseIgnoresLeadingV() {
        XCTAssertTrue(AppUpdateChecker.isNewerRelease("v1.14.9", than: "1.14.8"))
        XCTAssertFalse(AppUpdateChecker.isNewerRelease("v1.14.8", than: "1.14.8"))
        XCTAssertFalse(AppUpdateChecker.isNewerRelease("1.14.7", than: "1.14.8"))
    }

    func testShorterVersionStillCompares() {
        XCTAssertTrue(AppUpdateChecker.isNewerRelease("1.15", than: "1.14.8"))
        XCTAssertEqual(AppUpdateChecker.displayVersion("v1.14.8+114"), "1.14.8")
    }

    func testPreferredPackageUsesNamedZip() {
        let named = URL(string: "https://example.com/iFocus.zip")!
        let other = URL(string: "https://example.com/other.zip")!
        let assets = [
            AppUpdateChecker.ReleaseAsset(name: "notes.txt", downloadURL: URL(string: "https://example.com/notes.txt")!),
            AppUpdateChecker.ReleaseAsset(name: "extra.zip", downloadURL: other),
            AppUpdateChecker.ReleaseAsset(name: "iFocus.zip", downloadURL: named)
        ]
        XCTAssertEqual(AppUpdateChecker.preferredPackage(among: assets), named)
    }
}
