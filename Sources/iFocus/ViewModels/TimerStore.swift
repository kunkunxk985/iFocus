import Foundation
import SwiftUI
import Combine
import AppKit
import UserNotifications
import iFocusCore

enum TimerMode: String, CaseIterable, Identifiable {
    case work = "专注"
    case shortBreak = "短休息"
    case longBreak = "长休息"
    
    var id: String { rawValue }
    
    func duration(settings: SettingsStore) -> TimeInterval {
        switch self {
        case .work:        return TimeInterval(settings.workMinutes * 60)
        case .shortBreak:  return TimeInterval(settings.shortBreakMinutes * 60)
        case .longBreak:   return TimeInterval(settings.longBreakMinutes * 60)
        }
    }
    
    var accent: Color {
        switch self {
        case .work:        return Color(hex: "#E65C40")
        case .shortBreak:  return Color(hex: "#10B981")
        case .longBreak:   return Color(hex: "#3B82F6")
        }
    }
    
    var accentName: String {
        switch self {
        case .work:        return "red"
        case .shortBreak:  return "green"
        case .longBreak:   return "blue"
        }
    }
    
    var next: TimerMode {
        switch self {
        case .work:        return .shortBreak
        case .shortBreak:  return .work
        case .longBreak:   return .work
        }
    }
}

class TimerStore: ObservableObject {
    private struct WorkSessionContext {
        let taskId: UUID?
        let taskTitle: String
        let taskCategory: TaskCategory?
    }

    /// Structural state only — changing these may refresh lists/sidebars.
    @Published var mode: TimerMode = .work
    @Published var isRunning: Bool = false
    @Published var completedPomodoros: Int = 0
    @Published var notificationStatus: String = "未请求"
    
    /// High-frequency clock. NOT `@Published` — publishing every second was
    /// invalidating the entire view tree (task list + edit sheet) and freezing macOS Form.
    private(set) var timeRemaining: TimeInterval = 25 * 60
    private var todayHistorySeconds: Int = 0
    
    /// Live total focus seconds today (history + current work segment). Computed, no publish.
    var totalSecondsToday: Int {
        todayHistorySeconds + (mode == .work ? currentWorkSessionElapsedSeconds : 0)
    }
    
    /// Fine-grained clock signal for TimerView / menu bar / floating pill only.
    let clockTick = PassthroughSubject<Void, Never>()
    
    var settings: SettingsStore
    var taskStore: TaskStore?
    private var timer: Timer?
    private var targetEndDate: Date?
    /// Wall-clock start of the current running segment (for accurate elapsed logging).
    private var segmentStartedAt: Date?
    /// Accumulated elapsed seconds across pause/resume within one focus session.
    private var elapsedBeforePause: TimeInterval = 0
    /// Duration captured when the segment begins; later setting changes must not rewrite history.
    private var sessionPlannedDuration: TimeInterval?
    /// Snapshot attribution when a work session starts, so later task edits cannot steal it.
    private var workSessionContext: WorkSessionContext?
    private var isCompleting = false
    private var lifecycleObservers: [NSObjectProtocol] = []
    
