import Foundation

/// Handles `ifocus://` URLs for Shortcuts / Alfred / scripts.
enum DeepLinkRouter {
    static let scheme = "ifocus"
    
    enum Action: Equatable {
        case start
        case pause
        case toggle
        case skip
        case reset
        case open(AppScreen?)
        case settings
        case freeFocus
    }
    
    static func parse(_ url: URL) -> Action? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let command = host.isEmpty ? path : host
        
        switch command {
        case "start":
            return .start
        case "pause":
            return .pause
        case "toggle":
            return .toggle
        case "skip":
            return .skip
        case "reset":
            return .reset
        case "settings", "setting":
            return .settings
        case "freefocus", "free":
            return .freeFocus
        case "open", "goto", "navigate":
            return .open(screen(from: url))
        case "timer":
            return .open(.timer)
        case "analytics", "stats":
            return .open(.analytics)
        case "today":
            return .open(.todayTask)
        case "inbox":
            return .open(.inboxTask)
        case "profile":
            return .open(.profile)
        default:
            if command.isEmpty { return .open(.timer) }
            return nil
        }
    }
    
    private static func screen(from url: URL) -> AppScreen? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let value = components.queryItems?
            .first(where: { $0.name == "screen" || $0.name == "page" })?
            .value?
            .lowercased()
        switch value {
        case "timer", "focus": return .timer
        case "analytics", "stats": return .analytics
        case "today": return .todayTask
        case "tomorrow": return .tomorrowTask
        case "week": return .weekTask
        case "planned": return .plannedTask
        case "completed": return .completedTask
        case "inbox": return .inboxTask
        case "profile": return .profile
        default: return .timer
        }
    }
    
    /// Dispatch parsed action into app notifications / timer.
    static func handle(_ url: URL, timerStore: TimerStore) {
        guard let action = parse(url) else { return }
        switch action {
        case .start:
            // Product meaning: start **work focus** (may confirm discard if mid-session).
            timerStore.requestStartWorkFocus(taskId: timerStore.taskStore?.activeTaskId)
            AppNavigation.post(.timer)
        case .pause:
            if timerStore.isRunning { timerStore.pause() }
        case .toggle:
            timerStore.toggle()
        case .skip:
            if timerStore.canSkipSegment {
                timerStore.skipToNext()
            }
        case .reset:
            NotificationCenter.default.post(name: AppNavigation.resetTimer, object: nil)
        case .settings:
            NotificationCenter.default.post(name: AppNavigation.openSettings, object: nil)
        case .freeFocus:
            timerStore.requestStartWorkFocus(taskId: nil)
            AppNavigation.post(.timer)
        case .open(let screen):
            if let screen {
                AppNavigation.post(screen)
            }
            WindowChromeController.shared.showMainWindow()
        }
        WindowChromeController.shared.showMainWindow()
    }
}
