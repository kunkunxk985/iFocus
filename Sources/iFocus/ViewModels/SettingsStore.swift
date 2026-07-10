import Foundation
import AppKit
import SwiftUI

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
}

class SettingsStore: ObservableObject {
    private enum Key {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let autoStartBreaks = "autoStartBreaks"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let dailyGoal = "dailyGoal"
        static let appearance = "appearance"
        static let username = "username"
        static let avatarColorIndex = "avatarColorIndex"
        static let avatarPath = "avatarPath"
        static let launchAtLogin = "launchAtLogin"
        static let toggleShortcut = "toggleShortcutPreset"
        static let showFocusModeHint = "showFocusModeHintOnStart"
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
    @Published var autoStartBreaks: Bool {
        didSet { defaults.set(autoStartBreaks, forKey: Key.autoStartBreaks) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    @Published var soundName: NSSound.Name {
        didSet { defaults.set(soundName as String, forKey: Key.soundName) }
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
    
    @discardableResult
    func uploadAvatar(from url: URL) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: avatarStorageDirectory, withIntermediateDirectories: true)
        } catch {
            print("[SettingsStore] uploadAvatar failed: \(error)")
            return false
        }

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            print("[SettingsStore] uploadAvatar failed: cannot read \(url.path): \(error)")
            return false
        }

        guard let sourceImage = NSImage(data: sourceData),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[SettingsStore] uploadAvatar failed: cannot decode image from \(url.path)")
            return false
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
            print("[SettingsStore] uploadAvatar failed: cannot encode image as PNG from \(url.path)")
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
            print("[SettingsStore] uploadAvatar failed: \(error)")
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
        self.soundEnabled      = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        let saved = defaults.string(forKey: Key.soundName) ?? "Glass"
        self.soundName         = NSSound.Name(saved)
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
        
        let shortcutRaw = defaults.string(forKey: Key.toggleShortcut) ?? ToggleShortcutPreset.shiftCmdSpace.rawValue
        self.toggleShortcut = ToggleShortcutPreset(rawValue: shortcutRaw) ?? .shiftCmdSpace
        self.showFocusModeHintOnStart = defaults.object(forKey: Key.showFocusModeHint) as? Bool ?? true
        
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
