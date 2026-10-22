import XCTest
import iFocusCore

final class LocalBackupTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-LocalBackup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testSuggestedFolderNameFormat() {
        let name = LocalBackup.suggestedFolderName(
            date: Date(timeIntervalSince1970: 1_720_000_000),
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertTrue(name.hasPrefix("iFocus-Backup-"))
        XCTAssertEqual(name.count, "iFocus-Backup-YYYY-MM-DD".count)
    }

    func testWriteInspectAndRestoreRoundTrip() throws {
        let packageDir = tempDir.appendingPathComponent("pkg", isDirectory: true)
        let liveDir = tempDir.appendingPathComponent("live", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDir, withIntermediateDirectories: true)

        let tasks = Data(#"[{"id":"00000000-0000-0000-0000-000000000001"}]"#.utf8)
        let sessions = Data("[]".utf8)
        let state = Data(#"{"activeTaskId":null}"#.utf8)
        let settings = Data(#"{"dailyGoal":8}"#.utf8)

        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [
                LocalBackup.tasksFileName: tasks,
                LocalBackup.sessionsFileName: sessions,
                LocalBackup.stateFileName: state
            ],
            settingsJSON: settings,
            manifest: LocalBackup.Manifest(
                appVersion: "1.8.0",
                taskCount: 1,
                sessionCount: 0
            )
        )

        let package = LocalBackup.inspect(directory: packageDir)
        XCTAssertTrue(package.isImportable)
        XCTAssertTrue(package.hasSettings)
        XCTAssertEqual(package.manifest?.appVersion, "1.8.0")
        XCTAssertEqual(package.manifest?.taskCount, 1)

        // Seed live with different content, then restore
        try Data("[]".utf8).write(to: liveDir.appendingPathComponent(LocalBackup.tasksFileName))
        let snapshot = try LocalBackup.snapshotLiveData(storageDirectory: liveDir)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: snapshot.appendingPathComponent(LocalBackup.tasksFileName).path
        ))

        try LocalBackup.restoreDataFiles(from: package, into: liveDir)
        let restored = try Data(contentsOf: liveDir.appendingPathComponent(LocalBackup.tasksFileName))
        XCTAssertEqual(restored, tasks)
    }

    func testEmptyPackageNotImportable() {
        let empty = tempDir.appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let package = LocalBackup.inspect(directory: empty)
        XCTAssertFalse(package.isImportable)
    }