    init(settings: SettingsStore, taskStore: TaskStore? = nil) {
        self.settings = settings
        self.taskStore = taskStore
        self.timeRemaining = TimeInterval(settings.workMinutes * 60)
        observeLifecycleEvents()
        if let store = taskStore {
            updateStatsFromHistory(taskStore: store)
        }
        
        // Defer UserNotifications until after launch — early access can crash when
        // the process is not yet a full app bundle session.
        let launchObs = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.bootstrapNotifications()
            }
        }
        lifecycleObservers.append(launchObs)
    }
    
    deinit {
        let workspaceNC = NSWorkspace.shared.notificationCenter
        let defaultNC = NotificationCenter.default
        for observer in lifecycleObservers {
            workspaceNC.removeObserver(observer)
            defaultNC.removeObserver(observer)
        }
        timer?.invalidate()
    }
    
    private func bootstrapNotifications() {
        guard isPackagedApp else { return }
        refreshNotificationStatus(requestIfNeeded: true)
    }
    
    /// Catch up after sleep / app reactivation using wall-clock `targetEndDate`.
    private func observeLifecycleEvents() {
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resyncFromWallClock()
            self?.updateNotificationStatus()
        }
        let active = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resyncFromWallClock()
        }
        lifecycleObservers = [wake, active]
    }
    
    private func resyncFromWallClock() {
        guard isRunning, !isCompleting else { return }
        updateTimerTick()
    }
    
    func updateNotificationStatus() {
        guard isPackagedApp else {
            notificationStatus = "仅应用版可用"
            return
        }
        refreshNotificationStatus(requestIfNeeded: false)
    }

    private func refreshNotificationStatus(requestIfNeeded: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.notificationStatus = "已授权"
                case .denied:
                    self.notificationStatus = "已拒绝"
                case .notDetermined:
                    self.notificationStatus = "未请求"
                @unknown default:
                    self.notificationStatus = "未知"
                }
                if requestIfNeeded && settings.authorizationStatus == .notDetermined {
                    self.requestNotificationPermission()
                }
            }
        }
    }

    var notificationActionTitle: String {
        switch notificationStatus {
        case "未请求": return "请求授权"
        case "已拒绝": return "打开系统设置"
        case "已授权": return "系统设置"
        default: return "刷新"
        }
    }

    func handleNotificationPermissionAction() {
        switch notificationStatus {
        case "已拒绝", "已授权":
            openSystemNotificationSettings()
        case "未请求":
            requestNotificationPermission()
        default:
            updateNotificationStatus()
        }
    }

    private var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }
    
    func updateStatsFromHistory(taskStore: TaskStore) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySessions = taskStore.focusSessions.filter { $0.timestamp >= today }
        self.completedPomodoros = todaySessions.count
        self.todayHistorySeconds = todaySessions.reduce(0) { $0 + $1.durationMinutes * 60 }
        emitClockTick()
    }
    
    var progress: Double {
        // Prefer the duration locked in at session start so mid-session setting
        // changes cannot invert the progress ring.
        let total = sessionPlannedDuration ?? mode.duration(settings: settings)
        return TimerFormatting.progress(remaining: timeRemaining, total: total)
    }
    
    var timeString: String {
        TimerFormatting.timeString(remaining: timeRemaining)
    }
    
    /// True while running, or once a segment has been started (including immediate pause).
    ///
    /// Driven only by session bookkeeping (`sessionPlannedDuration` / elapsed), never by
    /// comparing remaining time to live settings — otherwise changing duration while idle
    /// (e.g. 25 → 40 min) would look "in progress" and block duration sync.
    var isSessionInProgress: Bool {
        if isRunning { return true }
        if sessionPlannedDuration != nil { return true }
        if elapsedBeforePause > 0.01 { return true }
        return false
    }
    
    /// Update idle timer length from settings without wiping an active/paused segment.
    func syncDurationFromSettingsIfIdle() {
        guard !isSessionInProgress else { return }
        timeRemaining = mode.duration(settings: settings)
        updateDockBadge()
        emitClockTick()
    }
    
    /// Next mode after a segment finishes (long break every 4th completed work session today).
    static func nextMode(after completed: TimerMode, workSessionsCompletedToday: Int) -> TimerMode {
        if completed == .work,
           workSessionsCompletedToday > 0,
           workSessionsCompletedToday % 4 == 0 {
            return .longBreak
        }
        return completed.next
    }
    
    /// Notification copy for a finished work segment (uses session snapshot, not live active task).
    static func workCompletionBody(taskId: UUID?, taskTitle: String?, next: TimerMode) -> String {
        if taskId != nil, let title = taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return "「\(title)」已完成 · 下一个：\(next.rawValue)"
        }
        return "休息一下吧，下一个：\(next.rawValue)"
    }
    
    func toggle() {
        isRunning ? pause() : start()
    }
    
    func start() {
        guard !isRunning, !isCompleting else { return }
        if sessionPlannedDuration == nil {
            sessionPlannedDuration = max(0, elapsedBeforePause + timeRemaining)
        }
        captureWorkSessionContextIfNeeded()
        isRunning = true
        segmentStartedAt = Date()
        targetEndDate = Date().addingTimeInterval(timeRemaining)
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTimerTick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        updateTimerTick()
        updateDockBadge()
        emitClockTick()
    }
    
    func pause() {
        updateRemainingFromTarget()
        if let segmentStartedAt {
            elapsedBeforePause += Date().timeIntervalSince(segmentStartedAt)
            self.segmentStartedAt = nil
        }
        isRunning = false
        timer?.invalidate()
        timer = nil
        targetEndDate = nil
        updateDockBadge()
        emitClockTick()
    }
    
    func reset() {
        pause()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        sessionPlannedDuration = nil
        workSessionContext = nil
        timeRemaining = mode.duration(settings: settings)
        refreshStatsFromHistory()
        updateDockBadge()
        emitClockTick()
    }
    
    func setMode(_ newMode: TimerMode) {
        guard !isRunning else { return }
        mode = newMode
        reset()
        updateDockBadge()
        emitClockTick()
    }

    /// Select a task without allowing an in-progress work segment to change ownership.
    /// A running work segment restarts immediately; a paused one resets and stays paused.
    func selectTask(_ taskId: UUID?) {
        guard taskStore?.activeTaskId != taskId else { return }
        let shouldRestart = isRunning && mode == .work
        if mode == .work && (isSessionInProgress || workSessionContext != nil) {
            reset()
        }
        taskStore?.activeTaskId = taskId
        if shouldRestart {
            start()
        }
    }

    /// Start or resume focus for a task. Switching tasks always starts a fresh work segment.
    func startFocus(on taskId: UUID) {
        selectTask(taskId)
        guard !isRunning else { return }
        if mode != .work {
            setMode(.work)
        }
        start()
    }
    
    /// Skip the current segment without logging a completed pomodoro.
    func skipToNext() {
        guard !isCompleting else { return }
        pause()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        sessionPlannedDuration = nil
        workSessionContext = nil
        let next = mode.next
        mode = next
        timeRemaining = next.duration(settings: settings)
        updateDockBadge()
        emitClockTick()
    }
    
    /// Elapsed seconds in the current work segment (including pause/resume).
    private var currentWorkSessionElapsedSeconds: Int {
        guard mode == .work else { return 0 }
        return max(0, Int(currentSessionElapsed.rounded()))
    }
    
    private var currentSessionElapsed: TimeInterval {
        var elapsed = elapsedBeforePause
        if let segmentStartedAt {
            elapsed += Date().timeIntervalSince(segmentStartedAt)
        } else {
            // Fallback when completing right after pause bookkeeping cleared the segment clock.
            let total = mode.duration(settings: settings)
            elapsed = max(elapsed, total - max(0, timeRemaining))
        }
        return max(0, elapsed)
    }

    private func captureWorkSessionContextIfNeeded() {
        guard mode == .work, workSessionContext == nil else { return }
        if let task = taskStore?.activeTask {
            workSessionContext = WorkSessionContext(
                taskId: task.id,
                taskTitle: task.title,
                taskCategory: task.category
            )
        } else {
            workSessionContext = WorkSessionContext(
                taskId: nil,
                taskTitle: "自由专注",
                taskCategory: nil
            )
        }
    }
    
    private func refreshStatsFromHistory() {
        if let store = taskStore {
            updateStatsFromHistory(taskStore: store)
        }
    }
    
    private func updateRemainingFromTarget() {
        guard let targetEndDate else { return }
        timeRemaining = max(0, targetEndDate.timeIntervalSinceNow)
    }
    
    private func updateTimerTick() {
        updateRemainingFromTarget()
        emitClockTick()
        updateDockBadge()
        guard timeRemaining <= 0 else { return }
        complete()
    }
    
    /// Notify clock consumers without `objectWillChange` (avoids full-tree re-render).
    private func emitClockTick() {
        clockTick.send()
    }
    
    private func updateDockBadge() {
        DispatchQueue.main.async {
            let tile = NSApp.dockTile
            if self.isRunning {
                tile.badgeLabel = self.timeString
            } else if self.completedPomodoros > 0 {
                tile.badgeLabel = "\(self.completedPomodoros)"
            } else {
                tile.badgeLabel = nil
            }
            tile.display()
        }
    }
    
    private func complete() {
        guard !isCompleting else { return }
        isCompleting = true
        
        // Capture elapsed before pause() clears running clocks.
        let wasWork = (mode == .work)
        let previousMode = mode
        let plannedDuration = sessionPlannedDuration ?? previousMode.duration(settings: settings)
        // Sleeping past the deadline must not turn one pomodoro into hours of history.
        let elapsedSeconds = min(currentSessionElapsed, plannedDuration)
        let completedWorkContext = workSessionContext
        
        pause()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        
        if wasWork, let minutes = TimerFormatting.logMinutes(
            elapsedSeconds: elapsedSeconds,
            maximumSeconds: plannedDuration
        ) {
            if let taskId = completedWorkContext?.taskId {
                taskStore?.addFocusTime(to: taskId, minutes: minutes)
                taskStore?.logFocusSession(
                    taskId: taskId,
                    taskTitle: completedWorkContext?.taskTitle ?? "已删除任务",
                    taskCategory: completedWorkContext?.taskCategory,
                    minutes: minutes
                )
            } else {
                taskStore?.logFocusSession(
                    taskId: nil,
                    taskTitle: completedWorkContext?.taskTitle ?? "自由专注",
                    minutes: minutes
                )
            }
            if let store = taskStore {
                updateStatsFromHistory(taskStore: store)
            }
        }
        
        // Restore mode for notification copy (pause does not change mode).
        mode = previousMode
        
        let nextMode = Self.nextMode(
            after: previousMode,
            workSessionsCompletedToday: wasWork ? completedPomodoros : 0
        )
        playSound()
        sendNotification(
            completed: previousMode,
            next: nextMode,
            workTaskId: completedWorkContext?.taskId,
            workTaskTitle: completedWorkContext?.taskTitle
        )
        
        isCompleting = false
        applyCompletion(nextMode: nextMode)
        updateDockBadge()
        emitClockTick()
    }
    
    private func applyCompletion(nextMode: TimerMode) {
        elapsedBeforePause = 0
        segmentStartedAt = nil
        sessionPlannedDuration = nil
        workSessionContext = nil
        if settings.autoStartBreaks {
            mode = nextMode
            timeRemaining = nextMode.duration(settings: settings)
            start()
        } else {
            mode = nextMode
            timeRemaining = nextMode.duration(settings: settings)
        }
        updateDockBadge()
        emitClockTick()
    }
    
    private func playSound() {
        guard settings.soundEnabled else { return }
        NSSound(named: settings.soundName)?.play()
    }
    
    func requestNotificationPermission() {
        guard isPackagedApp else {
            notificationStatus = "仅应用版可用"
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            self?.updateNotificationStatus()
        }
    }

    private func openSystemNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
    
    private func sendNotification(
        completed: TimerMode,
        next: TimerMode,
        workTaskId: UUID? = nil,
        workTaskTitle: String? = nil
    ) {
        guard isPackagedApp else { return }
        let content = UNMutableNotificationContent()
        switch completed {
        case .work:
            content.title = "专注完成"
            // Use the session snapshot captured at start — active task may have been
            // deleted or edited while the timer was running.
            content.body = Self.workCompletionBody(
                taskId: workTaskId,
                taskTitle: workTaskTitle,
                next: next
            )
        case .shortBreak:
            content.title = "短休息结束"
            content.body = "准备好了吗？开始下一段专注！"
        case .longBreak:
            content.title = "长休息结束"
            content.body = "准备好了吗？开始下一段专注！"
        }
        content.sound = settings.soundEnabled ? .default : nil
        let request = UNNotificationRequest(
            identifier: "ifocus.timer.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { _ in })
    }
}
