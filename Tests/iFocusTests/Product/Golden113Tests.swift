import XCTest
@testable import iFocus
import iFocusCore

/// Compatibility contract with iFocus 1.13. `Tests/Fixtures/v1.13` holds synthetic 1.13 data
/// files and a backup package; `Tests/Fixtures/golden-1.13` holds what the unmodified 1.13
/// code exported from them (fixed clock, Asia/Shanghai, Monday-first weeks).
final class Golden113Tests: XCTestCase {
    /// Walk up from this file so the fixture root stays valid if the test moves
    /// under `Tests/iFocusTests/<layer>/`.
    static let fixturesRoot: URL = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let manager = FileManager.default
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("Fixtures", isDirectory: true)
            if manager.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        preconditionFailure("Fixtures directory not found above \(#filePath)")
    }()
    static let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    static let fixedNow = ISO8601DateFormatter().date(from: "2026-10-18T12:00:00Z")!

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Golden113-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        for name in ["tasks.json", "focus_sessions.json", "app_state.json"] {
            try FileManager.default.copyItem(
                at: Self.fixturesRoot.appendingPathComponent("v1.13/data/\(name)"),
                to: tempDir.appendingPathComponent(name)
            )
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func goldenText(_ path: String) throws -> String {
        try String(contentsOf: Self.fixturesRoot.appendingPathComponent("golden-1.13/\(path)"), encoding: .utf8)
    }

    func testFixtureDataLoadsCompletely() {
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertNil(store.dataLoadErrorMessage)
        XCTAssertEqual(store.tasks.count, 6)
        XCTAssertEqual(store.focusSessions.count, 12)
        XCTAssertEqual(store.activeTaskId?.uuidString, "00000000-0000-4000-8000-000000000001")
    }

    func testExportMatchesGolden113() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let files = StudyLogExport.files(
            entries: store.focusSessions.map(StudyLogWriter.entry(for:)),
            now: Self.fixedNow,
            calendar: StudyLogExport.weekCalendar(timeZone: Self.shanghai)
        )
        XCTAssertEqual(files["sessions.csv"], try goldenText("sessions.csv"), "sessions.csv must stay byte-identical")
        for week in ["2026-09-28", "2026-10-05", "2026-10-12"] {
            let path = "weeks/\(week).md"
            let actual = try XCTUnwrap(files[path], path)
            let golden = try goldenText(path)
            XCTAssertTrue(actual.hasPrefix(golden), "\(path) must keep its 1.13 content as an exact prefix")
        }
    }

    func testBackupPackageStillValidates() throws {
        let package = LocalBackup.inspect(directory: Self.fixturesRoot.appendingPathComponent("v1.13/backup"))
        XCTAssertTrue(package.isImportable)
        XCTAssertTrue(package.hasSettings)
        XCTAssertNoThrow(try TaskStore.validateBackupPayloads(in: package))
    }

    func testSettingsFixtureImports() throws {
        let suite = "iFocus.Golden113.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        try settings.importSettingsJSON(Data(contentsOf: Self.fixturesRoot.appendingPathComponent("v1.13/data/settings.json")))
        XCTAssertEqual(settings.username, "林画")
        XCTAssertEqual(settings.dailyGoal, 8)
        XCTAssertTrue(settings.countUpWork)
    }
}
