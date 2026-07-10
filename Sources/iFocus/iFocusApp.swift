import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared so we can flush persistence on quit.
    static weak var taskStore: TaskStore?
    
    /// Keep the process alive for menu-bar timer when the main window is hidden.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// Dock click re-shows the main window if it was only hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowChromeController.shared.showMainWindow()
        }
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowChrome.applyAll()
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.taskStore?.flushPendingSaves()
        NSApp.dockTile.badgeLabel = nil
        NSApp.dockTile.display()
    }
}

/// Owns window chrome + close-to-hide behavior for the main window.
final class WindowChromeController: NSObject, NSWindowDelegate {
    static let shared = WindowChromeController()
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.title == "设置" {
            return true
        }
        sender.orderOut(nil)
        return false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            WindowChrome.apply(to: window)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        WindowChrome.layoutTrafficLights(in: window)
        WindowChrome.softenScrollers(in: window)
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        WindowChrome.layoutTrafficLights(in: window)
        WindowChrome.softenScrollers(in: window)
    }
    
    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let candidates = NSApplication.shared.windows.filter { window in
            window.title != "设置" && window.canBecomeKey
        }
        if let window = candidates.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let any = NSApplication.shared.windows.first {
            any.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct iFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings: SettingsStore
    @StateObject private var timerStore: TimerStore
    @StateObject private var taskStore: TaskStore
    @StateObject private var menuBarController: MenuBarController
    
    init() {
        let settings = SettingsStore()
        let taskStore = TaskStore()
        let timerStore = TimerStore(settings: settings, taskStore: taskStore)
        _settings = StateObject(wrappedValue: settings)
        _taskStore = StateObject(wrappedValue: taskStore)
        _timerStore = StateObject(wrappedValue: timerStore)
        _menuBarController = StateObject(wrappedValue: MenuBarController(timerStore: timerStore))
        AppDelegate.taskStore = taskStore
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            NSApplication.shared.appearance = settings.appearance.toAppearance()
            WindowChrome.applyAll()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                WindowChrome.apply(to: window)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(timerStore)
                .environmentObject(taskStore)
                .preferredColorScheme(settings.appearance.colorScheme)
                .frame(minWidth: AppWindow.minimumSize.width, minHeight: AppWindow.minimumSize.height)
        }
        // Hidden title text + transparent full-size content (no empty unified toolbar —
        // empty toolbars paint a solid top band that reads as a white strip).
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: AppWindow.defaultSize.width, height: AppWindow.defaultSize.height)
        .commands {
            CommandMenu("前往") {
                Button("专注钟") { AppNavigation.post(.timer) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("数据统计") { AppNavigation.post(.analytics) }
                    .keyboardShortcut("2", modifiers: .command)
                Divider()
                Button("今天") { AppNavigation.post(.todayTask) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("明天") { AppNavigation.post(.tomorrowTask) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("本周") { AppNavigation.post(.weekTask) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("收集箱") { AppNavigation.post(.inboxTask) }
                    .keyboardShortcut("6", modifiers: .command)
                Divider()
                Button("个人资料") { AppNavigation.post(.profile) }
                    .keyboardShortcut("7", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: AppNavigation.openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("专注") {
                Button("开始 / 暂停") {
                    NotificationCenter.default.post(name: AppNavigation.toggleTimer, object: nil)
                }
                Button("重置计时") {
                    NotificationCenter.default.post(name: AppNavigation.resetTimer, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("跳过当前段") {
                    NotificationCenter.default.post(name: AppNavigation.skipTimer, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
        .onChange(of: settings.appearance) { mode in
            NSApplication.shared.appearance = mode.toAppearance()
            WindowChrome.applyAll()
        }
        
        WindowGroup("设置", id: "settings") {
            SettingsWindowView()
                .environmentObject(settings)
                .environmentObject(timerStore)
                .environmentObject(taskStore)
                .preferredColorScheme(settings.appearance.colorScheme)
                .frame(
                    minWidth: AppWindow.settingsSize.width,
                    minHeight: AppWindow.settingsSize.height
                )
                .frame(width: AppWindow.settingsSize.width, height: AppWindow.settingsSize.height)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: AppWindow.settingsSize.width, height: AppWindow.settingsSize.height)
    }
}

/// Window geometry — keep in sync with `AppWindowMetrics` (settings UI copy).
private enum AppWindow {
    static let minimumSize = AppWindowMetrics.minimum
    static let defaultSize = AppWindowMetrics.defaultSize
    static let settingsSize = CGSize(width: 900, height: 600)
}

extension AppearanceMode {
    func toAppearance() -> NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

/// Minimal window chrome — transparent titlebar, relaxed traffic-light insets.
///
/// Content draws edge-to-edge under a transparent titlebar so there is no
/// solid “white strip” between the traffic lights and the app surface.
enum WindowChrome {
    static func applyAll() {
        for window in NSApplication.shared.windows where isManagedAppWindow(window) {
            apply(to: window)
        }
    }
    
    static func apply(to window: NSWindow) {
        guard isManagedAppWindow(window) else { return }
        let isSettings = window.title == "设置"
        let isFullScreen = window.styleMask.contains(.fullScreen)
        
        // Do not rebuild styleMask while fullscreen — preserves .fullScreen bit.
        if !isFullScreen {
            if isSettings {
                window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            } else {
                window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
            }
        } else {
            window.styleMask.insert(.fullSizeContentView)
        }
        
        if !isSettings {
            window.delegate = WindowChromeController.shared
        }
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        
        // Critical: no empty NSToolbar. Unified empty toolbars paint an opaque top band.
        if window.toolbar != nil {
            window.toolbar = nil
        }
        
        let targetSize = isSettings ? AppWindow.settingsSize : AppWindow.minimumSize
        window.minSize = targetSize
        if isSettings && !isFullScreen {
            window.maxSize = targetSize
            window.setContentSize(targetSize)
        }
        
        // Match content so any residual chrome blends (never pure system white).
        window.isOpaque = true
        window.backgroundColor = AppTheme.windowBackgroundColor
        window.hasShadow = true
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = AppTheme.windowBackgroundColor.cgColor
        window.contentView?.layer?.masksToBounds = false
        
        // Clear opaque titlebar container fills that can still flash as a white strip.
        clearTitlebarOpaqueFills(in: window)
        
        // Gemini-style hiddenInset traffic lights (not flush to the corner).
        layoutTrafficLights(in: window)
        // System often re-applies default frames after style changes — reassert once.
        DispatchQueue.main.async {
            layoutTrafficLights(in: window)
            softenScrollers(in: window)
        }
        softenScrollers(in: window)
    }

    /// Never restyle system panels such as NSOpenPanel/NSSavePanel. Replacing
    /// their style mask, toolbar, or scrollers leaves the picker dimmed and inert.
    private static func isManagedAppWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSSavePanel) else { return false }
        return window.title == "iFocus" || window.title == "设置"
    }
    
    /// Match Gemini / Electron `hiddenInset`: ~20pt leading, ~18pt from the window top.
    static func layoutTrafficLights(in window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen) else { return }
        guard let close = window.standardWindowButton(.closeButton),
              let mini = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let container = close.superview else { return }
        
        let btnW = close.frame.width
        let btnH = close.frame.height
        let gap = AppTheme.trafficLightSpacing
        let leading = AppTheme.trafficLightLeading
        let top = AppTheme.trafficLightTop
        
        // Anchor to the *window frame* top-leading edge (not the titlebar container’s
        // internal origin), so insets match what you see in Gemini.
        let windowTopLeftInContainer: NSPoint = {
            // Window frame is in screen space; convert top-left of window content area.
            // Titlebar buttons live in a view that spans the titlebar — use window
            // coordinates via convert from a point at (leading, windowHeight - top - btnH).
            let windowHeight = window.frame.height
            // Point in window base coordinates (origin bottom-left of window frame).
            let pointInWindow = NSPoint(
                x: leading,
                y: windowHeight - top - btnH
            )
            // Convert window → container. Use contentView if conversion through window works.
            if let content = window.contentView {
                let inContent = content.convert(pointInWindow, from: nil)
                return container.convert(inContent, from: content)
            }
            return NSPoint(
                x: leading,
                y: max(0, container.bounds.height - top - btnH)
            )
        }()
        
        var x = windowTopLeftInContainer.x
        // Keep a sane vertical clamp inside the titlebar container.
        let y = min(
            max(0, windowTopLeftInContainer.y),
            max(0, container.bounds.height - btnH)
        )
        
        for button in [close, mini, zoom] {
            let origin = NSPoint(x: round(x), y: round(y))
            if abs(button.frame.origin.x - origin.x) > 0.5
                || abs(button.frame.origin.y - origin.y) > 0.5 {
                button.setFrameOrigin(origin)
            }
            x += btnW + gap
        }
    }
    
    /// Prefer overlay / auto-hiding scrollers — never the chunky legacy track.
    static func softenScrollers(in window: NSWindow) {
        guard let root = window.contentView else { return }
        applySoftScroller(to: root)
    }
    
    private static func applySoftScroller(to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.scrollerStyle = .overlay
            scroll.autohidesScrollers = true
            // Fully hide tracks — content scrolls with trackpad / mouse wheel only.
            scroll.hasVerticalScroller = false
            scroll.hasHorizontalScroller = false
            scroll.scrollerInsets = NSEdgeInsets()
        }
        for sub in view.subviews {
            applySoftScroller(to: sub)
        }
    }
    
    private static func clearTitlebarOpaqueFills(in window: NSWindow) {
        guard let close = window.standardWindowButton(.closeButton) else { return }
        var view: NSView? = close.superview
        var depth = 0
        while let current = view, depth < 6 {
            let name = String(describing: type(of: current))
            if name.contains("Titlebar") || name.contains("Toolbar") {
                current.wantsLayer = true
                current.layer?.backgroundColor = NSColor.clear.cgColor
                if let effect = current as? NSVisualEffectView {
                    effect.material = .titlebar
                    effect.blendingMode = .withinWindow
                    effect.state = .active
                    effect.isEmphasized = false
                }
            }
            view = current.superview
            depth += 1
        }
    }
}
