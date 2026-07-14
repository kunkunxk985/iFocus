import Foundation

/// Quiet local backup package — folder of JSON files + manifest.
/// No cloud, no zip dependency: copy-friendly for AirDrop / Time Machine / USB.
public enum LocalBackup {
    public static let formatVersion = 1
    public static let manifestFileName = "manifest.json"
    public static let settingsFileName = "settings.json"
    public static let tasksFileName = "tasks.json"
    public static let sessionsFileName = "focus_sessions.json"
    public static let stateFileName = "app_state.json"
    public static let timerSessionFileName = "timer_session.json"
    public static let avatarFileName = "avatar.png"

    public static let dataFileNames: [String] = [
        tasksFileName,
        sessionsFileName,
        stateFileName,
        timerSessionFileName
    ]

    public static let packageFileNames: Set<String> = Set(
        dataFileNames + [settingsFileName, avatarFileName]
    )

    public struct Manifest: Codable, Equatable {
        public var formatVersion: Int
        public var appVersion: String
        public var exportedAt: Date
        public var taskCount: Int?
        public var sessionCount: Int?

        public init(
            formatVersion: Int = LocalBackup.formatVersion,
            appVersion: String,
            exportedAt: Date = Date(),
            taskCount: Int? = nil,
            sessionCount: Int? = nil
        ) {
            self.formatVersion = formatVersion
            self.appVersion = appVersion
            self.exportedAt = exportedAt
            self.taskCount = taskCount
            self.sessionCount = sessionCount
        }
    }

    public struct Package: Equatable {
        public var directory: URL
        public var manifest: Manifest?
        public var presentDataFiles: [String]
        public var hasSettings: Bool
        public var hasAvatar: Bool

        public var isImportable: Bool {
            presentDataFiles.contains(LocalBackup.tasksFileName)
                || presentDataFiles.contains(LocalBackup.sessionsFileName)
        }
    }

    public struct ValidationSummary: Equatable {
        public var taskCount: Int?
        public var sessionCount: Int?
        public var hasSettings: Bool
        public var hasTimerSession: Bool
        public var hasAvatar: Bool

        public init(
            taskCount: Int?,
            sessionCount: Int?,
            hasSettings: Bool,
            hasTimerSession: Bool,
            hasAvatar: Bool
        ) {
            self.taskCount = taskCount
            self.sessionCount = sessionCount
            self.hasSettings = hasSettings
            self.hasTimerSession = hasTimerSession
            self.hasAvatar = hasAvatar
        }
    }

    public struct RestoreReceipt: Equatable {
        public var snapshotDirectory: URL
        public var restoredFileNames: [String]
        public var previouslyExistingFileNames: Set<String>

        public init(
            snapshotDirectory: URL,
            restoredFileNames: [String],
            previouslyExistingFileNames: Set<String>
        ) {
            self.snapshotDirectory = snapshotDirectory
            self.restoredFileNames = restoredFileNames
            self.previouslyExistingFileNames = previouslyExistingFileNames
        }
    }