    func testRestoreDoesNotDeleteUnlistedLiveFiles() throws {
        let packageDir = tempDir.appendingPathComponent("pkg2", isDirectory: true)
        let liveDir = tempDir.appendingPathComponent("live2", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDir, withIntermediateDirectories: true)

        // Live has all three; package only ships tasks.
        try Data(#"[{"old":true}]"#.utf8).write(to: liveDir.appendingPathComponent(LocalBackup.tasksFileName))
        try Data(#"[{"session":1}]"#.utf8).write(to: liveDir.appendingPathComponent(LocalBackup.sessionsFileName))
        try Data(#"{"keep":true}"#.utf8).write(to: liveDir.appendingPathComponent(LocalBackup.stateFileName))

        let newTasks = Data(#"[{"new":true}]"#.utf8)
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [LocalBackup.tasksFileName: newTasks],
            settingsJSON: nil,
            manifest: LocalBackup.Manifest(appVersion: "1.9.1", taskCount: 1, sessionCount: 0)
        )
        let package = LocalBackup.inspect(directory: packageDir)
        XCTAssertTrue(package.isImportable)
        XCTAssertEqual(package.presentDataFiles, [LocalBackup.tasksFileName])

        _ = try LocalBackup.snapshotLiveData(storageDirectory: liveDir)
        try LocalBackup.restoreDataFiles(from: package, into: liveDir)

        XCTAssertEqual(
            try Data(contentsOf: liveDir.appendingPathComponent(LocalBackup.tasksFileName)),
            newTasks
        )
        // Sessions / state not in package — left as-is (import is merge-by-file, not wipe).
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: liveDir.appendingPathComponent(LocalBackup.sessionsFileName).path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: liveDir.appendingPathComponent(LocalBackup.stateFileName).path
        ))
    }

    func testValidationIncludesTimerAvatarAndUsesActualCounts() throws {
        let packageDir = tempDir.appendingPathComponent("complete", isDirectory: true)
        let timer = Data(#"{"mode":"专注","timeRemaining":600}"#.utf8)
        let avatar = Data([0x89, 0x50, 0x4E, 0x47])
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [
                LocalBackup.tasksFileName: Data("[{},{}]".utf8),
                LocalBackup.sessionsFileName: Data("[{}]".utf8),
                LocalBackup.stateFileName: Data("{}".utf8),
                LocalBackup.timerSessionFileName: timer,
                LocalBackup.avatarFileName: avatar
            ],
            settingsJSON: Data("{}".utf8),
            manifest: LocalBackup.Manifest(appVersion: "1.9.3", taskCount: 99, sessionCount: 99)
        )

        let package = LocalBackup.inspect(directory: packageDir)
        let summary = try LocalBackup.validate(package: package)
        XCTAssertEqual(summary.taskCount, 2)
        XCTAssertEqual(summary.sessionCount, 1)
        XCTAssertTrue(summary.hasSettings)
        XCTAssertTrue(summary.hasTimerSession)
        XCTAssertTrue(summary.hasAvatar)
    }

    func testInvalidJSONIsRejectedBeforeLiveDataChanges() throws {
        let packageDir = tempDir.appendingPathComponent("invalid", isDirectory: true)
        let liveDir = tempDir.appendingPathComponent("invalid-live", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: liveDir, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: packageDir.appendingPathComponent(LocalBackup.tasksFileName))
        let original = Data(#"[{"safe":true}]"#.utf8)
        try original.write(to: liveDir.appendingPathComponent(LocalBackup.tasksFileName))

        let package = LocalBackup.inspect(directory: packageDir)
        XCTAssertThrowsError(try LocalBackup.restoreDataFiles(from: package, into: liveDir))
        XCTAssertEqual(
            try Data(contentsOf: liveDir.appendingPathComponent(LocalBackup.tasksFileName)),
            original
        )
    }

    func testRestoreReceiptCanRollbackAllChangedFiles() throws {
        let packageDir = tempDir.appendingPathComponent("rollback", isDirectory: true)
        let liveDir = tempDir.appendingPathComponent("rollback-live", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDir, withIntermediateDirectories: true)
        let originalTasks = Data(#"[{"old":true}]"#.utf8)
        try originalTasks.write(to: liveDir.appendingPathComponent(LocalBackup.tasksFileName))
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [
                LocalBackup.tasksFileName: Data(#"[{"new":true}]"#.utf8),
                LocalBackup.timerSessionFileName: Data("{}".utf8)
            ],
            settingsJSON: nil,
            manifest: LocalBackup.Manifest(appVersion: "1.9.3")
        )

        let receipt = try LocalBackup.restoreDataFiles(
            from: LocalBackup.inspect(directory: packageDir),
            into: liveDir
        )
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: liveDir.appendingPathComponent(LocalBackup.timerSessionFileName).path
        ))

        try LocalBackup.rollbackRestore(receipt, into: liveDir)
        XCTAssertEqual(
            try Data(contentsOf: liveDir.appendingPathComponent(LocalBackup.tasksFileName)),
            originalTasks
        )
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: liveDir.appendingPathComponent(LocalBackup.timerSessionFileName).path
        ))
    }

    func testFutureBackupFormatIsRejected() throws {
        let packageDir = tempDir.appendingPathComponent("future", isDirectory: true)
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [LocalBackup.tasksFileName: Data("[]".utf8)],
            settingsJSON: nil,
            manifest: LocalBackup.Manifest(formatVersion: 999, appVersion: "99.0")
        )
        XCTAssertThrowsError(try LocalBackup.validate(package: LocalBackup.inspect(directory: packageDir))) {
            XCTAssertEqual($0 as? LocalBackup.BackupError, .unsupportedFormat(999))
        }
    }
}
