import Foundation

/// Before the stores read anything on the first launch of a new version, copy every JSON
/// data file to `pre-upgrade/<oldVersion>-<yyyyMMdd-HHmm>/`. The copy is never pruned.
enum PreUpgradeGuard {
    static let lastLaunchedVersionKey = "lastLaunchedVersion"
    static let folderName = "pre-upgrade"

    /// Returns the folder written on this launch, or nil when the version is unchanged
    /// or there was nothing to copy. Records `currentVersion` either way.
    @discardableResult
    static func run(
        storageDirectory: URL,
        currentVersion: String,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> URL? {
        let previous = defaults.string(forKey: lastLaunchedVersionKey)
        guard previous != currentVersion else { return nil }
        defer { defaults.set(currentVersion, forKey: lastLaunchedVersionKey) }

        let files = ((try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []).filter { $0.pathExtension.lowercased() == "json" }
        guard !files.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let name = "\(previous ?? "unknown")-\(formatter.string(from: now))"
        let folder = storageDirectory
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            AppLog.tasks.error("pre-upgrade copy failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        for file in files {
            try? fileManager.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent))
        }
        return folder
    }

    /// Alert text when the upgrade launch could not read some records.
    static func skippedItemsNotice(count: Int, folder: URL) -> String {
        "升级后有 \(count) 条记录没能读出来，所以没有显示。升级前的数据已原样保存在：\n\(folder.path)\n需要时可以从这里找回。"
    }
}
