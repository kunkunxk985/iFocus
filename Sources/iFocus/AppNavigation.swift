import Foundation

/// App-wide navigation (menu commands / keyboard shortcuts).
enum AppNavigation {
    static let navigate = Notification.Name("iFocus.navigate")
    static let openSettings = Notification.Name("iFocus.openSettings")
    
    static let toggleTimer = Notification.Name("iFocus.toggleTimer")
    static let resetTimer = Notification.Name("iFocus.resetTimer")
    static let skipTimer = Notification.Name("iFocus.skipTimer")
    
    /// Post via `object` so Swift enums don't get lost in ObjC userInfo bridging.
    static func post(_ screen: AppScreen) {
        NotificationCenter.default.post(name: navigate, object: screen)
    }
}
