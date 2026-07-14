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
    
    /// Break modes keep fixed hues; work always follows the user accent preset.
    var accent: Color {
        switch self {
        case .work:        return AppTheme.accent
        case .shortBreak:  return Color(hex: "#0D9488") // teal — stays distinct from 专注绿
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

/// Destructive mid-session action awaiting user confirmation.
enum PendingSessionDiscard: Equatable {
    case selectTask(UUID?)
    case freeFocus
    case setMode(TimerMode)
    /// Stop current segment (work or break) and start work on this task (nil = free).
    case startWorkFocus(UUID?)
    
    var message: String {
        switch self {
        case .selectTask:
            return "切换任务会丢弃当前进行中的时段（不记入专注记录）。确定切换？"
        case .freeFocus:
            return "开始自由专注会丢弃当前进行中的时段（不记入记录）。确定继续？"
        case .setMode:
            return "切换模式会重置当前时段（不记入记录）。确定切换？"
        case .startWorkFocus:
            return "将结束当前时段（不记入记录）并开始专注。确定继续？"
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
    @Published var notificationFeedback: String?
    /// Brief toast after a segment completes (UI clears it).
    @Published var celebrationMessage: String?
    /// Full-screen overlay when daily pomodoro goal is first crossed today.
    @Published var showDailyGoalCelebration: Bool = false
    /// Unclean-exit snapshot waiting for user to resume or discard (set at launch).
    @Published var pendingResumeSnapshot: TimerSessionSnapshot?
    /// When set, UI should confirm discarding the mid-session before applying the action.
    @Published var pendingSessionDiscard: PendingSessionDiscard?
    /// True when paused mid-session longer than the reminder threshold.
    @Published var isPauseIdleTooLong: Bool = false
    /// Whole minutes already spent paused (for UI copy).
    @Published private(set) var pauseIdleMinutes: Int = 0
    
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
    /// Optional override for tests (defaults to Application Support).
    var sessionStorageDirectory: URL?
    private var timer: Timer?
    private var pauseWatchTimer: Timer?
    private var pauseStartedAt: Date?
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
    /// Throttle dirty disk writes while the timer is running.
    private var lastDirtySnapshotAt: Date?
    private let dirtySnapshotInterval: TimeInterval = 12
    
    init(settings: SettingsStore, taskStore: TaskStore? = nil, sessionStorageDirectory: URL? = nil) {
        self.settings = settings
        self.taskStore = taskStore
        self.sessionStorageDirectory = sessionStorageDirectory
        self.timeRemaining = TimeInterval(settings.workMinutes * 60)
        observeLifecycleEvents()
        if let store = taskStore {
            updateStatsFromHistory(taskStore: store)
        }
        loadPendingResumeIfNeeded()
        
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
        pauseWatchTimer?.invalidate()
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
            self?.updateNotificationStatus()
        }
        // Midnight: refresh daily counters only when idle (don't yank stats mid-session).
        let dayChanged = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.isSessionInProgress || self.isRunning { return }
            self.refreshStatsFromHistory()
        }
        lifecycleObservers = [wake, active, dayChanged]
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
    
    /// Next mode after a segment finishes (long break every N completed work sessions today).
    static func nextMode(
        after completed: TimerMode,
        workSessionsCompletedToday: Int,
        longBreakEvery: Int = 4
    ) -> TimerMode {
        let every = max(2, longBreakEvery)
        if completed == .work,
           workSessionsCompletedToday > 0,
           workSessionsCompletedToday % every == 0 {
            return .longBreak
        }
        return completed.next
    }
    
    /// How many more work completions today until the next long break (1...N).
    var workSessionsUntilLongBreak: Int {
        Self.workSessionsUntilLongBreak(
            completedPomodorosToday: completedPomodoros,
            every: settings.longBreakEvery
        )
    }
    
    static func workSessionsUntilLongBreak(completedPomodorosToday: Int, every: Int = 4) -> Int {
        let n = max(2, every)
        let mod = max(0, completedPomodorosToday) % n
        return mod == 0 ? n : n - mod
    }
    
    static func celebrationText(
        wasWork: Bool,
        minutes: Int?,
        nextMode: TimerMode,
        completedPomodorosToday: Int,
        dailyGoal: Int,
        longBreakEvery: Int = 4
    ) -> String {
        if wasWork, let minutes {
            let untilLong = workSessionsUntilLongBreak(
                completedPomodorosToday: completedPomodorosToday,
                every: longBreakEvery
            )
            if nextMode == .longBreak {
                return "专注 \(minutes) 分钟完成 · 进入长休息"
            }
            if dailyGoal > 0, completedPomodorosToday >= dailyGoal {
                return "专注 \(minutes) 分钟 · 今日目标已达成"
            }
            if untilLong == 1 {
                return "专注 \(minutes) 分钟 · 再 1 个番茄后长休息"
            }
            return "专注 \(minutes) 分钟完成 · 下一个：\(nextMode.rawValue)"
        }
        return "\(wasWork ? "专注" : "休息")结束 · 下一个：\(nextMode.rawValue)"
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
        clearPauseIdleState()
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
        persistDirtySnapshot(force: true)
        // Industry practice: schedule wall-clock notification so end still fires if UI is throttled.
        scheduleSegmentEndNotification()
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
        cancelSegmentEndNotification()
        // Only watch idle when a session is mid-way (not a fresh full duration sitting idle).
        if isSessionInProgress {
            pauseStartedAt = Date()
            startPauseWatchIfNeeded()
        } else {
            clearPauseIdleState()
        }
        updateDockBadge()
        emitClockTick()
        persistDirtySnapshot(force: true)
    }
    
    func reset() {
        pauseWatchTimer?.invalidate()
        pauseWatchTimer = nil
        pause()
        clearPauseIdleState()
        cancelSegmentEndNotification()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        sessionPlannedDuration = nil
        workSessionContext = nil
        timeRemaining = mode.duration(settings: settings)
        refreshStatsFromHistory()
        updateDockBadge()
        emitClockTick()
        clearSessionSnapshot()
    }
    
    private func clearPauseIdleState() {
        pauseStartedAt = nil
        pauseIdleMinutes = 0
        if isPauseIdleTooLong { isPauseIdleTooLong = false }
        pauseWatchTimer?.invalidate()
        pauseWatchTimer = nil
    }
    
    private func startPauseWatchIfNeeded() {
        pauseWatchTimer?.invalidate()
        guard settings.pauseReminderEnabled else { return }
        let watch = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluatePauseIdle()
        }
        pauseWatchTimer = watch
        RunLoop.main.add(watch, forMode: .common)
        evaluatePauseIdle()
    }
    
    private func evaluatePauseIdle() {
        guard !isRunning, isSessionInProgress, let pauseStartedAt else {
            if isPauseIdleTooLong { isPauseIdleTooLong = false }
            return
        }
        guard settings.pauseReminderEnabled else {
            if isPauseIdleTooLong { isPauseIdleTooLong = false }
            return
        }
        let elapsed = Date().timeIntervalSince(pauseStartedAt)
        let minutes = Int(elapsed / 60.0)
        pauseIdleMinutes = minutes
        let threshold = max(1, settings.pauseReminderMinutes)
        let tooLong = minutes >= threshold
        if isPauseIdleTooLong != tooLong {
            isPauseIdleTooLong = tooLong
        }
        if tooLong {
            emitClockTick()
            updateDockBadge()
        }
    }
    
    func setMode(_ newMode: TimerMode) {
        requestSetMode(newMode)
    }
    
    /// Request mode change; confirms if a mid-session would be wiped.
    func requestSetMode(_ newMode: TimerMode) {
        guard newMode != mode else { return }
        // Cannot change mode chips while running — pause first (UI disables this).
        guard !isRunning else { return }
        if isSessionInProgress {
            if pendingSessionDiscard != nil { return }
            pendingSessionDiscard = .setMode(newMode)
            return
        }
        applySetMode(newMode)
    }
    
    private func applySetMode(_ newMode: TimerMode) {
        // Stop clocks if somehow still running (start-work force path).
        if isRunning {
            pause()
        }
        mode = newMode
        reset()
        updateDockBadge()
        emitClockTick()
    }

    /// Select a task. Mid-session switches ask for confirmation via `pendingSessionDiscard`.
    func selectTask(_ taskId: UUID?) {
        requestSelectTask(taskId)
    }
    
    func requestSelectTask(_ taskId: UUID?, force: Bool = false) {
        guard taskStore?.activeTaskId != taskId else { return }
        if !force && mode == .work && (isSessionInProgress || workSessionContext != nil) {
            if pendingSessionDiscard != nil { return }
            pendingSessionDiscard = .selectTask(taskId)
            return
        }
        pendingSessionDiscard = nil
        applySelectTask(taskId)
    }
    
    private func applySelectTask(_ taskId: UUID?) {
        let shouldRestart = isRunning && mode == .work
        if mode == .work && (isSessionInProgress || workSessionContext != nil) {
            reset()
        }
        taskStore?.activeTaskId = taskId
        if shouldRestart {
            start()
        }
    }
    
    /// Free focus entry (menu / deep link) with mid-session guard.
    func requestFreeFocus(force: Bool = false) {
        requestStartWorkFocus(taskId: nil, force: force)
    }
    
    /// Unified “start work focus” for task rows, deep links, menu bar.
    /// Handles running break → switch to work, mid-session discard confirm, then start.
    func requestStartWorkFocus(taskId: UUID?, force: Bool = false) {
        let sameTask = taskStore?.activeTaskId == taskId
        let needsDiscard = isRunning || isSessionInProgress || workSessionContext != nil
        
        if !force && needsDiscard {
            // Resuming same work task while paused work — just start, no discard.
            if sameTask, mode == .work, !isRunning, isSessionInProgress {
                start()
                return
            }
            // Pure toggle pause/resume on same running work task.
            if sameTask, mode == .work, isRunning {
                pause()
                return
            }
            if pendingSessionDiscard != nil { return }
            pendingSessionDiscard = .startWorkFocus(taskId)
            return
        }
        pendingSessionDiscard = nil
        applyStartWorkFocus(taskId: taskId)
    }
    
    private func applyStartWorkFocus(taskId: UUID?) {
        if isRunning || isSessionInProgress || workSessionContext != nil {
            reset()
        }
        taskStore?.activeTaskId = taskId
        if mode != .work {
            mode = .work
            timeRemaining = mode.duration(settings: settings)
            sessionPlannedDuration = nil
            elapsedBeforePause = 0
        }
        if !isRunning {
            start()
        }
        updateDockBadge()
        emitClockTick()
    }
    
    func confirmPendingSessionDiscard() {
        guard let pending = pendingSessionDiscard else { return }
        pendingSessionDiscard = nil
        switch pending {
        case .selectTask(let id), .startWorkFocus(let id):
            applyStartWorkFocus(taskId: id)
        case .freeFocus:
            applyStartWorkFocus(taskId: nil)
        case .setMode(let mode):
            applySetMode(mode)
        }
    }
    
    func cancelPendingSessionDiscard() {
        pendingSessionDiscard = nil
    }

    /// Start or resume focus for a task (unified work-intent path).
    func startFocus(on taskId: UUID) {
        requestStartWorkFocus(taskId: taskId)
    }
    
    /// Skip the current segment without logging a completed pomodoro.
    /// Next mode follows the same long-break cadence as natural completion (skip does not count as a pomodoro).
    /// Whether skip is allowed (strict mode blocks skip for a pure pomodoro flow).
    var canSkipSegment: Bool { !settings.strictMode }

    func skipToNext() {
        guard !isCompleting else { return }
        guard canSkipSegment else {
            celebrationMessage = "严格模式：不可跳过，请完成本段或重置"
            return
        }
        let previousMode = mode
        pause()
        cancelSegmentEndNotification()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        sessionPlannedDuration = nil
        workSessionContext = nil
        let next = Self.nextMode(
            after: previousMode,
            workSessionsCompletedToday: previousMode == .work ? completedPomodoros : 0,
            longBreakEvery: settings.longBreakEvery
        )
        mode = next
        timeRemaining = next.duration(settings: settings)
        updateDockBadge()
        emitClockTick()
        clearSessionSnapshot()
    }

    /// Explicit one-tap start of the prepared next segment (when auto-start is off).
    func startPreparedSegment() {
        guard !isRunning, !isCompleting else { return }
        celebrationMessage = nil
        start()
    }
    
    /// Re-arm pause idle watch when settings change while already paused.
    func refreshPauseWatchFromSettings() {
        if !isRunning, isSessionInProgress, settings.pauseReminderEnabled {
            if pauseStartedAt == nil {
                pauseStartedAt = Date()
            }
            startPauseWatchIfNeeded()
        } else if !settings.pauseReminderEnabled {
            clearPauseIdleState()
        }
    }
    
    // MARK: - Session snapshot (crash / force-quit resume)
    
    private func sessionDirectory() -> URL? {
        sessionStorageDirectory
    }
    
    private func loadPendingResumeIfNeeded() {
        guard let snap = TimerSessionPersistence.load(from: sessionDirectory()) else { return }
        if snap.shouldOfferResume {
            pendingResumeSnapshot = snap
            return
        }
        // Idle / empty snapshot left on disk — drop so we start fresh.
        TimerSessionPersistence.clear(in: sessionDirectory())
    }

    /// Refresh a restored timer snapshot after a backup import.
    func reloadPendingResumeFromDisk() {
        pendingResumeSnapshot = nil
        loadPendingResumeIfNeeded()
    }
    
    /// Build current session state for disk (always dirty while process is alive).
    func makeSessionSnapshot(cleanExit: Bool) -> TimerSessionSnapshot {
        // Prefer wall-clock remaining when running so resume is accurate after kill.
        var remaining = timeRemaining
        if isRunning, let targetEndDate {
            remaining = max(0, targetEndDate.timeIntervalSinceNow)
        }
        var elapsed = elapsedBeforePause
        if isRunning, let segmentStartedAt {
            elapsed += Date().timeIntervalSince(segmentStartedAt)
        }
        return TimerSessionSnapshot(
            mode: mode.rawValue,
            timeRemaining: remaining,
            isRunning: isRunning,
            elapsedBeforePause: elapsed,
            sessionPlannedDuration: sessionPlannedDuration,
            activeTaskId: taskStore?.activeTaskId ?? workSessionContext?.taskId,
            workTaskTitle: workSessionContext?.taskTitle ?? taskStore?.activeTask?.title,
            workTaskCategory: (workSessionContext?.taskCategory ?? taskStore?.activeTask?.category)?.rawValue,
            cleanExit: cleanExit,
            savedAt: Date()
        )
    }
    
    private func persistDirtySnapshot(force: Bool = false) {
        guard isSessionInProgress else {
            // No mid-session — avoid leaving a stale dirty file.
            if force { clearSessionSnapshot() }
            return
        }
        if !force, let last = lastDirtySnapshotAt,
           Date().timeIntervalSince(last) < dirtySnapshotInterval {
            return
        }
        lastDirtySnapshotAt = Date()
        TimerSessionPersistence.save(makeSessionSnapshot(cleanExit: false), to: sessionDirectory())
    }
    
    private func clearSessionSnapshot() {
        lastDirtySnapshotAt = nil
        TimerSessionPersistence.clear(in: sessionDirectory())
    }
    
    /// Call on clean process exit. Mid-session state is kept so next launch can resume.
    func markCleanExit() {
        if isSessionInProgress {
            // Intentional quit mid-session — still recoverable (cleanExit flag for copy only).
            TimerSessionPersistence.save(makeSessionSnapshot(cleanExit: true), to: sessionDirectory())
        } else {
            clearSessionSnapshot()
        }
    }
    
    /// Apply a pending unclean-exit snapshot (paused). User taps continue to start.
    @discardableResult
    func resumeFromPendingSnapshot() -> Bool {
        guard let snap = pendingResumeSnapshot else { return false }
        guard let restoredMode = snap.timerMode else {
            discardPendingResume()
            return false
        }
        // Stop any current clocks first.
        timer?.invalidate()
        timer = nil
        pauseWatchTimer?.invalidate()
        pauseWatchTimer = nil
        targetEndDate = nil
        segmentStartedAt = nil
        clearPauseIdleState()
        
        mode = restoredMode
        isRunning = false
        timeRemaining = max(0, snap.timeRemaining)
        elapsedBeforePause = max(0, snap.elapsedBeforePause)
        sessionPlannedDuration = snap.sessionPlannedDuration
        
        // Only reattach task id if it still exists and is incomplete.
        var restoredTaskId = snap.activeTaskId
        if let taskId = restoredTaskId {
            if let task = taskStore?.tasks.first(where: { $0.id == taskId }), !task.isCompleted {
                taskStore?.activeTaskId = taskId
            } else {
                restoredTaskId = nil
                taskStore?.activeTaskId = nil
            }
        }
        
        if restoredMode == .work {
            let category = snap.workTaskCategory.flatMap { raw in
                TaskCategory.allCases.first { $0.rawValue == raw }
            }
            workSessionContext = WorkSessionContext(
                taskId: restoredTaskId,
                taskTitle: snap.workTaskTitle ?? "自由专注",
                taskCategory: category
            )
        } else {
            workSessionContext = nil
        }
        pendingResumeSnapshot = nil
        // Restored as paused — arm pause-idle watch so long pause still nudges.
        if isSessionInProgress {
            pauseStartedAt = Date()
            startPauseWatchIfNeeded()
        }
        // Keep a dirty snapshot now that we're alive with mid-session state.
        persistDirtySnapshot(force: true)
        updateDockBadge()
        emitClockTick()
        objectWillChange.send()
        return true
    }
    
    func discardPendingResume() {
        pendingResumeSnapshot = nil
        clearSessionSnapshot()
    }
    
    func dismissDailyGoalCelebration() {
        showDailyGoalCelebration = false
    }
    
    /// YYYY-MM-dd key for once-per-day goal celebration.
    private static let goalCelebratedDayKey = "dailyGoalCelebratedDay"
    
    private func maybeTriggerDailyGoalCelebration(previousCount: Int, newCount: Int) {
        let goal = settings.dailyGoal
        guard goal > 0, newCount >= goal, previousCount < goal else { return }
        let day = Self.dayKey(for: Date())
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Self.goalCelebratedDayKey) == day { return }
        defaults.set(day, forKey: Self.goalCelebratedDayKey)
        showDailyGoalCelebration = true
    }
    
    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current
        let y = c.component(.year, from: date)
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
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
        persistDirtySnapshot(force: false)
        guard timeRemaining <= 0 else { return }
        complete()
    }
    
    /// Notify clock consumers without `objectWillChange` (avoids full-tree re-render).
    private func emitClockTick() {
        clockTick.send()
    }
    
    private func updateDockBadge() {
        DispatchQueue.main.async {
            // Unit tests and early teardown can run without an NSApplication instance.
            guard let app = NSApp else { return }
            let tile = app.dockTile
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
        clearPauseIdleState()
        elapsedBeforePause = 0
        segmentStartedAt = nil
        
        let previousPomodoros = completedPomodoros
        var loggedMinutes: Int?
        if wasWork, let minutes = TimerFormatting.logMinutes(
            elapsedSeconds: elapsedSeconds,
            maximumSeconds: plannedDuration
        ) {
            loggedMinutes = minutes
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
            maybeTriggerDailyGoalCelebration(
                previousCount: previousPomodoros,
                newCount: completedPomodoros
            )
        }
        
        // Restore mode for notification copy (pause does not change mode).
        mode = previousMode
        
        let nextMode = Self.nextMode(
            after: previousMode,
            workSessionsCompletedToday: wasWork ? completedPomodoros : 0,
            longBreakEvery: settings.longBreakEvery
        )
        celebrationMessage = Self.celebrationText(
            wasWork: wasWork,
            minutes: loggedMinutes,
            nextMode: nextMode,
            completedPomodorosToday: completedPomodoros,
            dailyGoal: settings.dailyGoal,
            longBreakEvery: settings.longBreakEvery
        )
        playCompletionRitual()
        // Cancel scheduled end fire; send an immediate completion banner instead.
        cancelSegmentEndNotification()
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
        mode = nextMode
        timeRemaining = nextMode.duration(settings: settings)
        // Industry-standard split: auto-start breaks vs auto-start work separately.
        let shouldAutoStart: Bool = {
            switch nextMode {
            case .work: return settings.autoStartWork
            case .shortBreak, .longBreak: return settings.autoStartBreaks
            }
        }()
        if shouldAutoStart {
            start()
        } else {
            clearSessionSnapshot()
        }
        updateDockBadge()
        emitClockTick()
    }

    // MARK: - Scheduled end notification (more reliable than in-app timer alone)

    private static let segmentEndNotificationId = "ifocus.timer.segmentEnd"

    private func scheduleSegmentEndNotification() {
        cancelSegmentEndNotification()
        guard isPackagedApp else { return }
        let remaining = max(1, timeRemaining)
        // Don't schedule multi-hour-ish edges as noisy; still cover normal pomodoro lengths.
        guard remaining <= 3 * 60 * 60 else { return }

        let content = UNMutableNotificationContent()
        switch mode {
        case .work:
            content.title = "专注即将完成"
            content.body = "本段专注已到时。打开 iFocus 查看下一段。"
        case .shortBreak:
            content.title = "短休息结束"
            content.body = "准备好了吗？开始下一段专注。"
        case .longBreak:
            content.title = "长休息结束"
            content.body = "准备好了吗？开始下一段专注。"
        }
        content.sound = settings.completionNotificationSound()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.segmentEndNotificationId,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { _ in })
    }

    private func cancelSegmentEndNotification() {
        guard isPackagedApp else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.segmentEndNotificationId])
        // Also clear delivered banner with same id if user already saw it mid-resume.
        center.removeDeliveredNotifications(withIdentifiers: [Self.segmentEndNotificationId])
    }
    
    /// Sound + optional Dock bounce when a segment finishes.
    private func playCompletionRitual() {
        if settings.soundEnabled {
            NSSound(named: settings.soundName)?.play()
        }
        if settings.dockBounceOnComplete {
            DispatchQueue.main.async {
                // Single bounce; clears when user activates the app.
                NSApp.requestUserAttention(.informationalRequest)
            }
        }
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

    func sendTestNotification() {
        guard isPackagedApp else {
            notificationFeedback = "仅应用版可发送通知"
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] notificationSettings in
            guard let self else { return }
            guard notificationSettings.authorizationStatus == .authorized ||
                    notificationSettings.authorizationStatus == .provisional else {
                DispatchQueue.main.async {
                    self.notificationFeedback = "请先在系统设置中允许通知"
                    self.updateNotificationStatus()
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "iFocus 通知测试"
            content.body = "通知已正常启用，专注结束时会在这里提醒你。"
            content.sound = self.settings.completionNotificationSound()
            let request = UNNotificationRequest(
                identifier: "ifocus.test.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                DispatchQueue.main.async {
                    if let error {
                        self.notificationFeedback = "发送失败：\(error.localizedDescription)"
                    } else {
                        self.notificationFeedback = "测试通知已发送"
                    }
                }
            }
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
        content.sound = settings.completionNotificationSound()
        let request = UNNotificationRequest(
            identifier: "ifocus.timer.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { _ in })
    }
}
