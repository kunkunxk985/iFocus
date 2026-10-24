import AppKit
import Combine
import SwiftUI

/// Borderless floating panel with a compact timer. It stays above normal windows
/// and on every Space, without activating the app or taking keyboard focus.
@MainActor
final class FloatingTimerWindowController: NSObject, NSWindowDelegate {
    static let shared = FloatingTimerWindowController()

    private var panel: NSPanel?
    private var timerStore: TimerStore?
    private var toggleObserver: NSObjectProtocol?
    private var frameKey = "miniTimerCircleFrame"
    private let panelSide: CGFloat = 176

    func configure(timerStore: TimerStore) {
        self.timerStore = timerStore
        guard toggleObserver == nil else { return }
        toggleObserver = NotificationCenter.default.addObserver(
            forName: AppNavigation.toggleMiniTimer,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.toggle() }
        }
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let timerStore, let taskStore = timerStore.taskStore else { return }
        if panel == nil {
            buildPanel(timerStore: timerStore, taskStore: taskStore, settings: timerStore.settings)
        }
        guard let panel else { return }
        panel.setFrame(constrainedFrame(panel.frame), display: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel(timerStore: TimerStore, taskStore: TaskStore, settings: SettingsStore) {
        let root = MiniTimerView(
            timerStore: timerStore,
            taskStore: taskStore,
            settings: settings,
            onClose: { [weak self] in self?.hide() },
            onOpenMain: { [weak self] in
                self?.hide()
                WindowChromeController.shared.showMainWindow()
                AppNavigation.post(.timer)
            }
        )
        let hosting = NSHostingController(rootView: root)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSide, height: panelSide),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.setFrame(savedFrame() ?? defaultFrame(), display: false)
        self.panel = panel
    }

    private func defaultFrame() -> NSRect {
        guard let screen = NSScreen.main?.visibleFrame else {
            return NSRect(x: 40, y: 40, width: panelSide, height: panelSide)
        }
        return NSRect(
            x: screen.maxX - panelSide - 24,
            y: screen.maxY - panelSide - 24,
            width: panelSide,
            height: panelSide
        )
    }

    private func savedFrame() -> NSRect? {
        guard let raw = UserDefaults.standard.string(forKey: frameKey) else { return nil }
        let frame = NSRectFromString(raw)
        guard frame.width > 80, frame.height > 80 else { return nil }
        return constrainedFrame(frame)
    }

    private func constrainedFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) })
                ?? NSScreen.main else { return frame }
        let visible = screen.visibleFrame
        var result = frame
        if result.maxX < visible.minX + 40 { result.origin.x = visible.minX + 40 }
        if result.maxY < visible.minY + 40 { result.origin.y = visible.minY + 40 }
        if result.minX > visible.maxX - 40 { result.origin.x = visible.maxX - result.width - 40 }
        if result.minY > visible.maxY - 40 { result.origin.y = visible.maxY - result.height - 40 }
        return result
    }

    private func saveFrame() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
    }
}
