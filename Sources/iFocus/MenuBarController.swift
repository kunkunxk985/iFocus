import AppKit
import Combine

/// Menu-bar tomato + live countdown (`mm:ss`).
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
        case countdown = 99
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
        item.autosaveName = "iFocus.menuBarCountdown"
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
            button.toolTip = "iFocus 倒计时"
            // Prefer attributed title for monospaced digits + mode tint.
            button.setButtonType(.momentaryLight)
        }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Large countdown row at top of menu (updates live while open via status item title).
        let countdownRow = NSMenuItem(title: "00:00", action: nil, keyEquivalent: "")
        countdownRow.tag = MenuTag.countdown.rawValue
        countdownRow.isEnabled = false
        if let font = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold) as NSFont? {
            countdownRow.attributedTitle = NSAttributedString(
                string: "00:00",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor
                ]
            )
        }
        menu.addItem(countdownRow)
        
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
        
        // Second-by-second countdown — menu bar only, not SwiftUI tree.
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
        
        let time = timerStore.timeString
        let isRunning = timerStore.isRunning
        let inProgress = timerStore.isSessionInProgress
        let mode = timerStore.mode
        
        // Menu bar button: time-first live countdown.
        let barText = Self.barTitle(
            timeString: time,
            mode: mode,
            isRunning: isRunning,
            isSessionInProgress: inProgress
        )
        if let button = statusItem.button {
            // Only attributedTitle — assigning `.title` after would wipe monospaced styling.
            button.attributedTitle = Self.attributedBarTitle(
                barText,
                mode: mode,
                isRunning: isRunning,
                isSessionInProgress: inProgress
            )
            button.setAccessibilityLabel("iFocus 倒计时 \(time)")
        }
        
        let runStateLabel: String = {
            if isRunning { return "进行中" }
            if inProgress { return "已暂停" }
            return "待开始"
        }()
        
        let taskTitle = timerStore.taskStore?.activeTask?.title
        var tooltip = "iFocus 倒计时\n\(mode.rawValue) \(time) · \(runStateLabel)"
        if let taskTitle, !taskTitle.isEmpty {
            tooltip += "\n当前任务：\(taskTitle)"
        } else if mode == .work {
            tooltip += "\n当前任务：自由专注"
        }
        statusItem.button?.toolTip = tooltip
        
        guard let menu = statusItem.menu else { return }
        
        // Big countdown at top of dropdown.
        if let countdownItem = menu.item(withTag: MenuTag.countdown.rawValue) {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
            countdownItem.attributedTitle = NSAttributedString(
                string: "  \(time)",
                attributes: [
                    .font: font,
                    .foregroundColor: Self.nsColor(for: mode, emphasized: isRunning || inProgress)
                ]
            )
        }
        
        menu.item(withTag: MenuTag.status.rawValue)?.title =
            "\(mode.rawValue)  · \(runStateLabel)"
        
        if let taskTitle, !taskTitle.isEmpty {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：\(taskTitle)"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = false
        } else {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：自由专注"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = mode != .work
        }
        
        let toggleTitle: String
        if isRunning {
            switch mode {
            case .work: toggleTitle = "暂停专注"
            case .shortBreak, .longBreak: toggleTitle = "暂停休息"
            }
        } else {
            switch mode {
            case .work: toggleTitle = "开始专注"
            case .shortBreak: toggleTitle = "开始短休息"
            case .longBreak: toggleTitle = "开始长休息"
            }
        }
        menu.item(withTag: MenuTag.toggle.rawValue)?.title = toggleTitle
        
        menu.item(withTag: MenuTag.nextMode.rawValue)?.isEnabled = true
        let next = mode.next
        menu.item(withTag: MenuTag.nextMode.rawValue)?.title = "切换到\(next.rawValue)"
    }
    
    // MARK: - Title formatting (unit-testable)
    
    /// Status-item plain text. Time is always first so the bar reads as a countdown.
    static func barTitle(
        timeString: String,
        mode: TimerMode,
        isRunning: Bool,
        isSessionInProgress: Bool
    ) -> String {
        if isRunning {
            return " \(timeString)"
        }
        if isSessionInProgress {
            return " ⏸\(timeString)"
        }
        // Idle: still show remaining (full duration) so the bar is useful at a glance.
        return " \(timeString)"
    }
    
    static func attributedBarTitle(
        _ text: String,
        mode: TimerMode,
        isRunning: Bool,
        isSessionInProgress: Bool
    ) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let color = nsColor(for: mode, emphasized: isRunning || isSessionInProgress)
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }
    
    private static func nsColor(for mode: TimerMode, emphasized: Bool) -> NSColor {
        guard emphasized else { return .labelColor }
        switch mode {
        case .work:
            return NSColor(calibratedRed: 0.90, green: 0.36, blue: 0.25, alpha: 1) // #E65C40-ish
        case .shortBreak:
            return NSColor(calibratedRed: 0.06, green: 0.73, blue: 0.51, alpha: 1) // #10B981
        case .longBreak:
            return NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1) // #3B82F6
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
