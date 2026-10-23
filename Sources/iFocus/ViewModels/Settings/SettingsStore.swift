import Foundation
import AppKit
import SwiftUI
import UserNotifications
import iFocusCore

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// App-menu shortcut for 开始/暂停 (global while app is frontmost).
enum ToggleShortcutPreset: String, CaseIterable, Identifiable {
    case shiftCmdSpace
    case controlCmdT
    case optionCmdP
    case controlCmdSpace
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .shiftCmdSpace: return "⇧⌘空格"
        case .controlCmdT: return "⌃⌘T"
        case .optionCmdP: return "⌥⌘P"
        case .controlCmdSpace: return "⌃⌘空格"
        }
    }
    
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .shiftCmdSpace, .controlCmdSpace: return .space
        case .controlCmdT: return "t"
        case .optionCmdP: return "p"
        }
    }
    
    var modifiers: EventModifiers {
        switch self {
        case .shiftCmdSpace: return [.command, .shift]
        case .controlCmdT: return [.command, .control]
        case .optionCmdP: return [.command, .option]
        case .controlCmdSpace: return [.command, .control]
        }
    }
    
    /// Prefer ⌃⌘T — ⇧⌘空格 often collides with input-source switching on Chinese Macs.
    static var defaultPreset: ToggleShortcutPreset { .controlCmdT }
}

class SettingsStore: ObservableObject {
    private enum Key {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let autoStartBreaks = "autoStartBreaks"
        static let autoStartWork = "autoStartWork"
        static let longBreakEvery = "longBreakEvery"
        static let strictMode = "strictMode"
        static let countUpWork = "countUpWork"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let hapticsEnabled = "hapticsEnabled"
        static let dailyGoal = "dailyGoal"
        static let appearance = "appearance"
        static let username = "username"
        static let avatarColorIndex = "avatarColorIndex"
        static let avatarPath = "avatarPath"
        static let launchAtLogin = "launchAtLogin"
        static let toggleShortcut = "toggleShortcutPreset"
        static let showFocusModeHint = "showFocusModeHintOnStart"
        static let pauseReminderEnabled = "pauseReminderEnabled"
        static let pauseReminderMinutes = "pauseReminderMinutes"
        static let accentPreset = "accentPreset"
        static let menuBarDisplayStyle = "menuBarDisplayStyle"
        static let uiDensity = "uiDensity"
        static let dockBounceOnComplete = "dockBounceOnComplete"
        static let decorativeMotionEnabled = "decorativeMotionEnabled"
        static let smartLaunchLanding = "smartLaunchLanding"
        // Analytics dashboard cards (quiet defaults: core on, details off)
        static let analyticsShowInsight = "analyticsShowInsight"
        static let analyticsShowKPI = "analyticsShowKPI"
        static let analyticsShowGoal = "analyticsShowGoal"
        static let analyticsShowTrend = "analyticsShowTrend"
        static let analyticsShowTimeline = "analyticsShowTimeline"
        static let analyticsShowHours = "analyticsShowHours"
        static let analyticsShowCategory = "analyticsShowCategory"
        static let analyticsShowTaskBinding = "analyticsShowTaskBinding"
        static let analyticsShowRecent = "analyticsShowRecentCards"
    }
    
    private let defaults: UserDefaults
    private let shouldApplyAppearance: Bool
    private let avatarStorageDirectory: URL
    
