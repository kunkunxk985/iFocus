import Foundation

/// App-wide navigation (menu commands / keyboard shortcuts).
enum AppNavigation {
    static let navigate = Notification.Name("iFocus.navigate")
    static let openSettings = Notification.Name("iFocus.openSettings")
    
    static let toggleTimer = Notification.Name("iFocus.toggleTimer")
    static let resetTimer = Notification.Name("iFocus.resetTimer")
    static let skipTimer = Notification.Name("iFocus.skipTimer")
    static let newTask = Notification.Name("iFocus.newTask")
    static let searchTasks = Notification.Name("iFocus.searchTasks")
    static let toggleSidebar = Notification.Name("iFocus.toggleSidebar")
    static let toggleMiniTimer = Notification.Name("iFocus.toggleMiniTimer")
    static let toggleFocusMode = Notification.Name("iFocus.toggleFocusMode")
    static let showOnboarding = Notification.Name("iFocus.showOnboarding")

    /// Survives closing/reopening the main window: the Settings replay button sets it,
    /// and whichever ContentView appears next consumes it.
    static let pendingOnboardingReplayKey = "iFocus.pendingOnboardingReplay"
    
    /// Post via `object` so Swift enums don't get lost in ObjC userInfo bridging.
    static func post(_ screen: AppScreen) {
        NotificationCenter.default.post(name: navigate, object: screen)
    }
}
