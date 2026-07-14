import AppKit
import Combine

/// Menu-bar Pro: live countdown, left-click toggle, right-click full menu.
/// Quiet tool — no mini-dashboard, no animated chrome.
///
/// `NSStatusBar.statusItem` must not be created during `App.init`.
final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private let timerStore: TimerStore
    private var cancellables: Set<AnyCancellable> = []
    private var didInstall = false
    private var launchObserver: NSObjectProtocol?
    /// Built once; content refreshed on `menuNeedsUpdate` / store changes.
    private var statusMenu: NSMenu?

    private enum MenuTag: Int {
        case countdown = 99
        case status = 100
        case progress = 107
        case task = 101
        case toggle = 102
        case freeFocus = 108
        case pickTask = 109
        case reset = 103
        case nextMode = 104
        case setMode = 110
        case openToday = 111
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.installStatusItemIfNeeded()
            }
        }

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
            button.image = Self.modeImage(for: timerStore.mode, isRunning: timerStore.isRunning)
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.toolTip = "iFocus · 左键开始/暂停 · 右键菜单"
            button.setButtonType(.momentaryLight)
            // Left-click toggles; right-click opens menu (pro quiet pattern).
            button.target = self
            button.action = #selector(statusItemPrimaryAction(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        rebuildMenu()
        // Keep menu detached until right-click so left-click can toggle.
        statusItem.menu = nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let countdownRow = NSMenuItem(title: "00:00", action: nil, keyEquivalent: "")
        countdownRow.tag = MenuTag.countdown.rawValue
        countdownRow.isEnabled = false
        menu.addItem(countdownRow)

        let statusRow = NSMenuItem(title: "状态", action: nil, keyEquivalent: "")
        statusRow.tag = MenuTag.status.rawValue
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        let progressRow = NSMenuItem(title: "今日 0/8", action: nil, keyEquivalent: "")
        progressRow.tag = MenuTag.progress.rawValue
        progressRow.isEnabled = false
        menu.addItem(progressRow)

        let taskRow = NSMenuItem(title: "任务", action: nil, keyEquivalent: "")
        taskRow.tag = MenuTag.task.rawValue
        taskRow.isEnabled = false
        menu.addItem(taskRow)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "开始", action: #selector(toggleTimer), keyEquivalent: "")
        toggleItem.tag = MenuTag.toggle.rawValue
        menu.addItem(toggleItem)

        let nextItem = NSMenuItem(title: "跳过此段", action: #selector(advanceMode), keyEquivalent: "")
        nextItem.tag = MenuTag.nextMode.rawValue
        menu.addItem(nextItem)

        let modeRoot = NSMenuItem(title: "切换模式", action: nil, keyEquivalent: "")
        modeRoot.tag = MenuTag.setMode.rawValue
        modeRoot.submenu = NSMenu(title: "模式")
        menu.addItem(modeRoot)

        menu.addItem(.separator())

        let freeItem = NSMenuItem(title: "自由专注", action: #selector(startFreeFocus), keyEquivalent: "")
        freeItem.tag = MenuTag.freeFocus.rawValue
        menu.addItem(freeItem)

        let pickRoot = NSMenuItem(title: "选择任务", action: nil, keyEquivalent: "")
        pickRoot.tag = MenuTag.pickTask.rawValue
        pickRoot.submenu = NSMenu(title: "任务")
        menu.addItem(pickRoot)

        let openToday = NSMenuItem(title: "打开今天清单", action: #selector(openTodayList), keyEquivalent: "")
        openToday.tag = MenuTag.openToday.rawValue
        menu.addItem(openToday)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(title: "重置计时…", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.tag = MenuTag.reset.rawValue
        menu.addItem(resetItem)

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
            if item.action != nil { item.target = self }
        }
        statusMenu = menu
    }

    // MARK: - Click routing

    @objc private func statusItemPrimaryAction(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggleTimer()
            return
        }
        switch event.type {
        case .rightMouseUp:
            popUpStatusMenu()
        case .leftMouseUp:
            if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
                popUpStatusMenu()
            } else {
                toggleTimer()
            }
        default:
            toggleTimer()
        }
    }

    private func popUpStatusMenu() {
        guard let statusItem, let button = statusItem.button, let menu = statusMenu else { return }
        updateStatusItem()
        // Prevent performClick from also firing the toggle action while the menu is up.
        let previousAction = button.action
        let previousTarget = button.target
        button.action = nil
        button.target = nil
        statusItem.menu = menu
        button.performClick(nil)
        // Detach menu and restore left-click toggle for the next interaction.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusItem?.menu = nil
            if let button = self.statusItem?.button {
                button.target = previousTarget ?? self
                button.action = previousAction ?? #selector(self.statusItemPrimaryAction(_:))
            }
        }
    }

    private func bindStores() {
        timerStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)

        timerStore.clockTick
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)

        if let taskStore = timerStore.taskStore {
            taskStore.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.updateStatusItem() }
                .store(in: &cancellables)
        }

        timerStore.settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem()
                self?.timerStore.refreshPauseWatchFromSettings()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let statusItem else { return }

        let time = timerStore.timeString
        let isRunning = timerStore.isRunning
        let inProgress = timerStore.isSessionInProgress
        let mode = timerStore.mode
        let goal = timerStore.settings.dailyGoal
        let done = timerStore.completedPomodoros

        let idleTooLong = timerStore.isPauseIdleTooLong
        let displayStyle = timerStore.settings.menuBarDisplayStyle
        let barText = Self.barTitle(
            timeString: time,
            mode: mode,
            isRunning: isRunning,
            isSessionInProgress: inProgress,
            completed: done,
            goal: goal,
            pauseIdleTooLong: idleTooLong,
            displayStyle: displayStyle
        )
        if let button = statusItem.button {
            button.image = Self.modeImage(for: mode, isRunning: isRunning || inProgress)
            if displayStyle == .iconOnly && !idleTooLong {
                button.attributedTitle = NSAttributedString(string: "")
                button.title = ""
            } else {
                button.attributedTitle = Self.attributedBarTitle(
                    barText,
                    mode: mode,
                    isRunning: isRunning,
                    isSessionInProgress: inProgress,
                    pauseIdleTooLong: idleTooLong
                )
            }
            button.setAccessibilityLabel(
                "iFocus \(time) 今日 \(done)/\(goal)。左键开始或暂停，右键打开菜单。"
            )
        }

        let runStateLabel = Self.runStateLabel(
            isRunning: isRunning,
            isSessionInProgress: inProgress,
            pauseIdleTooLong: idleTooLong
        )

        let taskTitle = timerStore.taskStore?.activeTask?.title
        var tooltip = "iFocus\n\(mode.rawValue) \(time) · \(runStateLabel)\n今日 \(done)/\(goal) 番茄"
        tooltip += "\n左键：开始/暂停 · 右键：菜单"
        if idleTooLong {
            tooltip += "\n已暂停 \(timerStore.pauseIdleMinutes) 分钟"
        }
        if let taskTitle, !taskTitle.isEmpty {
            tooltip += "\n当前：\(taskTitle)"
        } else if mode == .work {
            tooltip += "\n当前：自由专注"
        }
        statusItem.button?.toolTip = tooltip

        guard let menu = statusMenu else { return }

        if let countdownItem = menu.item(withTag: MenuTag.countdown.rawValue) {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
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
        menu.item(withTag: MenuTag.progress.rawValue)?.title =
            "今日  \(done) / \(goal) 番茄"

        if let taskTitle, !taskTitle.isEmpty {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：\(taskTitle)"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = false
        } else {
            menu.item(withTag: MenuTag.task.rawValue)?.title = "任务：自由专注"
            menu.item(withTag: MenuTag.task.rawValue)?.isHidden = mode != .work
        }

        menu.item(withTag: MenuTag.toggle.rawValue)?.title = Self.toggleTitle(
            mode: mode,
            isRunning: isRunning
        )
        menu.item(withTag: MenuTag.freeFocus.rawValue)?.isEnabled = true

        menu.item(withTag: MenuTag.nextMode.rawValue)?.isEnabled = true
        let skipTarget = TimerStore.nextMode(
            after: mode,
            workSessionsCompletedToday: mode == .work ? done : 0
        )
        menu.item(withTag: MenuTag.nextMode.rawValue)?.title = "跳过 → \(skipTarget.rawValue)"

        // Reset only meaningful when something is live.
        menu.item(withTag: MenuTag.reset.rawValue)?.isEnabled = isRunning || inProgress

        refreshModeSubmenu(menu)
        refreshTaskSubmenu(menu)
    }

    private func refreshModeSubmenu(_ menu: NSMenu) {
        guard let root = menu.item(withTag: MenuTag.setMode.rawValue) else { return }
        let sub = NSMenu(title: "模式")
        let running = timerStore.isRunning
        for mode in TimerMode.allCases {
            let mins: Int
            switch mode {
            case .work: mins = timerStore.settings.workMinutes
            case .shortBreak: mins = timerStore.settings.shortBreakMinutes
            case .longBreak: mins = timerStore.settings.longBreakMinutes
            }
            let item = NSMenuItem(
                title: "\(mode.rawValue)（\(mins) 分）",
                action: #selector(setModeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = timerStore.mode == mode ? .on : .off
            item.isEnabled = !running
            sub.addItem(item)
        }
        if running {
            let hint = NSMenuItem(title: "计时中不可切换（可先暂停或跳过）", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            sub.addItem(.separator())
            sub.addItem(hint)
        }
        root.submenu = sub
        root.isEnabled = true
    }

    private func refreshTaskSubmenu(_ menu: NSMenu) {
        guard let pickRoot = menu.item(withTag: MenuTag.pickTask.rawValue) else { return }
        let sub = NSMenu(title: "任务")
        let store = timerStore.taskStore

        let today = store?.tasks(for: .todayTask).filter { !$0.isCompleted } ?? []
        let pinned = (store?.tasks.filter { $0.isPinned && !$0.isCompleted } ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
        let inbox = store?.tasks(for: .inboxTask).filter { !$0.isCompleted } ?? []

        var added = 0
        added += appendTaskSection(sub, title: "今天", tasks: Array(today.prefix(10)))
        // Avoid duplicating today's pinned rows too aggressively — still list pin section if any unique.
        let pinnedExtra = pinned.filter { task in !today.contains(where: { $0.id == task.id }) }
        if !pinnedExtra.isEmpty {
            added += appendTaskSection(sub, title: "置顶", tasks: Array(pinnedExtra.prefix(6)))
        }
        let inboxExtra = inbox.filter { task in
            !today.contains(where: { $0.id == task.id })
                && !pinned.contains(where: { $0.id == task.id })
        }
        if !inboxExtra.isEmpty {
            added += appendTaskSection(sub, title: "收集箱", tasks: Array(inboxExtra.prefix(6)))
        }

        if added == 0 {
            let empty = NSMenuItem(title: "暂无待办任务", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            sub.addItem(empty)
            let open = NSMenuItem(title: "打开今天清单…", action: #selector(openTodayList), keyEquivalent: "")
            open.target = self
            sub.addItem(open)
        }

        pickRoot.submenu = sub
    }

    @discardableResult
    private func appendTaskSection(_ menu: NSMenu, title: String, tasks: [FocusTask]) -> Int {
        guard !tasks.isEmpty else { return 0 }
        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for task in tasks {
            let prefix = task.isPinned ? "📌 " : ""
            let item = NSMenuItem(
                title: prefix + task.title,
                action: #selector(selectTaskFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = task.id.uuidString
            item.state = (task.id == timerStore.taskStore?.activeTaskId) ? .on : .off
            menu.addItem(item)
        }
        return tasks.count
    }

    // MARK: - Title / icon helpers (testable)

    static func runStateLabel(
        isRunning: Bool,
        isSessionInProgress: Bool,
        pauseIdleTooLong: Bool
    ) -> String {
        if isRunning { return "进行中" }
        if pauseIdleTooLong { return "暂停过久" }
        if isSessionInProgress { return "已暂停" }
        return "待开始"
    }

    static func toggleTitle(mode: TimerMode, isRunning: Bool) -> String {
        if isRunning {
            switch mode {
            case .work: return "暂停专注"
            case .shortBreak, .longBreak: return "暂停休息"
            }
        }
        switch mode {
        case .work: return "开始专注"
        case .shortBreak: return "开始短休息"
        case .longBreak: return "开始长休息"
        }
    }

    static func barTitle(
        timeString: String,
        mode: TimerMode,
        isRunning: Bool,
        isSessionInProgress: Bool,
        completed: Int = 0,
        goal: Int = 0,
        pauseIdleTooLong: Bool = false,
        displayStyle: MenuBarDisplayStyle = .iconTime
    ) -> String {
        let progressLabel = goal > 0 ? "\(completed)/\(goal)" : timeString
        if pauseIdleTooLong {
            return " ⚠\(timeString)" + (goal > 0 ? " \(completed)/\(goal)" : "")
        }
        switch displayStyle {
        case .iconOnly:
            return ""
        case .iconTime:
            if isRunning { return " \(timeString)" }
            if isSessionInProgress { return " ⏸\(timeString)" }
            return " \(timeString)"
        case .iconProgress:
            if isRunning { return " \(progressLabel)" }
            if isSessionInProgress { return " ⏸\(progressLabel)" }
            return " \(progressLabel)"
        }
    }

    static func attributedBarTitle(
        _ text: String,
        mode: TimerMode,
        isRunning: Bool,
        isSessionInProgress: Bool,
        pauseIdleTooLong: Bool = false
    ) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let color: NSColor
        if pauseIdleTooLong {
            color = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.15, alpha: 1)
        } else {
            color = nsColor(for: mode, emphasized: isRunning || isSessionInProgress)
        }
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }

    private static func nsColor(for mode: TimerMode, emphasized: Bool) -> NSColor {
        guard emphasized else { return .labelColor }
        switch mode {
        case .work:
            return AppTheme.accentNSColor
        case .shortBreak:
            return NSColor(calibratedRed: 0.06, green: 0.73, blue: 0.51, alpha: 1)
        case .longBreak:
            return NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1)
        }
    }

    /// Compact tomato — tint shifts by mode when active (quiet signal).
    static func modeImage(for mode: TimerMode, isRunning: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let body: NSColor
        if !isRunning {
            body = NSColor(calibratedRed: 0.96, green: 0.20, blue: 0.14, alpha: 0.85)
        } else {
            switch mode {
            case .work:
                body = AppTheme.accentNSColor
            case .shortBreak:
                body = NSColor(calibratedRed: 0.06, green: 0.73, blue: 0.51, alpha: 1)
            case .longBreak:
                body = NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1)
            }
        }
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            body.setFill()
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

    // MARK: - Actions

    @objc private func toggleTimer() {
        timerStore.toggle()
        updateStatusItem()
    }

    @objc private func startFreeFocus() {
        let needsConfirm = timerStore.isRunning || timerStore.isSessionInProgress
        if needsConfirm {
            let alert = NSAlert()
            alert.messageText = "丢弃当前时段？"
            alert.informativeText = PendingSessionDiscard.startWorkFocus(nil).message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            timerStore.requestStartWorkFocus(taskId: nil, force: true)
        } else {
            timerStore.requestStartWorkFocus(taskId: nil)
        }
        updateStatusItem()
    }

    @objc private func selectTaskFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        let switching = timerStore.taskStore?.activeTaskId != id
            || timerStore.mode != .work
            || timerStore.isRunning
            || timerStore.isSessionInProgress
        let needsConfirm = (timerStore.isRunning || timerStore.isSessionInProgress)
            && !(timerStore.taskStore?.activeTaskId == id && timerStore.mode == .work && !timerStore.isRunning)
        if needsConfirm && switching {
            let alert = NSAlert()
            alert.messageText = "开始专注？"
            alert.informativeText = PendingSessionDiscard.startWorkFocus(id).message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            timerStore.requestStartWorkFocus(taskId: id, force: true)
        } else {
            timerStore.startFocus(on: id)
        }
        updateStatusItem()
    }

    @objc private func setModeFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = TimerMode(rawValue: raw) else { return }
        guard !timerStore.isRunning else { return }
        if timerStore.isSessionInProgress {
            let alert = NSAlert()
            alert.messageText = "切换模式？"
            alert.informativeText = PendingSessionDiscard.setMode(mode).message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "切换")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            timerStore.requestSetMode(mode)
            // requestSetMode queues discard while paused mid-session — confirm immediately.
            if timerStore.pendingSessionDiscard != nil {
                timerStore.confirmPendingSessionDiscard()
            }
        } else {
            timerStore.requestSetMode(mode)
        }
        updateStatusItem()
    }

    @objc private func resetTimer() {
        if timerStore.isRunning || timerStore.isSessionInProgress {
            let alert = NSAlert()
            alert.messageText = "重置当前计时？"
            alert.informativeText = "进行中的时段不会记入专注记录。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "重置")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        timerStore.celebrationMessage = nil
        timerStore.reset()
        updateStatusItem()
    }

    @objc private func advanceMode() {
        timerStore.skipToNext()
        updateStatusItem()
    }

    @objc private func openTodayList() {
        WindowChromeController.shared.showMainWindow()
        AppNavigation.post(.todayTask)
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
}

extension MenuBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateStatusItem()
    }
}
