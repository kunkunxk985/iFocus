import AppKit
import Foundation

/// Downloads a release DMG and swaps it over the running iFocus.app, then relaunches.
@MainActor
final class AppUpdateCenter: ObservableObject {
    static let shared = AppUpdateCenter()

    enum Phase: Equatable {
        case idle
        case checking
        case available(version: String, package: URL)
        case downloading
        case installing
        case upToDate
        case noRelease
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    private var job: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .installing:
            return true
        case .idle, .available, .upToDate, .noRelease, .failed:
            return false
        }
    }

    func checkOrInstall() {
        guard !isBusy else { return }
        resetTask?.cancel()
        if case .available(_, let package) = phase {
            job = Task { await performInstall(package: package) }
        } else {
            job = Task { await performCheck() }
        }
    }

    func resetTransientStatusIfNeeded() {
        resetTask?.cancel()
        switch phase {
        case .upToDate, .noRelease, .failed:
            phase = .idle
        case .idle, .checking, .available, .downloading, .installing:
            break
        }
    }

    private func scheduleAutoReset() {
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            resetTransientStatusIfNeeded()
        }
    }

    private func performCheck() async {
        phase = .checking
        let status = await AppUpdateChecker.check(currentVersion: AppVersion.short)
        switch status {
        case .upToDate:
            phase = .upToDate
            scheduleAutoReset()
        case .noRelease:
            phase = .noRelease
            scheduleAutoReset()
        case .missingPackage(let version):
            phase = .failed("新版本 \(version) 还没有安装包")
            scheduleAutoReset()
        case .failed:
            phase = .failed("暂时连不上，稍后再试")
            scheduleAutoReset()
        case .available(let version, let package):
            phase = .available(version: version, package: package)
        }
    }

    private func performInstall(package: URL) async {
        phase = .downloading
        do {
            let installed = try await AppUpdateInstaller.prepare(package: package)
            phase = .installing
            try AppUpdateInstaller.swapInAfterQuit(preparedApp: installed.app, workDirectory: installed.work)
            NSApp.terminate(nil)
        } catch {
            phase = .failed(error.localizedDescription)
            scheduleAutoReset()
        }
    }
}

enum AppUpdateInstaller {
    struct Prepared {
        let app: URL
        let work: URL
    }

    enum Failure: LocalizedError {
        case notInstalledApp
        case downloadFailed
        case unreadablePackage
        case wrongApp
        case cannotReplace

        var errorDescription: String? {
            switch self {
            case .notInstalledApp:
                return "请从安装好的 iFocus 里更新"
            case .downloadFailed:
                return "下载没有完成，稍后再试"
            case .unreadablePackage:
                return "安装包无法打开"
            case .wrongApp:
                return "安装包不是 iFocus"
            case .cannotReplace:
                return "没有权限替换当前的应用"
            }
        }
    }

    static func prepare(package: URL) async throws -> Prepared {
        let destination = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard destination.lastPathComponent == "iFocus.app" else { throw Failure.notInstalledApp }
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            throw Failure.cannotReplace
        }

        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let archiveName = package.lastPathComponent.isEmpty ? AppUpdateChecker.packageName : package.lastPathComponent
        let archive = work.appendingPathComponent(archiveName)
        let expanded = work.appendingPathComponent("expanded", isDirectory: true)
        try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)

        do {
            let (downloaded, response) = try await URLSession.shared.download(from: package)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { throw Failure.downloadFailed }
            if FileManager.default.fileExists(atPath: archive.path) {
                try FileManager.default.removeItem(at: archive)
            }
            do {
                try FileManager.default.moveItem(at: downloaded, to: archive)
            } catch {
                try FileManager.default.copyItem(at: downloaded, to: archive)
            }
            let stagedApp = try expandReleaseArchive(at: archive, into: expanded, work: work)
            guard bundleIdentifier(of: stagedApp) == "com.kun.ifocus" else { throw Failure.wrongApp }
            try? run("/usr/bin/xattr", ["-cr", stagedApp.path])
            return Prepared(app: stagedApp, work: work)
        } catch let failure as Failure {
            try? FileManager.default.removeItem(at: work)
            throw failure
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw Failure.downloadFailed
        }
    }

    /// Hands replacement to a small script that waits until this process has quit.
    static func swapInAfterQuit(preparedApp: URL, workDirectory: URL) throws {
        let destination = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard destination.lastPathComponent == "iFocus.app" else { throw Failure.notInstalledApp }
        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent("iFocus.app.update-staging", isDirectory: true)
        let backup = parent.appendingPathComponent("iFocus.app.pre-update-backup", isDirectory: true)
        let script = workDirectory.appendingPathComponent("install.sh")
        let body = """
        #!/bin/bash
        set -euo pipefail
        DEST=\(shellQuote(destination.path))
        NEW=\(shellQuote(preparedApp.path))
        STAGING=\(shellQuote(staging.path))
        BACKUP=\(shellQuote(backup.path))
        WORK=\(shellQuote(workDirectory.path))

        restore_backup() {
          rm -rf "$DEST"
          if [[ -d "$BACKUP" ]]; then
            ditto "$BACKUP" "$DEST"
          fi
        }

        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
          sleep 0.2
        done

        rm -rf "$STAGING"
        if ! ditto "$NEW" "$STAGING"; then
          exit 1
        fi
        xattr -cr "$STAGING" || true

        rm -rf "$BACKUP"
        if [[ -d "$DEST" ]]; then
          ditto "$DEST" "$BACKUP"
        fi

        rm -rf "$DEST"
        if ! mv "$STAGING" "$DEST"; then
          restore_backup
          exit 1
        fi

        open "$DEST" || true
        rm -rf "$BACKUP" "$WORK"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private static func expandReleaseArchive(at archive: URL, into expanded: URL, work: URL) throws -> URL {
        let ext = archive.pathExtension.lowercased()
        guard ext == "dmg" else { throw Failure.unreadablePackage }

        let mount = work.appendingPathComponent("mount", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, archive.path])
        defer {
            _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet"])
        }
        guard let mounted = findApp(in: mount) else { throw Failure.unreadablePackage }
        let staged = expanded.appendingPathComponent("iFocus.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: staged.path) {
            try FileManager.default.removeItem(at: staged)
        }
        try run("/usr/bin/ditto", [mounted.path, staged.path])
        return staged
    }

    private static func findApp(in root: URL) -> URL? {
        let fileManager = FileManager.default
        let direct = root.appendingPathComponent("iFocus.app")
        if fileManager.fileExists(atPath: direct.path) { return direct }
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return nil }
        for child in children {
            if child.lastPathComponent == "iFocus.app" { return child }
            let nested = child.appendingPathComponent("iFocus.app")
            if fileManager.fileExists(atPath: nested.path) { return nested }
        }
        return nil
    }

    private static func bundleIdentifier(of app: URL) -> String? {
        let info = app.appendingPathComponent("Contents/Info.plist")
        guard let dictionary = NSDictionary(contentsOf: info) else { return nil }
        return dictionary["CFBundleIdentifier"] as? String
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure.unreadablePackage }
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
