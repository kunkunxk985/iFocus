import Foundation

/// Disk snapshot so we can offer resume after crash / force-quit.
struct TimerSessionSnapshot: Codable, Equatable {
    var mode: String
    var timeRemaining: TimeInterval
    var isRunning: Bool
    var elapsedBeforePause: TimeInterval
    var sessionPlannedDuration: TimeInterval?
    var activeTaskId: UUID?
    var workTaskTitle: String?
    var workTaskCategory: String?
    /// false while app is running; true only after clean terminate.
    var cleanExit: Bool
    var savedAt: Date
    /// Work segment counts up (nil in snapshots from older versions = countdown).
    var countUp: Bool? = nil
    
    var hasResumableSession: Bool {
        // Mid-session if planned duration set, or remaining not a "fresh full" idle.
        sessionPlannedDuration != nil || elapsedBeforePause > 0.5
    }
    
    /// Offer resume after crash **or** intentional quit mid-session.
    /// (`cleanExit` is retained for analytics copy; both paths are recoverable.)
    var shouldOfferResume: Bool {
        hasResumableSession
    }
    
    /// 「还剩 12:30」 for a countdown, 「已专注 47:05」 for a count-up focus.
    var resumeTimeLabel: String {
        func clock(_ seconds: TimeInterval) -> String {
            let total = max(0, Int(seconds.rounded()))
            return String(format: "%d:%02d", total / 60, total % 60)
        }
        if countUp == true {
            let planned = sessionPlannedDuration ?? (elapsedBeforePause + timeRemaining)
            return "已专注 " + clock(planned - timeRemaining)
        }
        return "还剩 " + clock(timeRemaining)
    }

    var resumeReasonLabel: String {
        cleanExit ? "上次退出时" : "上次异常退出时"
    }
    
    var timerMode: TimerMode? {
        TimerMode.allCases.first { $0.rawValue == mode }
    }
}

enum TimerSessionPersistence {
    private static let fileName = "timer_session.json"
    
    static func fileURL(in directory: URL? = nil) -> URL {
        let dir = directory ?? TaskStore.defaultStorageDirectory()
        return dir.appendingPathComponent(fileName)
    }
    
    static func load(from directory: URL? = nil) -> TimerSessionSnapshot? {
        let url = fileURL(in: directory)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TimerSessionSnapshot.self, from: data)
    }
    
    static func save(_ snapshot: TimerSessionSnapshot, to directory: URL? = nil) {
        let url = fileURL(in: directory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
    
    static func clear(in directory: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL(in: directory))
    }
}
