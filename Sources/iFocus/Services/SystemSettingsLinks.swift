import AppKit

/// One place for the macOS settings panes the app sends people to.
enum SystemSettingsLinks {
    static func openNotifications() {
        open([
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ])
    }

    static func openFocus() {
        open([
            "x-apple.systempreferences:com.apple.Focus-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ])
    }

    static func openLoginItems() {
        LaunchAtLogin.openLoginItemsSettings()
    }

    private static func open(_ values: [String]) {
        for value in values {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