    @Published var workMinutes: Int {
        didSet {
            let clamped = Self.clampWorkMinutes(workMinutes)
            guard clamped == workMinutes else {
                workMinutes = clamped
                return
            }
            defaults.set(workMinutes, forKey: Key.workMinutes)
        }
    }
    @Published var shortBreakMinutes: Int {
        didSet {
            let clamped = Self.clampShortBreakMinutes(shortBreakMinutes)
            guard clamped == shortBreakMinutes else {
                shortBreakMinutes = clamped
                return
            }
            defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes)
        }
    }
    @Published var longBreakMinutes: Int {
        didSet {
            let clamped = Self.clampLongBreakMinutes(longBreakMinutes)
            guard clamped == longBreakMinutes else {
                longBreakMinutes = clamped
                return
            }
            defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes)
        }
    }
    /// When a work segment ends, auto-start the next break.
    @Published var autoStartBreaks: Bool {
        didSet { defaults.set(autoStartBreaks, forKey: Key.autoStartBreaks) }
    }
    /// When a break ends, auto-start the next work segment.
    @Published var autoStartWork: Bool {
        didSet { defaults.set(autoStartWork, forKey: Key.autoStartWork) }
    }
    /// Long break after every N completed work pomodoros today (industry default 4).
    @Published var longBreakEvery: Int {
        didSet {
            let clamped = Self.clampLongBreakEvery(longBreakEvery)
            guard clamped == longBreakEvery else {
                longBreakEvery = clamped
                return
            }
            defaults.set(longBreakEvery, forKey: Key.longBreakEvery)
        }
    }
    /// Disables skip (and deep-link skip) so a segment must finish or be reset with confirm.
    @Published var strictMode: Bool {
        didSet { defaults.set(strictMode, forKey: Key.strictMode) }
    }
    /// Work segments count up from 00:00 and end on 「完成」 instead of a fixed countdown.
    @Published var countUpWork: Bool {
        didSet { defaults.set(countUpWork, forKey: Key.countUpWork) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    @Published var soundName: NSSound.Name {
        didSet { defaults.set(soundName as String, forKey: Key.soundName) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }
    @Published var dailyGoal: Int {
        didSet {
            let clamped = Self.clampDailyGoal(dailyGoal)
            guard clamped == dailyGoal else {
                dailyGoal = clamped
                return
            }
            defaults.set(dailyGoal, forKey: Key.dailyGoal)
        }
    }
    @Published var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            applySystemAppearance()
        }
    }
    @Published var username: String {
        didSet { defaults.set(username, forKey: Key.username) }
    }
    @Published var avatarColorIndex: Int {
        didSet { defaults.set(avatarColorIndex, forKey: Key.avatarColorIndex) }
    }
    @Published var avatarPath: String? {
        didSet {
            if let path = avatarPath {
                defaults.set(path, forKey: Key.avatarPath)
            } else {
                defaults.removeObject(forKey: Key.avatarPath)
            }
        }
    }
    
    /// User preference for login launch. **Default is always off** — never auto-register.
    /// System registration only runs when the user toggles this in Settings.
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
        }
    }
    
    /// Last human-readable feedback from login-item registration.
    @Published var launchAtLoginFeedback: String?
    
    @Published var toggleShortcut: ToggleShortcutPreset {
        didSet { defaults.set(toggleShortcut.rawValue, forKey: Key.toggleShortcut) }
    }
    
    /// When starting a work segment, offer to open System Focus settings.
    @Published var showFocusModeHintOnStart: Bool {
        didSet { defaults.set(showFocusModeHintOnStart, forKey: Key.showFocusModeHint) }
    }
    
    @Published var pauseReminderEnabled: Bool {
        didSet { defaults.set(pauseReminderEnabled, forKey: Key.pauseReminderEnabled) }
    }
    
    /// Minutes paused mid-session before nudging the user (default 5).
    @Published var pauseReminderMinutes: Int {
        didSet {
            let clamped = min(60, max(1, pauseReminderMinutes))
            guard clamped == pauseReminderMinutes else {
                pauseReminderMinutes = clamped
                return
            }
            defaults.set(pauseReminderMinutes, forKey: Key.pauseReminderMinutes)
        }
    }
    
    @Published var accentPreset: AccentPreset {
        didSet {
            defaults.set(accentPreset.rawValue, forKey: Key.accentPreset)
            // Keep AppTheme.accent reader in sync (same UserDefaults key).
            objectWillChange.send()
        }
    }
    
    @Published var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet { defaults.set(menuBarDisplayStyle.rawValue, forKey: Key.menuBarDisplayStyle) }
    }
    
    @Published var uiDensity: UIDensity {
        didSet { defaults.set(uiDensity.rawValue, forKey: Key.uiDensity) }
    }
    
    /// Bounce Dock icon once when a timer segment completes.
    @Published var dockBounceOnComplete: Bool {
        didSet { defaults.set(dockBounceOnComplete, forKey: Key.dockBounceOnComplete) }
    }
    
    /// Ring breath, play invite pulse, celebrate scale — off by default (安静工具).
    @Published var decorativeMotionEnabled: Bool {
        didSet { defaults.set(decorativeMotionEnabled, forKey: Key.decorativeMotionEnabled) }
    }
    
    /// Open 「今天」 when there are open today/overdue tasks; otherwise 专注钟.
    @Published var smartLaunchLanding: Bool {
        didSet { defaults.set(smartLaunchLanding, forKey: Key.smartLaunchLanding) }
    }
    
    // MARK: - Analytics cards visibility (设置里可开关)
    
    @Published var analyticsShowInsight: Bool {
        didSet { defaults.set(analyticsShowInsight, forKey: Key.analyticsShowInsight) }
    }
    @Published var analyticsShowKPI: Bool {
        didSet { defaults.set(analyticsShowKPI, forKey: Key.analyticsShowKPI) }
    }
    @Published var analyticsShowGoal: Bool {
        didSet { defaults.set(analyticsShowGoal, forKey: Key.analyticsShowGoal) }
    }
    @Published var analyticsShowTrend: Bool {
        didSet { defaults.set(analyticsShowTrend, forKey: Key.analyticsShowTrend) }
    }
    @Published var analyticsShowTimeline: Bool {
        didSet { defaults.set(analyticsShowTimeline, forKey: Key.analyticsShowTimeline) }
    }
    @Published var analyticsShowHours: Bool {
        didSet { defaults.set(analyticsShowHours, forKey: Key.analyticsShowHours) }
    }
    @Published var analyticsShowCategory: Bool {
        didSet { defaults.set(analyticsShowCategory, forKey: Key.analyticsShowCategory) }
    }
    @Published var analyticsShowTaskBinding: Bool {
        didSet { defaults.set(analyticsShowTaskBinding, forKey: Key.analyticsShowTaskBinding) }
    }
    @Published var analyticsShowRecent: Bool {
        didSet { defaults.set(analyticsShowRecent, forKey: Key.analyticsShowRecent) }
    }
    
    /// Restore quiet-tool analytics layout (core on, details off).
    func resetAnalyticsCardVisibilityToQuietDefaults() {
        analyticsShowInsight = true
        analyticsShowKPI = true
        analyticsShowGoal = true
        analyticsShowTrend = true
        analyticsShowTimeline = false
        analyticsShowHours = false
        analyticsShowCategory = false
        analyticsShowTaskBinding = false
        analyticsShowRecent = false
    }

    /// Power-user layout: every analytics card visible.
    func enableAllAnalyticsCards() {
        analyticsShowInsight = true
        analyticsShowKPI = true
        analyticsShowGoal = true
        analyticsShowTrend = true
        analyticsShowTimeline = true
        analyticsShowHours = true
        analyticsShowCategory = true
        analyticsShowTaskBinding = true
        analyticsShowRecent = true
    }

    var anyAnalyticsCardEnabled: Bool {
        analyticsShowInsight
            || analyticsShowKPI
            || analyticsShowGoal
            || analyticsShowTrend
            || analyticsShowTimeline
            || analyticsShowHours
            || analyticsShowCategory
            || analyticsShowTaskBinding
            || analyticsShowRecent
    }

    var isAnalyticsQuietDefault: Bool {
        analyticsShowInsight
            && analyticsShowKPI
            && analyticsShowGoal
            && analyticsShowTrend
            && !analyticsShowTimeline
            && !analyticsShowHours
            && !analyticsShowCategory
            && !analyticsShowTaskBinding
            && !analyticsShowRecent
    }

    var isAnalyticsFullLayout: Bool {
        analyticsShowInsight
            && analyticsShowKPI
            && analyticsShowGoal
            && analyticsShowTrend
            && analyticsShowTimeline
            && analyticsShowHours
            && analyticsShowCategory
            && analyticsShowTaskBinding
            && analyticsShowRecent
    }
    
    /// Reflect OS login-item state in the toggle (read-only sync).
    /// Does **not** register the app — only the Settings switch calls `applyLaunchAtLoginPreference()`.
    func refreshLaunchAtLoginFromSystem() {
        // If the user (or System Settings) already registered us, show ON.
        // If not registered, keep preference as saved (default false) — never force ON.
        let systemOn = LaunchAtLogin.isEnabled
        if systemOn {
            if !launchAtLogin { launchAtLogin = true }
        } else if launchAtLogin, defaults.object(forKey: Key.launchAtLogin) as? Bool == true {
            // Preference says on but OS says off (user removed login item, or not in /Applications).
            launchAtLogin = false
            launchAtLoginFeedback = "系统中未启用登录项，已同步为关闭。可在下方重新打开。"
        }
    }
    
    /// Apply the toggle — only invoke from explicit user action in Settings.
    func applyLaunchAtLoginPreference() {
        let result = LaunchAtLogin.setEnabled(launchAtLogin)
        launchAtLoginFeedback = result.message
        let systemOn = LaunchAtLogin.isEnabled
        if !result.ok {
            // Registration failed — don't leave a lying "ON" switch.
            launchAtLogin = systemOn
        } else if launchAtLogin, !systemOn, LaunchAtLogin.status == .requiresApproval {
            // Waiting for user approval in System Settings; keep preference ON.
            launchAtLoginFeedback = result.message
        }
    }
    
    func openDataFolderInFinder() {
        let url = avatarStorageDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    /// Readable CSV + weekly reports mirrored from focus history (`~/StudyLog`).
    func openStudyLogFolderInFinder() {
        let url = StudyLogWriter.defaultDirectory()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    /// Feedback line for backup export/import (settings panel).
    @Published var backupFeedback: String?

    /// Preference keys included in quiet local backup (not transient UI state).
    static let backupPreferenceKeys: [String] = [
        Key.workMinutes, Key.shortBreakMinutes, Key.longBreakMinutes,
        Key.autoStartBreaks, Key.autoStartWork, Key.longBreakEvery, Key.strictMode, Key.countUpWork,
        Key.soundEnabled, Key.soundName, Key.hapticsEnabled, Key.dailyGoal,
        Key.appearance, Key.username, Key.avatarColorIndex,
        Key.toggleShortcut, Key.showFocusModeHint,
        Key.pauseReminderEnabled, Key.pauseReminderMinutes,
        Key.accentPreset, Key.menuBarDisplayStyle, Key.uiDensity,
        Key.dockBounceOnComplete, Key.decorativeMotionEnabled, Key.smartLaunchLanding,
        Key.analyticsShowInsight, Key.analyticsShowKPI, Key.analyticsShowGoal,
        Key.analyticsShowTrend, Key.analyticsShowTimeline, Key.analyticsShowHours,
        Key.analyticsShowCategory, Key.analyticsShowTaskBinding, Key.analyticsShowRecent
        // launchAtLogin intentionally omitted — OS registration is separate.
    ]

    func exportSettingsJSON() throws -> Data {
        // Export the effective values, including defaults that have never been written.
        // This makes a backup deterministic and lets a failed restore fully roll back.
        let dict: [String: Any] = [
            Key.workMinutes: workMinutes,
            Key.shortBreakMinutes: shortBreakMinutes,
            Key.longBreakMinutes: longBreakMinutes,
            Key.autoStartBreaks: autoStartBreaks,
            Key.autoStartWork: autoStartWork,
            Key.longBreakEvery: longBreakEvery,
            Key.strictMode: strictMode,
            Key.countUpWork: countUpWork,
            Key.soundEnabled: soundEnabled,
            Key.soundName: soundName as String,
            Key.hapticsEnabled: hapticsEnabled,
            Key.dailyGoal: dailyGoal,
            Key.appearance: appearance.rawValue,
            Key.username: username,
            Key.avatarColorIndex: avatarColorIndex,
            Key.toggleShortcut: toggleShortcut.rawValue,
            Key.showFocusModeHint: showFocusModeHintOnStart,
            Key.pauseReminderEnabled: pauseReminderEnabled,
            Key.pauseReminderMinutes: pauseReminderMinutes,
            Key.accentPreset: accentPreset.rawValue,
            Key.menuBarDisplayStyle: menuBarDisplayStyle.rawValue,
            Key.uiDensity: uiDensity.rawValue,
            Key.dockBounceOnComplete: dockBounceOnComplete,
            Key.decorativeMotionEnabled: decorativeMotionEnabled,
            Key.smartLaunchLanding: smartLaunchLanding,
            Key.analyticsShowInsight: analyticsShowInsight,
            Key.analyticsShowKPI: analyticsShowKPI,
            Key.analyticsShowGoal: analyticsShowGoal,
            Key.analyticsShowTrend: analyticsShowTrend,
            Key.analyticsShowTimeline: analyticsShowTimeline,
            Key.analyticsShowHours: analyticsShowHours,
            Key.analyticsShowCategory: analyticsShowCategory,
            Key.analyticsShowTaskBinding: analyticsShowTaskBinding,
            Key.analyticsShowRecent: analyticsShowRecent
        ]
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    func importSettingsJSON(_ data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalBackup.BackupError.readFailed("settings.json")
        }
        for key in Self.backupPreferenceKeys {
            if let value = dict[key] {
                defaults.set(value, forKey: key)
            }
        }
        // Re-apply into published properties.
        // JSONSerialization boxes numbers as NSNumber — never cast with `as? Int` alone.
        if let v = Self.jsonInt(dict["workMinutes"]) { workMinutes = Self.clampWorkMinutes(v) }
        if let v = Self.jsonInt(dict["shortBreakMinutes"]) { shortBreakMinutes = Self.clampShortBreakMinutes(v) }
        if let v = Self.jsonInt(dict["longBreakMinutes"]) { longBreakMinutes = Self.clampLongBreakMinutes(v) }
        if let v = Self.jsonBool(dict["autoStartBreaks"]) { autoStartBreaks = v }
        if let v = Self.jsonBool(dict["autoStartWork"]) { autoStartWork = v }
        if let v = Self.jsonInt(dict["longBreakEvery"]) { longBreakEvery = Self.clampLongBreakEvery(v) }
        if let v = Self.jsonBool(dict["strictMode"]) { strictMode = v }
        if let v = Self.jsonBool(dict[Key.countUpWork]) { countUpWork = v }
        if let v = Self.jsonBool(dict["soundEnabled"]) { soundEnabled = v }
        if let v = dict["soundName"] as? String { soundName = NSSound.Name(v) }
        if let v = Self.jsonBool(dict[Key.hapticsEnabled]) { hapticsEnabled = v }
        if let v = Self.jsonInt(dict["dailyGoal"]) { dailyGoal = Self.clampDailyGoal(v) }
        if let v = dict["appearance"] as? String, let mode = AppearanceMode(rawValue: v) {
            appearance = mode
        }
        if let v = dict["username"] as? String {
            username = v
            sanitizeUsername()
        }
        if let v = Self.jsonInt(dict["avatarColorIndex"]) { avatarColorIndex = v }
        if let v = dict[Key.toggleShortcut] as? String,
           let preset = ToggleShortcutPreset(rawValue: v) {
            toggleShortcut = preset
        }
        if let v = Self.jsonBool(dict[Key.showFocusModeHint]) { showFocusModeHintOnStart = v }
        if let v = Self.jsonBool(dict["pauseReminderEnabled"]) { pauseReminderEnabled = v }
        if let v = Self.jsonInt(dict["pauseReminderMinutes"]) { pauseReminderMinutes = v }
        if let v = dict["accentPreset"] as? String, let preset = AccentPreset(rawValue: v) {
            accentPreset = preset
        }
        if let v = dict["menuBarDisplayStyle"] as? String,
           let style = MenuBarDisplayStyle(rawValue: v) {
            menuBarDisplayStyle = style
        }
        if let v = dict["uiDensity"] as? String, let density = UIDensity(rawValue: v) {
            uiDensity = density
        }
        if let v = Self.jsonBool(dict["dockBounceOnComplete"]) { dockBounceOnComplete = v }
        if let v = Self.jsonBool(dict["decorativeMotionEnabled"]) { decorativeMotionEnabled = v }
        if let v = Self.jsonBool(dict["smartLaunchLanding"]) { smartLaunchLanding = v }
        if let v = Self.jsonBool(dict["analyticsShowInsight"]) { analyticsShowInsight = v }
        if let v = Self.jsonBool(dict["analyticsShowKPI"]) { analyticsShowKPI = v }
        if let v = Self.jsonBool(dict["analyticsShowGoal"]) { analyticsShowGoal = v }
        if let v = Self.jsonBool(dict["analyticsShowTrend"]) { analyticsShowTrend = v }
        if let v = Self.jsonBool(dict["analyticsShowTimeline"]) { analyticsShowTimeline = v }
        if let v = Self.jsonBool(dict["analyticsShowHours"]) { analyticsShowHours = v }
        if let v = Self.jsonBool(dict["analyticsShowCategory"]) { analyticsShowCategory = v }
        if let v = Self.jsonBool(dict["analyticsShowTaskBinding"]) { analyticsShowTaskBinding = v }
        if let v = Self.jsonBool(dict["analyticsShowRecentCards"]) { analyticsShowRecent = v }
    }

    /// `JSONSerialization` yields `NSNumber` for ints/bools — bridge safely.
    static func jsonInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let i = Int(s) { return i }
        return nil
    }

    static func jsonBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }
    
    @discardableResult
    func uploadAvatar(from url: URL) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: avatarStorageDirectory, withIntermediateDirectories: true)
        } catch {
            AppLog.settings.error("uploadAvatar failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            AppLog.settings.error("uploadAvatar cannot read path")
            return false
        }

        guard let sourceImage = NSImage(data: sourceData),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            AppLog.settings.error("uploadAvatar cannot decode image")
            return false
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
            AppLog.settings.error("uploadAvatar cannot encode PNG")
            return false
        }

        let destinationURL = avatarStorageDirectory.appendingPathComponent("avatar-\(UUID().uuidString).png")
        let previousAvatarPath = avatarPath
        do {
            try (pngData as Data).write(to: destinationURL, options: .atomic)
            self.avatarPath = destinationURL.path
            if let previousAvatarPath, previousAvatarPath != destinationURL.path {
                try? fileManager.removeItem(atPath: previousAvatarPath)
            }
            return true
        } catch {
            AppLog.settings.error("uploadAvatar failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    func removeAvatar() {
        if let path = avatarPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        self.avatarPath = nil
    }
    
    init(
        defaults: UserDefaults = .standard,
        applyAppearance: Bool = true,
        avatarStorageDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.shouldApplyAppearance = applyAppearance
        self.avatarStorageDirectory = avatarStorageDirectory ?? Self.defaultAvatarStorageDirectory()
        
        self.workMinutes       = Self.clampWorkMinutes(Self.intValue(for: Key.workMinutes, in: defaults, defaultValue: 25))
        self.shortBreakMinutes = Self.clampShortBreakMinutes(Self.intValue(for: Key.shortBreakMinutes, in: defaults, defaultValue: 5))
        self.longBreakMinutes  = Self.clampLongBreakMinutes(Self.intValue(for: Key.longBreakMinutes, in: defaults, defaultValue: 15))
        self.autoStartBreaks   = defaults.bool(forKey: Key.autoStartBreaks)
        self.autoStartWork     = defaults.bool(forKey: Key.autoStartWork)
        self.longBreakEvery    = Self.clampLongBreakEvery(
            Self.intValue(for: Key.longBreakEvery, in: defaults, defaultValue: 4)
        )
        self.strictMode        = defaults.object(forKey: Key.strictMode) as? Bool ?? false
        self.countUpWork       = defaults.bool(forKey: Key.countUpWork)
        self.soundEnabled      = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        let saved = defaults.string(forKey: Key.soundName) ?? "Glass"
        self.soundName         = NSSound.Name(saved)
        self.hapticsEnabled    = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        self.dailyGoal         = Self.clampDailyGoal(Self.intValue(for: Key.dailyGoal, in: defaults, defaultValue: 8))
        
        let savedAppearance = defaults.string(forKey: Key.appearance) ?? AppearanceMode.system.rawValue
        self.appearance        = AppearanceMode(rawValue: savedAppearance) ?? .system
        
        let savedUsername = defaults.string(forKey: Key.username)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedUsername, !savedUsername.isEmpty {
            self.username = savedUsername
        } else {
            self.username = "小番茄"
        }
        self.avatarColorIndex  = defaults.integer(forKey: Key.avatarColorIndex)
        self.avatarPath        = defaults.string(forKey: Key.avatarPath)
        // Default OFF. Never register login item here — user must enable in Settings.
        let savedLaunch = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        // Only show ON at launch if already registered in the OS (user previously opted in).
        self.launchAtLogin = LaunchAtLogin.isEnabled || savedLaunch
        
        let shortcutRaw = defaults.string(forKey: Key.toggleShortcut) ?? ToggleShortcutPreset.defaultPreset.rawValue
        self.toggleShortcut = ToggleShortcutPreset(rawValue: shortcutRaw) ?? .defaultPreset
        // Quiet-tool defaults: no Focus hint spam, no Dock bounce, no decorative motion.
        self.showFocusModeHintOnStart = defaults.object(forKey: Key.showFocusModeHint) as? Bool ?? false
        self.pauseReminderEnabled = defaults.object(forKey: Key.pauseReminderEnabled) as? Bool ?? true
        self.pauseReminderMinutes = Self.intValue(for: Key.pauseReminderMinutes, in: defaults, defaultValue: 5)
        let accentRaw = defaults.string(forKey: Key.accentPreset) ?? AccentPreset.tomato.rawValue
        let resolvedAccent = AccentPreset(rawValue: accentRaw) ?? .tomato
        self.accentPreset = resolvedAccent
        // Mirror into the shared key AppTheme reads.
        defaults.set(resolvedAccent.rawValue, forKey: "accentPreset")
        let menuStyleRaw = defaults.string(forKey: Key.menuBarDisplayStyle) ?? MenuBarDisplayStyle.iconTime.rawValue
        self.menuBarDisplayStyle = MenuBarDisplayStyle(rawValue: menuStyleRaw) ?? .iconTime
        let densityRaw = defaults.string(forKey: Key.uiDensity) ?? UIDensity.comfortable.rawValue
        self.uiDensity = UIDensity(rawValue: densityRaw) ?? .comfortable
        self.dockBounceOnComplete = defaults.object(forKey: Key.dockBounceOnComplete) as? Bool ?? false
        self.decorativeMotionEnabled = defaults.object(forKey: Key.decorativeMotionEnabled) as? Bool ?? false
        self.smartLaunchLanding = defaults.object(forKey: Key.smartLaunchLanding) as? Bool ?? true
        
        self.analyticsShowInsight = defaults.object(forKey: Key.analyticsShowInsight) as? Bool ?? true
        self.analyticsShowKPI = defaults.object(forKey: Key.analyticsShowKPI) as? Bool ?? true
        self.analyticsShowGoal = defaults.object(forKey: Key.analyticsShowGoal) as? Bool ?? true
        self.analyticsShowTrend = defaults.object(forKey: Key.analyticsShowTrend) as? Bool ?? true
        self.analyticsShowTimeline = defaults.object(forKey: Key.analyticsShowTimeline) as? Bool ?? false
        self.analyticsShowHours = defaults.object(forKey: Key.analyticsShowHours) as? Bool ?? false
        self.analyticsShowCategory = defaults.object(forKey: Key.analyticsShowCategory) as? Bool ?? false
        self.analyticsShowTaskBinding = defaults.object(forKey: Key.analyticsShowTaskBinding) as? Bool ?? false
        self.analyticsShowRecent = defaults.object(forKey: Key.analyticsShowRecent) as? Bool ?? false
        
        // Drop legacy keys that used to persist transient UI/runtime state.
        defaults.removeObject(forKey: "isLocked")
        defaults.removeObject(forKey: "isEditingName")
        defaults.removeObject(forKey: "editingNameText")
        
        applySystemAppearance()
    }
    
    private func applySystemAppearance() {
        guard shouldApplyAppearance else { return }
        DispatchQueue.main.async {
            let nsAppearance = self.appearance.toAppearance()
            NSApplication.shared.appearance = nsAppearance
            for window in NSApplication.shared.windows {
                window.appearance = nsAppearance
            }
        }
    }
    
    func sanitizeUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        username = trimmed.isEmpty ? "小番茄" : trimmed
    }
    
    static let availableSounds: [NSSound.Name] = [
        "Glass", "Blow", "Bottle", "Frog", "Funk",
        "Hero", "Morse", "Ping", "Pop", "Purr",
        "Sosumi", "Submarine", "Tink"
    ].map { NSSound.Name($0) }
    
    static func clampWorkMinutes(_ value: Int) -> Int {
        min(90, max(1, value))
    }
    
    static func clampShortBreakMinutes(_ value: Int) -> Int {
        min(30, max(1, value))
    }
    
    static func clampLongBreakMinutes(_ value: Int) -> Int {
        min(60, max(5, value))
    }
    
    static func clampDailyGoal(_ value: Int) -> Int {
        min(20, max(1, value))
    }

    static func clampLongBreakEvery(_ value: Int) -> Int {
        min(8, max(2, value))
    }

    /// Sound for UserNotifications. Custom names try app/system; nil when muted.
    func completionNotificationSound() -> UNNotificationSound? {
        guard soundEnabled else { return nil }
        // Prefer the same family as in-app NSSound names (Glass, Ping, …).
        // If the OS cannot resolve the name, fall back to default so end alerts still ring.
        let raw = (soundName as String).trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: raw))
        }
        return .default
    }
    
    private static func intValue(for key: String, in defaults: UserDefaults, defaultValue: Int) -> Int {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.integer(forKey: key)
    }

    private static func defaultAvatarStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("iFocus", isDirectory: true)
    }
}
