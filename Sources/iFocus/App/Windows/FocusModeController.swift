import AppKit
import Combine

/// Full-screen focus: hides the sidebar and window chrome through native full screen,
/// forces the timer's immersive stage, and restores the previous state on exit.
@MainActor
final class FocusModeController: ObservableObject {
    static let shared = FocusModeController()

    @Published private(set) var isActive = false

    private weak var window: NSWindow?
    private var enteredFullScreen = false
    private var previousImmersive = false
    private var toggleObserver: NSObjectProtocol?
    private var fullScreenExitObserver: NSObjectProtocol?

    private init() {
        toggleObserver = NotificationCenter.default.addObserver(
            forName: AppNavigation.toggleFocusMode,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.toggle() }
        }
        fullScreenExitObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self, self.isActive,
                      let window = note.object as? NSWindow,
                      window === self.window else { return }
                // The user left native full screen directly (green button / menu).
                self.finish(exitFullScreen: false)
            }
        }
    }

    func toggle() {
        isActive ? exit() : enter()
    }

    func enter() {
        guard !isActive, let window = mainWindow() else { return }
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)

        self.window = window
        isActive = true
        previousImmersive = UserDefaults.standard.bool(forKey: "timerImmersiveMode")
        UserDefaults.standard.set(true, forKey: "timerImmersiveMode")
        enteredFullScreen = !window.styleMask.contains(.fullScreen)
        if enteredFullScreen {
            window.toggleFullScreen(nil)
        }
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    func exit() {
        finish(exitFullScreen: enteredFullScreen)
    }

    private func finish(exitFullScreen: Bool) {
        guard isActive else { return }
        isActive = false
        UserDefaults.standard.set(previousImmersive, forKey: "timerImmersiveMode")
        NSCursor.setHiddenUntilMouseMoves(false)

        guard let window else {
            enteredFullScreen = false
            return
        }
        if exitFullScreen, window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        enteredFullScreen = false
        self.window = nil
    }

    private func mainWindow() -> NSWindow? {
        NSApplication.shared.windows.first(where: { $0.title == "iFocus" && $0.canBecomeKey })
            ?? NSApplication.shared.windows.first(where: { $0.title == "iFocus" })
    }
}
