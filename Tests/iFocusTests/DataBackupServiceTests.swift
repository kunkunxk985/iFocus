import AppKit
import XCTest
@testable import iFocus
import iFocusCore

final class DataBackupServiceTests: XCTestCase {
    private var root: URL!
    private var suiteNames: [String] = []

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-DataBackupService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for name in suiteNames {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        suiteNames = []
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    func testRestoreIncludesAvatarSettingsAndPendingTimer() throws {
        let liveDir = try makeDirectory("live")
        let sourceDir = try makeDirectory("source")
        let packageDir = root.appendingPathComponent("package", isDirectory: true)

        let liveSettings = makeSettings("live", avatarDirectory: liveDir)
        liveSettings.username = "当前用户"
        let liveTasks = TaskStore(storageDirectory: liveDir)
        liveTasks.newTaskTitle = "当前任务"
        liveTasks.addTask(for: .inboxTask)
        liveTasks.flushPendingSaves()

        let sourceSettings = makeSettings("source", avatarDirectory: sourceDir)
        sourceSettings.username = "备份用户"
        sourceSettings.workMinutes = 42
        let sourceTasks = TaskStore(storageDirectory: sourceDir)
        sourceTasks.newTaskTitle = "恢复后的任务"
        sourceTasks.addTask(for: .inboxTask)
        sourceTasks.flushPendingSaves()
        let restoredTaskID = try XCTUnwrap(sourceTasks.tasks.first?.id)

        let snapshot = TimerSessionSnapshot(
            mode: TimerMode.work.rawValue,
            timeRemaining: 720,
            isRunning: false,
            elapsedBeforePause: 180,
            sessionPlannedDuration: 1_500,
            activeTaskId: restoredTaskID,
            workTaskTitle: "恢复后的任务",
            workTaskCategory: nil,
            cleanExit: true,
            savedAt: Date()
        )
        TimerSessionPersistence.save(snapshot, to: sourceDir)

        var payloads = sourceTasks.backupFilePayloads()
        payloads[LocalBackup.avatarFileName] = try makePNGData()
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: payloads,
            settingsJSON: try sourceSettings.exportSettingsJSON(),
            manifest: LocalBackup.Manifest(appVersion: "1.9.3")
        )

        let package = LocalBackup.inspect(directory: packageDir)
        let preview = DataBackupService.RestorePreview(
            package: package,
            summary: try LocalBackup.validate(package: package)
        )
        let timer = TimerStore(
            settings: liveSettings,
            taskStore: liveTasks,
            sessionStorageDirectory: liveDir
        )

        let outcome = try DataBackupService.restoreBackup(
            preview,
            taskStore: liveTasks,
            settings: liveSettings,
            timerStore: timer
        ).get()

        XCTAssertEqual(liveTasks.tasks.map(\.title), ["恢复后的任务"])
        XCTAssertEqual(liveSettings.username, "备份用户")
        XCTAssertEqual(liveSettings.workMinutes, 42)
        let avatarPath = try XCTUnwrap(liveSettings.avatarPath)
        XCTAssertNotNil(NSImage(contentsOfFile: avatarPath))
        XCTAssertEqual(timer.pendingResumeSnapshot?.activeTaskId, restoredTaskID)
        XCTAssertEqual(timer.pendingResumeSnapshot?.timeRemaining, 720)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outcome.safetySnapshotDirectory
                .appendingPathComponent(LocalBackup.tasksFileName).path
        ))
    }

    func testModelDecodeFailureLeavesFilesAndSettingsUnchanged() throws {
        let liveDir = try makeDirectory("rollback-live")
        let packageDir = root.appendingPathComponent("bad-package", isDirectory: true)
        let settings = makeSettings("rollback", avatarDirectory: liveDir)
        settings.username = "保留用户"
        let tasks = TaskStore(storageDirectory: liveDir)
        tasks.newTaskTitle = "保留任务"
        tasks.addTask(for: .inboxTask)
        tasks.flushPendingSaves()

        let badSettings = try JSONSerialization.data(
            withJSONObject: ["username": "不应保留", "workMinutes": 59]
        )
        try LocalBackup.writePackage(
            to: packageDir,
            filePayloads: [
                // Structurally valid JSON, but invalid as a FocusTask.
                LocalBackup.tasksFileName: Data(#"[{"unknown":true}]"#.utf8)
            ],
            settingsJSON: badSettings,
            manifest: LocalBackup.Manifest(appVersion: "1.9.3")
        )
        let package = LocalBackup.inspect(directory: packageDir)
        let preview = DataBackupService.RestorePreview(
            package: package,
            summary: try LocalBackup.validate(package: package)
        )
        let timer = TimerStore(
            settings: settings,
            taskStore: tasks,
            sessionStorageDirectory: liveDir
        )

        let result = DataBackupService.restoreBackup(
            preview,
            taskStore: tasks,
            settings: settings,
            timerStore: timer
        )
        if case .success = result {
            XCTFail("Invalid task payload should fail and roll back")
        }
        XCTAssertEqual(tasks.tasks.map(\.title), ["保留任务"])
        XCTAssertEqual(settings.username, "保留用户")
        XCTAssertEqual(settings.workMinutes, 25)
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSettings(_ suffix: String, avatarDirectory: URL) -> SettingsStore {
        let suite = "iFocus.DataBackupServiceTests.\(suffix).\(UUID().uuidString)"
        suiteNames.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(
            defaults: defaults,
            applyAppearance: false,
            avatarStorageDirectory: avatarDirectory
        )
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 24).fill()
        image.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