    public enum BackupError: Error, Equatable, LocalizedError {
        case notABackup
        case nothingToImport
        case writeFailed(String)
        case readFailed(String)
        case invalidFile(String)
        case unsupportedFormat(Int)
        case rollbackFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notABackup: return "所选位置不是有效的 iFocus 备份文件夹。"
            case .nothingToImport: return "备份里没有可恢复的任务或专注记录。"
            case .writeFailed(let s): return "写入失败：\(s)"
            case .readFailed(let s): return "读取失败：\(s)"
            case .invalidFile(let s): return "备份文件无效：\(s)"
            case .unsupportedFormat(let version): return "此备份格式较新（版本 \(version)），请先更新 iFocus。"
            case .rollbackFailed(let s): return "恢复失败，且自动回滚未能完成：\(s)"
            }
        }
    }

    /// Suggested folder name: `iFocus-Backup-2026-07-12`.
    public static func suggestedFolderName(date: Date = Date(), calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "iFocus-Backup-\(f.string(from: date))"
    }

    public static func inspect(directory: URL, fileManager: FileManager = .default) -> Package {
        var present: [String] = []
        for name in dataFileNames {
            let url = directory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                present.append(name)
            }
        }
        let settingsURL = directory.appendingPathComponent(settingsFileName)
        let hasSettings = fileManager.fileExists(atPath: settingsURL.path)
        let avatarURL = directory.appendingPathComponent(avatarFileName)
        let hasAvatar = fileManager.fileExists(atPath: avatarURL.path)
        let manifest = loadManifest(from: directory, fileManager: fileManager)
        return Package(
            directory: directory,
            manifest: manifest,
            presentDataFiles: present,
            hasSettings: hasSettings,
            hasAvatar: hasAvatar
        )
    }

    /// Validate every known payload before any live data is touched.
    public static func validate(
        package: Package,
        fileManager: FileManager = .default
    ) throws -> ValidationSummary {
        guard package.isImportable else { throw BackupError.nothingToImport }
        if let version = package.manifest?.formatVersion, version > formatVersion {
            throw BackupError.unsupportedFormat(version)
        }

        var taskCount: Int?
        var sessionCount: Int?
        for name in package.presentDataFiles {
            let data = try readPayload(named: name, from: package.directory)
            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: data)
            } catch {
                throw BackupError.invalidFile(name)
            }
            switch name {
            case tasksFileName:
                guard let values = object as? [Any] else { throw BackupError.invalidFile(name) }
                taskCount = values.count
            case sessionsFileName:
                guard let values = object as? [Any] else { throw BackupError.invalidFile(name) }
                sessionCount = values.count
            case stateFileName, timerSessionFileName:
                guard object is [String: Any] else { throw BackupError.invalidFile(name) }
            default:
                throw BackupError.invalidFile(name)
            }
        }

        if package.hasSettings {
            let data = try readPayload(named: settingsFileName, from: package.directory)
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  object is [String: Any] else {
                throw BackupError.invalidFile(settingsFileName)
            }
        }
        if package.hasAvatar {
            let data = try readPayload(named: avatarFileName, from: package.directory)
            guard !data.isEmpty else { throw BackupError.invalidFile(avatarFileName) }
        }

        return ValidationSummary(
            taskCount: taskCount,
            sessionCount: sessionCount,
            hasSettings: package.hasSettings,
            hasTimerSession: package.presentDataFiles.contains(timerSessionFileName),
            hasAvatar: package.hasAvatar
        )
    }

    public static func loadManifest(from directory: URL, fileManager: FileManager = .default) -> Manifest? {
        let url = directory.appendingPathComponent(manifestFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Manifest.self, from: data)
    }

    /// Write a complete package into `directory` (created if needed).
    public static func writePackage(
        to directory: URL,
        filePayloads: [String: Data],
        settingsJSON: Data?,
        manifest: Manifest,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        for (name, data) in filePayloads {
            guard packageFileNames.contains(name) else {
                throw BackupError.writeFailed(name)
            }
            let dest = directory.appendingPathComponent(name)
            do {
                try data.write(to: dest, options: .atomic)
            } catch {
                throw BackupError.writeFailed(name)
            }
        }

        if let settingsJSON {
            do {
                try settingsJSON.write(
                    to: directory.appendingPathComponent(settingsFileName),
                    options: .atomic
                )
            } catch {
                throw BackupError.writeFailed(settingsFileName)
            }
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(manifest)
            try data.write(
                to: directory.appendingPathComponent(manifestFileName),
                options: .atomic
            )
        } catch {
            throw BackupError.writeFailed(manifestFileName)
        }
    }

    /// Atomically replace listed live files. A snapshot is retained for manual recovery.
    @discardableResult
    public static func restoreDataFiles(
        from package: Package,
        into storageDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> RestoreReceipt {
        _ = try validate(package: package, fileManager: fileManager)
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        var incoming: [String: Data] = [:]
        for name in package.presentDataFiles {
            incoming[name] = try readPayload(named: name, from: package.directory)
        }

        let snapshot = try snapshotLiveData(storageDirectory: storageDirectory, fileManager: fileManager)
        let existing = Set(package.presentDataFiles.filter {
            fileManager.fileExists(atPath: storageDirectory.appendingPathComponent($0).path)
        })
        let receipt = RestoreReceipt(
            snapshotDirectory: snapshot,
            restoredFileNames: package.presentDataFiles,
            previouslyExistingFileNames: existing
        )

        do {
            for name in package.presentDataFiles {
                guard let data = incoming[name] else { throw BackupError.readFailed(name) }
                try data.write(
                    to: storageDirectory.appendingPathComponent(name),
                    options: .atomic
                )
            }
            return receipt
        } catch {
            do {
                try rollbackRestore(receipt, into: storageDirectory, fileManager: fileManager)
            } catch {
                throw BackupError.rollbackFailed(error.localizedDescription)
            }
            throw error
        }
    }

    public static func rollbackRestore(
        _ receipt: RestoreReceipt,
        into storageDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        for name in receipt.restoredFileNames {
            let destination = storageDirectory.appendingPathComponent(name)
            if receipt.previouslyExistingFileNames.contains(name) {
                let source = receipt.snapshotDirectory.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: source.path) else {
                    throw BackupError.rollbackFailed(name)
                }
                let data = try Data(contentsOf: source)
                try data.write(to: destination, options: .atomic)
            } else if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
    }

    /// Snapshot current live files beside storage before overwrite.
    public static func snapshotLiveData(
        storageDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = storageDirectory.appendingPathComponent(
            "pre-import-\(stamp)-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        for name in dataFileNames {
            let src = storageDirectory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: src.path) else { continue }
            try fileManager.copyItem(
                at: src,
                to: backupDir.appendingPathComponent(name)
            )
        }
        return backupDir
    }

    private static func readPayload(named name: String, from directory: URL) throws -> Data {
        do {
            return try Data(contentsOf: directory.appendingPathComponent(name))
        } catch {
            throw BackupError.readFailed(name)
        }
    }
}
