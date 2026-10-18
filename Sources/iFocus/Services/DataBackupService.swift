import AppKit
import Foundation
import iFocusCore

/// Quiet one-tap backup: folder of JSON + manifest. No cloud, no accounts.
enum DataBackupService {
    struct RestorePreview: Identifiable, Equatable {
        let id = UUID()
        let package: LocalBackup.Package
        let summary: LocalBackup.ValidationSummary
    }

    struct RestoreOutcome: Equatable {
        let preview: RestorePreview
        let safetySnapshotDirectory: URL
    }

    static func exportBackup(
        taskStore: TaskStore,
        settings: SettingsStore,
        appVersion: String
    ) -> Result<URL, Error> {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "导出到此位置"
        panel.message = "将创建一个备份文件夹（任务、专注记录与偏好）。"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)

        guard panel.runModal() == .OK, let parent = panel.url else {
            return .failure(CancelError())
        }

        let folderName = LocalBackup.suggestedFolderName()
        let destination = uniqueDirectory(in: parent, preferredName: folderName)

        do {
            var payloads = taskStore.backupFilePayloads()
            if let avatarPath = settings.avatarPath {
                let avatarURL = URL(fileURLWithPath: avatarPath)
                if let avatarData = try? Data(contentsOf: avatarURL),
                   NSImage(data: avatarData) != nil {
                    payloads[LocalBackup.avatarFileName] = avatarData
                }
            }
            let settingsData = try settings.exportSettingsJSON()
            let taskCount = (try? JSONSerialization.jsonObject(with: payloads[LocalBackup.tasksFileName] ?? Data("[]".utf8)))
                .flatMap { ($0 as? [Any])?.count }
            let sessionCount = (try? JSONSerialization.jsonObject(with: payloads[LocalBackup.sessionsFileName] ?? Data("[]".utf8)))
                .flatMap { ($0 as? [Any])?.count }

            let manifest = LocalBackup.Manifest(
                appVersion: appVersion,
                taskCount: taskCount,
                sessionCount: sessionCount
            )
            try LocalBackup.writePackage(
                to: destination,
                filePayloads: payloads,
                settingsJSON: settingsData,
                manifest: manifest
            )
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            return .success(destination)
        } catch {
            return .failure(error)
        }
    }

    static func selectBackup() -> Result<RestorePreview, Error> {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择备份文件夹"
        panel.message = "选择 iFocus 备份文件夹。确认内容后才会覆盖当前数据。"

        guard panel.runModal() == .OK, let directory = panel.url else {
            return .failure(CancelError())
        }

        let package = LocalBackup.inspect(directory: directory)
        guard package.isImportable else {
            return .failure(LocalBackup.BackupError.notABackup)
        }

        do {
            let summary = try LocalBackup.validate(package: package)
            try TaskStore.validateBackupPayloads(in: package)
            if package.hasAvatar {
                let avatarURL = package.directory.appendingPathComponent(LocalBackup.avatarFileName)
                let data = try Data(contentsOf: avatarURL)
                guard NSImage(data: data) != nil else {
                    throw LocalBackup.BackupError.invalidFile(LocalBackup.avatarFileName)
                }
            }
            return .success(RestorePreview(package: package, summary: summary))
        } catch {
            return .failure(error)
        }
    }

    static func restoreBackup(
        _ preview: RestorePreview,
        taskStore: TaskStore,
        settings: SettingsStore,
        timerStore: TimerStore
    ) -> Result<RestoreOutcome, Error> {
        var receipt: LocalBackup.RestoreReceipt?
        var installedAvatarURL: URL?
        var originalSettingsData: Data?
        var didBeginRestore = false
        let originalAvatarPath = settings.avatarPath
        let activeTimerSnapshot = timerStore.isSessionInProgress
            ? timerStore.makeSessionSnapshot(cleanExit: true)
            : nil

        do {
            // Validate again because a selected backup folder may have changed while the alert was open.
            _ = try LocalBackup.validate(package: preview.package)
            try TaskStore.validateBackupPayloads(in: preview.package)
            originalSettingsData = try settings.exportSettingsJSON()
            let incomingSettings: Data?
            if preview.package.hasSettings {
                incomingSettings = try Data(
                    contentsOf: preview.package.directory.appendingPathComponent(LocalBackup.settingsFileName)
                )
            } else {
                incomingSettings = nil
            }
            let incomingAvatar: Data?
            if preview.package.hasAvatar {
                incomingAvatar = try Data(
                    contentsOf: preview.package.directory.appendingPathComponent(LocalBackup.avatarFileName)
                )
            } else {
                incomingAvatar = nil
            }
            if let incomingAvatar, NSImage(data: incomingAvatar) == nil {
                throw LocalBackup.BackupError.invalidFile(LocalBackup.avatarFileName)
            }

            taskStore.flushPendingSaves()
            timerStore.reset()
            timerStore.pendingResumeSnapshot = nil
            didBeginRestore = true

            let restoreReceipt = try LocalBackup.restoreDataFiles(
                from: preview.package,
                into: taskStore.storageDirectory
            )
            receipt = restoreReceipt

            if let incomingSettings {
                try settings.importSettingsJSON(incomingSettings)
            }
            if let incomingAvatar {
                let destination = taskStore.storageDirectory.appendingPathComponent(
                    "avatar-restored-\(UUID().uuidString).png"
                )
                try incomingAvatar.write(to: destination, options: .atomic)
                installedAvatarURL = destination
                settings.avatarPath = destination.path
            }

            guard taskStore.reloadFromDisk() else {
                throw LocalBackup.BackupError.readFailed("恢复后数据仍无法读取")
            }
            timerStore.reloadPendingResumeFromDisk()
            // Imported settings may change the work length or count-up; the timer was reset above.
            timerStore.syncDurationFromSettingsIfIdle()

            if let originalAvatarPath,
               originalAvatarPath != settings.avatarPath,
               isOwnedAvatar(path: originalAvatarPath, storageDirectory: taskStore.storageDirectory) {
                try? FileManager.default.removeItem(atPath: originalAvatarPath)
            }
            return .success(
                RestoreOutcome(
                    preview: preview,
                    safetySnapshotDirectory: restoreReceipt.snapshotDirectory
                )
            )
        } catch {
            let originalError = error
            if let installedAvatarURL {
                try? FileManager.default.removeItem(at: installedAvatarURL)
            }
            if didBeginRestore {
                settings.avatarPath = originalAvatarPath
            }

            do {
                if didBeginRestore {
                    if let receipt {
                        try LocalBackup.rollbackRestore(receipt, into: taskStore.storageDirectory)
                    }
                    if let originalSettingsData {
                        try settings.importSettingsJSON(originalSettingsData)
                    }
                    _ = taskStore.reloadFromDisk()
                    if let activeTimerSnapshot {
                        TimerSessionPersistence.save(activeTimerSnapshot, to: taskStore.storageDirectory)
                    }
                    timerStore.reloadPendingResumeFromDisk()
                    timerStore.syncDurationFromSettingsIfIdle()
                }
            } catch {
                return .failure(LocalBackup.BackupError.rollbackFailed(error.localizedDescription))
            }
            return .failure(originalError)
        }
    }

    private static func uniqueDirectory(in parent: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        let url = parent.appendingPathComponent(preferredName, isDirectory: true)
        if !fm.fileExists(atPath: url.path) { return url }
        var index = 2
        while true {
            let candidate = parent.appendingPathComponent("\(preferredName)-\(index)", isDirectory: true)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func isOwnedAvatar(path: String, storageDirectory: URL) -> Bool {
        let avatarURL = URL(fileURLWithPath: path).standardizedFileURL
        let storagePath = storageDirectory.standardizedFileURL.path + "/"
        return avatarURL.path.hasPrefix(storagePath)
    }

    struct CancelError: Error, LocalizedError {
        var errorDescription: String? { "已取消" }
    }
}
