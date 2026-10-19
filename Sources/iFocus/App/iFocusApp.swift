import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Shared so we can flush persistence on quit.
    static weak var taskStore: TaskStore?
    /// Shared for `ifocus://` deep links and clean-exit snapshot.
    static weak var timerStore: TimerStore?
    
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
        UNUserNotificationCenter.current().delegate = self
        WindowChrome.applyAll()
        NSApp.setActivationPolicy(.regular)

        // Sanitize corrupted fullscreen window frame if present
        if let saved = WindowLayoutStore.savedMainWindowFrame(),
           let screen = NSScreen.main,
           saved.size == screen.frame.size {
            UserDefaults.standard.removeObject(forKey: "mainWindowFrame")
        }
        WindowLayoutStore.restoreMainWindowIfPossible()
        ViewMenuSanitizer.attachToViewMenu()
        DispatchQueue.main.async {
            ViewMenuSanitizer.attachToViewMenu()
        }

        // Observe frame changes on the main window for layout memory.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow,
                  window.title != "设置",
                  !window.styleMask.contains(.fullScreen),
                  !WindowStateModel.shared.isFullScreen,
                  !WindowStateModel.shared.isTransitioningFullScreen else { return }
            if let screen = window.screen, window.frame.size == screen.frame.size { return }
            WindowLayoutStore.saveMainWindowFrame(window.frame)
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow,
                  window.title != "设置",
                  !window.styleMask.contains(.fullScreen),
                  !WindowStateModel.shared.isFullScreen,
                  !WindowStateModel.shared.isTransitioningFullScreen else { return }
            if let screen = window.screen, window.frame.size == screen.frame.size { return }
            WindowLayoutStore.saveMainWindowFrame(window.frame)
        }
    }
    
    /// `ifocus://start` / `ifocus://open?screen=today` etc. (registered in Info.plist).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let timerStore = AppDelegate.timerStore else { return }
        for url in urls {
            DeepLinkRouter.handle(url, timerStore: timerStore)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.timerStore?.markCleanExit()
        AppDelegate.taskStore?.flushPendingSaves()
        NSApp.dockTile.badgeLabel = nil
        NSApp.dockTile.display()
    }
}

/// Sanitizes the standard View menu to prevent duplicate full-screen commands.
final class ViewMenuSanitizer: NSObject, NSMenuDelegate {
    static let shared = ViewMenuSanitizer()
    private var isSanitizing = false

    func menuNeedsUpdate(_ menu: NSMenu) {
        sanitize(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        sanitize(menu)
    }

    func sanitize(_ menu: NSMenu) {
        guard !isSanitizing else { return }
        isSanitizing = true
        defer { isSanitizing = false }

        let indicesToRemove = menu.items.indices.filter { idx in
            let item = menu.items[idx]
            return item.action == #selector(NSWindow.toggleFullScreen(_:))
                || item.title.contains("全屏幕")
                || item.title == "Enter Full Screen"
                || item.title == "Exit Full Screen"
        }
        for idx in indicesToRemove.reversed() {
            menu.removeItem(at: idx)
        }
    }

    static func attachToViewMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }
        for item in mainMenu.items {
            if let submenu = item.submenu {
                let isViewMenu = item.title == "显示"
                    || item.title == "View"
                    || submenu.items.contains {
                        $0.title == "展开侧栏" || $0.title == "收起侧栏"
                        || $0.title == "进入全屏" || $0.title == "退出全屏"
                    }
                if isViewMenu {
                    submenu.delegate = shared
                    shared.sanitize(submenu)
                }
            }
        }
    }
}

/// Owns window chrome + close-to-hide behavior for the main window.
final class WindowChromeController: NSObject, NSWindowDelegate {
    static let shared = WindowChromeController()
    
    private final class FullScreenExitToken {
        var observer: NSObjectProtocol?
    }

