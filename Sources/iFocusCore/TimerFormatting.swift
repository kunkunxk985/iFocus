import Foundation

/// Pure timer display helpers.
public enum TimerFormatting {
    
    /// Matches app display: ceil remaining seconds into mm:ss.
    public static func timeString(remaining: TimeInterval) -> String {
        let displaySeconds = Int(ceil(max(0, remaining)))
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Count-up display: `mm:ss`, or `h:mm:ss` from one hour on.
    public static func elapsedString(seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Round elapsed seconds to pomodoro log minutes (min 1 if elapsed >= 1s).
    public static func logMinutes(
        elapsedSeconds: TimeInterval,
        maximumSeconds: TimeInterval? = nil
    ) -> Int? {
        let upperBound = maximumSeconds.map { max(0, $0) } ?? elapsedSeconds
        let boundedElapsed = min(elapsedSeconds, upperBound)
        guard boundedElapsed >= 1 else { return nil }
        return max(1, Int((boundedElapsed / 60.0).rounded()))
    }
    
    public static func progress(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, 1.0 - (remaining / total)))
    }
}
