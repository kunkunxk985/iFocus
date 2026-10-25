import AppKit
import Foundation

/// Downloads a release zip and swaps it over the running iFocus.app, then relaunches.
@MainActor
final class AppUpdateCenter: ObservableObject {
    static let shared = AppUpdateCenter()

    enum Phase: Equatable {
        case idle
        case checking
        case downloading
        case installing
        case upToDate
        case noRelease
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    private var job: Task<Void, Never>?

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .installing:
            return true
        case .idle, .upToDate, .noRelease, .failed:
            return false
        }
    }

    func checkAndInstall() {
        guard !isBusy else { return }
        job = Task { await perform() }
    }

    private func perform() async {
        phase = .checking
        let status = await AppUpdateChecker.check(currentVersion: AppVersion.short)
        switch status {
        case .upToDate:
            phase = .upToDate
        case .noRelease:
            phase = .noRelease
        case .missingPackage(let version):
            phase = .failed("新版本 \(version) 还没有安装包")
        case .failed:
            phase = .failed("暂时连不上，稍后再试")
        case .available(_, let package):
            phase = .downloading
            do {
                let installed = try await AppUpdateInstaller.prepare(package: package)
                phase = .installing
                try AppUpdateInstaller.swapInAfterQuit(preparedApp: installed.app, workDirectory: installed.work)
                NSApp.terminate(nil)
            } catch {
                phase = .failed(error.localizedDescription)
            }
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
        let zip = work.appendingPathComponent("iFocus.zip")
        let expanded = work.appendingPathComponent("expanded", isDirectory: true)

        do {
            let (downloaded, response) = try await URLSession.shared.download(from: package)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { throw Failure.downloadFailed }
            if FileManager.default.fileExists(atPath: zip.path) {
                try FileManager.default.removeItem(at: zip)
            }
            do {
                try FileManager.default.moveItem(at: downloaded, to: zip)
            } catch {
                try FileManager.default.copyItem(at: downloaded, to: zip)
            }
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, expanded.path])
            guard let app = findApp(in: expanded) else { throw Failure.unreadablePackage }
            guard bundleIdentifier(of: app) == "com.kun.ifocus" else { throw Failure.wrongApp }
            try? run("/usr/bin/xattr", ["-cr", app.path])
            return Prepared(app: app, work: work)
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
