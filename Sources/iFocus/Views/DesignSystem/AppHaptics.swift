import AppKit

/// Clean, centralized haptics feedback engine for tactile micro-interactions.
///
/// Wraps `NSHapticFeedbackManager.defaultPerformer` with user preference checks
/// (`SettingsStore.hapticsEnabled`, default enabled).
public enum AppHaptics {
    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    /// Level change haptic pattern when a task is completed.
    public static func taskCompleted() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    /// Generic tactile click on primary control buttons (play/pause/skip/reset).
    public static func buttonClick() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    /// Alignment notch feedback when switching timer modes (work/shortBreak/longBreak).
    public static func modeSwitched() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    /// Subtle alignment feedback for picking presets, color swatches, or tabs.
    public static func selectionChanged() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
