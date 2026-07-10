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
