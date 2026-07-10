import AppKit
import Combine

/// Menu-bar tomato + timer.
///
/// `NSStatusBar.statusItem` must not be created during `App.init`.
/// On newer macOS, menu extras attach via hosted scenes; creating the item
/// before `applicationDidFinishLaunching` can fatal with "missing context".
final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private let timerStore: TimerStore
    private var cancellables: Set<AnyCancellable> = []
    private var didInstall = false
    private var launchObserver: NSObjectProtocol?
    
    private enum MenuTag: Int {
        case status = 100
        case task = 101
        case toggle = 102
        case reset = 103
        case nextMode = 104
        case show = 105
        case quit = 106
    }
    
    init(timerStore: TimerStore) {
        self.timerStore = timerStore
        super.init()
        bindStores()
        
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Extra delay so AppKit finishes status-bar scene plumbing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.installStatusItemIfNeeded()
            }
        }
        
        // Late creation path (controller built after launch already finished).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            if NSApp.isRunning, !NSApp.windows.isEmpty || self.applicationHasFinishedLaunching {
                self.installStatusItemIfNeeded()
            }
        }
    }
    
    private var applicationHasFinishedLaunching: Bool {
        // After didFinishLaunching, the main menu is populated for normal apps.
        NSApp.mainMenu != nil
    }
    
    deinit {
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    private func installStatusItemIfNeeded() {
        guard !didInstall else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.installStatusItemIfNeeded() }
            return
        }
        guard NSApp.isRunning else { return }
        
        // Prefer real app-bundle launches (avoids odd CLI-only contexts).
        let bundlePath = Bundle.main.bundlePath
        let looksLikeAppBundle = bundlePath.hasSuffix(".app") || bundlePath.contains(".app/")
        guard looksLikeAppBundle else { return }
        
        didInstall = true
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        statusItem = item
        
        configureStatusItem()
        updateStatusItem()
    }
    
    private func configureStatusItem() {
        guard let statusItem else { return }
        
        if let button = statusItem.button {
            button.image = Self.tomatoImage()
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.toolTip = "iFocus"
        }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let statusRow = NSMenuItem(title: "状态", action: nil, keyEquivalent: "")
        statusRow.tag = MenuTag.status.rawValue
        statusRow.isEnabled = false
        menu.addItem(statusRow)
        
        let taskRow = NSMenuItem(title: "任务", action: nil, keyEquivalent: "")
        taskRow.tag = MenuTag.task.rawValue
        taskRow.isEnabled = false
        menu.addItem(taskRow)
        
        menu.addItem(.separator())
        
        let toggleItem = NSMenuItem(title: "开始", action: #selector(toggleTimer), keyEquivalent: "")
        toggleItem.tag = MenuTag.toggle.rawValue
        menu.addItem(toggleItem)
        
        let resetItem = NSMenuItem(title: "重置计时器", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.tag = MenuTag.reset.rawValue
        menu.addItem(resetItem)
        
        let nextItem = NSMenuItem(title: "切换到下一段", action: #selector(advanceMode), keyEquivalent: "")
        nextItem.tag = MenuTag.nextMode.rawValue
        menu.addItem(nextItem)
        
        menu.addItem(.separator())
        
        let showItem = NSMenuItem(title: "显示主界面", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.tag = MenuTag.show.rawValue
        menu.addItem(showItem)
        
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        let quitItem = NSMenuItem(title: "退出 iFocus", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.tag = MenuTag.quit.rawValue
        menu.addItem(quitItem)
        
        menu.items.forEach { item in
            if item.action != nil {
                item.target = self
            }
        }
        statusItem.menu = menu
    }
    
    private func bindStores() {
        // Structural changes (start/pause/mode) — not every clock tick.
        timerStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
        
        // Second-by-second display only — does not refresh SwiftUI task lists.
        timerStore.clockTick
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
        
        if let taskStore = timerStore.taskStore {
            taskStore.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateStatusItem()
                }
                .store(in: &cancellables)
        }
    }
    
    private func updateStatusItem() {
        guard let statusItem else { return }
        
        let modeLabel = shortModeLabel(timerStore.mode)
        let title: String
        if timerStore.isRunning {
            title = " \(modeLabel) \(timerStore.timeString)"
        } else {
            title = " \(timerStore.timeString)"
        }
        statusItem.button?.title = title
        
        let taskTitle = timerStore.taskStore?.activeTask?.title
        let runStateLabel: String = {
            if timerStore.isRunning { return "进行中" }
            if timerStore.isSessionInProgress { return "已暂停" }
            return "待开始"
        }()
        var tooltip = "iFocus · \(timerStore.mode.rawValue) \(timerStore.timeString) · \(runStateLabel)"
        if let taskTitle, !taskTitle.isEmpty {
            tooltip += "\n当前任务：\(taskTitle)"
        }
        statusItem.button?.toolTip = tooltip
        
        guard let menu = statusItem.menu else { return }
        
        menu.item(withTag: MenuTag.status.rawValue)?.title =
            "\(timerStore.mode.rawValue)  \(timerStore.timeString)  · \(runStateLabel)"
        
        if let taskTitle, !taskTitle.isEmpty {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：\(taskTitle)"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = false
        } else {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：自由专注"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = timerStore.mode != .work
        }
        
        let toggleTitle: String
        if timerStore.isRunning {
            switch timerStore.mode {
            case .work: toggleTitle = "暂停专注"
            case .shortBreak, .longBreak: toggleTitle = "暂停休息"
            }
        } else {
            switch timerStore.mode {
            case .work: toggleTitle = "开始专注"
            case .shortBreak: toggleTitle = "开始短休息"
            case .longBreak: toggleTitle = "开始长休息"
            }
        }
        menu.item(withTag: MenuTag.toggle.rawValue)?.title = toggleTitle
        
        menu.item(withTag: MenuTag.nextMode.rawValue)?.isEnabled = true
        let next = timerStore.mode.next
        menu.item(withTag: MenuTag.nextMode.rawValue)?.title = "切换到\(next.rawValue)"
    }
    
    private func shortModeLabel(_ mode: TimerMode) -> String {
        switch mode {
        case .work: return "专注"
        case .shortBreak: return "短休"
        case .longBreak: return "长休"
        }
    }
    
    @objc private func toggleTimer() {
        timerStore.toggle()
        updateStatusItem()
    }
    
    @objc private func resetTimer() {
        timerStore.reset()
        updateStatusItem()
    }
    
    @objc private func advanceMode() {
        timerStore.skipToNext()
        updateStatusItem()
    }
    
    @objc private func showMainWindow() {
        WindowChromeController.shared.showMainWindow()
    }
    
    @objc private func openSettings() {
        WindowChromeController.shared.showMainWindow()
        NotificationCenter.default.post(name: AppNavigation.openSettings, object: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private static func tomatoImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            
            NSColor(calibratedRed: 0.96, green: 0.20, blue: 0.14, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 3, y: 2.5, width: 12, height: 12)).fill()
            
            NSColor(calibratedRed: 0.18, green: 0.56, blue: 0.22, alpha: 1).setFill()
            let leaf = NSBezierPath()
            leaf.move(to: NSPoint(x: 9, y: 14.5))
            leaf.line(to: NSPoint(x: 6.5, y: 17))
            leaf.line(to: NSPoint(x: 9.2, y: 15.8))
            leaf.line(to: NSPoint(x: 11.8, y: 17))
            leaf.close()
            leaf.fill()
            
            NSColor(calibratedWhite: 1, alpha: 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: 5.5, y: 10, width: 3, height: 2)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