    static func closeOrHide(window: NSWindow) {
        if window.title == "设置" {
            window.close()
            return
        }
        if window.styleMask.contains(.fullScreen) {
            let token = FullScreenExitToken()
            token.observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: window,
                queue: .main
            ) { _ in
                if let obs = token.observer {
                    NotificationCenter.default.removeObserver(obs)
                    token.observer = nil
                }
                window.orderOut(nil)
            }
            window.toggleFullScreen(nil)
        } else {
            window.orderOut(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.title == "设置" {
            return true
        }
        WindowChromeController.closeOrHide(window: sender)
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
    @StateObject private var windowState = WindowStateModel.shared
    
    init() {
        let settings = SettingsStore()
        // Copy the data files aside on the first launch of a new version, before anything reads them.
        let preUpgradeFolder = PreUpgradeGuard.run(
            storageDirectory: TaskStore.defaultStorageDirectory(),
            currentVersion: AppVersion.short
        )
        let taskStore = TaskStore(studyLogDirectory: StudyLogWriter.defaultDirectory())
        if let preUpgradeFolder, taskStore.skippedItemsOnLoad > 0 {
            taskStore.upgradeNotice = PreUpgradeGuard.skippedItemsNotice(
                count: taskStore.skippedItemsOnLoad,
                folder: preUpgradeFolder
            )
        }
        let timerStore = TimerStore(settings: settings, taskStore: taskStore)
        _settings = StateObject(wrappedValue: settings)
        _taskStore = StateObject(wrappedValue: taskStore)
        _timerStore = StateObject(wrappedValue: timerStore)
        _menuBarController = StateObject(wrappedValue: MenuBarController(timerStore: timerStore))
        AppDelegate.taskStore = taskStore
        AppDelegate.timerStore = timerStore
        
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
                // `ifocus://` links are handled by AppDelegate → DeepLinkRouter. Let the existing
                // main window take the URL event; otherwise SwiftUI opens one more window per link.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        // Hidden title text + transparent full-size content (no empty unified toolbar —
        // empty toolbars paint a solid top band that reads as a white strip).
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: AppWindow.defaultSize.width, height: AppWindow.defaultSize.height)
        .commands {
            CommandGroup(replacing: .sidebar) {
                Button(windowState.isSidebarCollapsed ? "展开侧栏" : "收起侧栏") {
                    NotificationCenter.default.post(name: AppNavigation.toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.control, .command])

                Divider()

                Button(windowState.isFullScreen ? "退出全屏" : "进入全屏") {
                    let window = (NSApp.keyWindow?.title != "设置" ? NSApp.keyWindow : nil)
                        ?? NSApplication.shared.windows.first(where: { $0.title == "iFocus" && $0.canBecomeKey })
                        ?? NSApplication.shared.windows.first(where: { $0.title == "iFocus" })
                    window?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }

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
                .keyboardShortcut(
                    settings.toggleShortcut.keyEquivalent,
                    modifiers: settings.toggleShortcut.modifiers
                )
                Button("重置计时") {
                    NotificationCenter.default.post(name: AppNavigation.resetTimer, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("跳过当前段") {
                    NotificationCenter.default.post(name: AppNavigation.skipTimer, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
            CommandMenu("任务") {
                Button("搜索任务") {
                    NotificationCenter.default.post(name: AppNavigation.searchTasks, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("新建任务") {
                    NotificationCenter.default.post(name: AppNavigation.newTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .onChange(of: settings.appearance) { mode in
            NSApplication.shared.appearance = mode.toAppearance()
            WindowChrome.applyAll()
        }
        
        Window("设置", id: "settings") {
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

/// Minimal window chrome — transparent titlebar with native traffic-light geometry.
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
            let mask: NSWindow.StyleMask = isSettings
                ? [.titled, .closable, .miniaturizable, .fullSizeContentView]
                : [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
            // This runs on every didBecomeKey; reassigning an unchanged mask still rebuilds the
            // titlebar, which can swallow the click that made the window key (e.g. on close).
            if window.styleMask != mask {
                window.styleMask = mask
            }
        } else {
            window.styleMask.insert(.fullSizeContentView)
        }

        if isSettings {
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        } else {
            window.collectionBehavior.insert(.fullScreenPrimary)
            ViewMenuSanitizer.attachToViewMenu()
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
        
        // Settings size is pinned by SwiftUI (fixed frame + `.contentSize`), which adds the
        // titlebar inset (frame 900×628). Forcing a 900×600 content size here fought that on
        // every didBecomeKey and resized the window inside the click that made it key.
        let targetSize = isSettings ? AppWindow.settingsSize : AppWindow.minimumSize
        window.minSize = targetSize
        
        // Non-opaque keeps the system's rounded corners clean. The fill is the app canvas, not
        // `.clear`: SwiftUI can leave a strip unpainted (seen at the bottom of the sidebar
        // column, 4–32pt tall), and a clear window then shows the desktop through it.
        window.isOpaque = false
        window.backgroundColor = AppTheme.windowBackgroundColor
        window.hasShadow = true
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.layer?.masksToBounds = false
        
        // Clear opaque titlebar container fills that can still flash as a white strip.
        clearTitlebarOpaqueFills(in: window)
        
        // Keep AppKit's native traffic-light appearance and standard geometry.
        layoutTrafficLights(in: window)
        // AppKit may recreate titlebar buttons after style changes; reassert visibility once.
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
    
    /// Preserve AppKit's native traffic-light frames, colors, and active/inactive appearance.
    static func layoutTrafficLights(in window: NSWindow) {
        guard isManagedAppWindow(window) else { return }
        guard !window.styleMask.contains(.fullScreen) else { return }
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]
        for case let button? in buttons {
            button.isHidden = false
        }
    }
    
    /// Reaffirm native traffic-light visibility after window appearance changes.
    static func layoutMainWindowTrafficLights() {
        for window in NSApplication.shared.windows where isManagedAppWindow(window) {
            layoutTrafficLights(in: window)
            DispatchQueue.main.async {
                layoutTrafficLights(in: window)
            }
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
                    if #available(macOS 26.0, *) {
                        // Preserve the platform's Liquid Glass titlebar material.
                        effect.state = .followsWindowActiveState
                    } else {
                        effect.material = .titlebar
                        effect.blendingMode = .withinWindow
                        effect.state = .active
                    }
                    effect.isEmphasized = false
                }
            }
            view = current.superview
            depth += 1
        }
    }
}
