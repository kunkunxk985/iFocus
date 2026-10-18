import Foundation
import os

/// Structured logging for production — replaces ad-hoc `print`.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kun.ifocus"

    static let tasks = Logger(subsystem: subsystem, category: "TaskStore")
    static let settings = Logger(subsystem: subsystem, category: "SettingsStore")
    static let timer = Logger(subsystem: subsystem, category: "TimerStore")
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")
    static let backup = Logger(subsystem: subsystem, category: "Backup")
    static let general = Logger(subsystem: subsystem, category: "App")
}
