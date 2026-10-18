import Foundation
import iFocusCore

/// Mirrors focus history into `~/StudyLog` (CSV + weekly Markdown) so it can be read
/// outside the app. `focus_sessions.json` stays the source of truth; this folder is
/// regenerated from it and safe to delete.
final class StudyLogWriter {
    static func defaultDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("StudyLog", isDirectory: true)
    }

    let directory: URL
    private let queue = DispatchQueue(label: "com.kun.ifocus.studylog", qos: .utility)

    init(directory: URL) {
        self.directory = directory
    }

    /// Snapshots on the caller's thread, writes on a background queue.
    func export(_ sessions: [FocusSession], now: Date = Date()) {
        let entries = sessions.map(Self.entry(for:))
        let directory = self.directory
        queue.async {
            Self.write(entries: entries, now: now, to: directory)
        }
    }

    /// Blocks until queued exports finish (app quit and tests).
    func waitUntilIdle() {
        queue.sync {}
    }

    static func entry(for session: FocusSession) -> StudyLogExport.Entry {
        StudyLogExport.Entry(
            endedAt: session.timestamp,
            minutes: session.durationMinutes,
            taskTitle: session.taskTitle,
            category: session.taskCategory?.rawValue
        )
    }

    private static func write(entries: [StudyLogExport.Entry], now: Date, to directory: URL) {
        let fm = FileManager.default
        let files = StudyLogExport.files(entries: entries, now: now, calendar: StudyLogExport.weekCalendar())
        do {
            try fm.createDirectory(
                at: directory.appendingPathComponent(StudyLogExport.weeksDirectoryName, isDirectory: true),
                withIntermediateDirectories: true
            )
            for (path, text) in files {
                let url = directory.appendingPathComponent(path)
                let data = Data(text.utf8)
                // Leave unchanged files alone so past weeks keep their modification dates.
                if let existing = try? Data(contentsOf: url), existing == data { continue }
                try data.write(to: url, options: .atomic)
            }
        } catch {
            AppLog.tasks.error("study log export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
