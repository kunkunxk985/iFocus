import SwiftUI
import AppKit

/// Immersive focus surface — scales to the available stage so min-window
/// always shows task picker, ring, mode chips, and play controls together.
struct TimerView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var viewState: ContentViewState
    /// Local clock surface — driven by `clockTick`, not full store publishes.
    @State private var clockVersion: UInt = 0
    @State private var showResetConfirm = false
    @State private var showFocusModeHint = false
    @State private var celebratePulse = false
    @State private var ringBreath = false
    @State private var playInvite = false
    @AppStorage("timerImmersiveMode") private var immersiveMode = false
    
    private var modeColor: Color {
        // Work + breaks both go through TimerMode.accent (work = user accent preset).
        timerStore.mode.accent
    }
    
    private var density: UIDensity { settings.uiDensity }
    
    private var longBreakProgress: (done: Int, total: Int) {
        let until = timerStore.workSessionsUntilLongBreak
        let done = 4 - until
        return (done, 4)
    }
    private var progress: Double {
        _ = clockVersion
        return timerStore.progress
    }
    
    private var displayTime: String {
        _ = clockVersion
        return timerStore.timeString
    }
    
    private var modeTitle: String {
        switch timerStore.mode {
        case .work: return timerStore.isRunning ? "专注中" : "专注"
        case .shortBreak: return timerStore.isRunning ? "短休息中" : "短休息"
        case .longBreak: return timerStore.isRunning ? "长休息中" : "长休息"
        }
    }
    
    private var statusLabel: String {
        if timerStore.isRunning { return "进行中" }
        if timerStore.isSessionInProgress { return "已暂停" }
        return "待开始"
    }
    
    private var goalProgress: Double {
        guard settings.dailyGoal > 0 else { return 0 }
        return min(1, Double(timerStore.completedPomodoros) / Double(settings.dailyGoal))
    }
    
    var body: some View {
        GeometryReader { geo in
            // Layout budget for min height ~640 (content ≈ 640, minus chrome).
            let h = geo.size.height
            let w = geo.size.width
            let compact = h < 680
            let topChrome: CGFloat = 48
            let stageScale = compact
                ? 1
                : min(1.5, max(1, min(w / 1200, h / 820)))
            
            let d = density.scale
            // Reserve vertical space for fixed chrome so the ring absorbs the rest.
            let reserved: CGFloat =
                topChrome
                + (compact ? 8 : 14) * d
                + (immersiveMode ? 36 : (compact ? 64 : 78)) * d  // status (+ goal when not immersive)
                + (immersiveMode ? 0 : (compact ? 14 : 18) * d)
                + (immersiveMode ? 0 : (compact ? 68 : 78) * d)  // task block
                + (immersiveMode ? 0 : (compact ? 10 : 14) * d)
                + (immersiveMode ? 0 : (compact ? 56 : 72) * d)  // mode chips
                + (compact ? 10 : 14) * d
                + (compact ? 72 : 88) * d  // controls
                + (compact ? 20 : 28) * d
            
            let ringBudget = max(160, h - reserved)
            let ringSize = min(
                (compact ? 240 : 300 * stageScale) * (immersiveMode ? 1.12 : 1),
                min(ringBudget, w * (immersiveMode ? 0.55 : 0.48))
            )
            
            ZStack {
                ambientBackground
                
                VStack(spacing: (compact ? 12 : 16) * d) {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                immersiveMode.toggle()
                            }
                        } label: {
                            Label(
                                immersiveMode ? "退出沉浸" : "沉浸模式",
                                systemImage: immersiveMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(AppTheme.cardBackground(for: colorScheme).opacity(0.75))
                                    .overlay(Capsule().stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1))
                            )
                        }
                        .buttonStyle(SoftScaleButtonStyle())
                        .help(immersiveMode ? "显示任务与模式" : "只保留环与控制")
                    }
                    .padding(.top, topChrome + (compact ? 4 : 6))
                    
                    if !immersiveMode {
                        topMeta(compact: compact, scale: stageScale)
                        
                        taskFocusBlock(compact: compact)
                            .frame(maxWidth: min(480 * stageScale, w - 40))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // Minimal status pill only
                        HStack(spacing: 8) {
                            PulseDot(
                                color: timerStore.isRunning
                                    ? modeColor
                                    : AppTheme.secondaryText(for: colorScheme),
                                isActive: timerStore.isRunning,
                                size: 7
                            )
                            Text(statusLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(timerStore.isRunning ? modeColor : AppTheme.secondaryText(for: colorScheme))
                            if timerStore.mode == .work, let title = taskStore.activeTask?.title {
                                Text("·")
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                                Text(title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(AppTheme.cardBackground(for: colorScheme).opacity(0.7))
                        )
                    }
                    
                    Spacer(minLength: 4)
                    
                    timerRing(size: ringSize)
                        .scaleEffect(celebratePulse ? 1.045 : (timerStore.isRunning && ringBreath ? 1.018 : 1))
                        .animation(.spring(response: 0.38, dampingFraction: 0.62), value: celebratePulse)
                        .animation(
                            timerStore.isRunning
                            ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.3),
                            value: ringBreath
                        )
                    
                    Spacer(minLength: 4)
                    
                    if !immersiveMode {
                        modeSwitcher(compact: compact)
                            .frame(maxWidth: min(400 * stageScale, w - 48))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    controlButtons(compact: compact, scale: stageScale)
                    
                    if !immersiveMode {
                        sessionHint
                            .padding(.bottom, compact ? 12 : 18)
                    } else {
                        Color.clear.frame(height: compact ? 12 : 18)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, (compact ? 20 : 28) * d)
                .animation(.easeInOut(duration: 0.22), value: immersiveMode)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onReceive(timerStore.clockTick) { _ in
            clockVersion &+= 1
        }
        .onAppear {
            clockVersion &+= 1
            syncAmbientMotion()
        }
        .onChange(of: timerStore.isRunning) { _ in
            syncAmbientMotion()
        }
        .confirmationDialog(
            "开始专注",
            isPresented: $showFocusModeHint,
            titleVisibility: .visible
        ) {
            Button("直接开始") {
                timerStore.toggle()
            }
            Button("打开系统专注设置…") {
                openSystemFocusSettings()
                timerStore.toggle()
            }
            Button("不再提示并开始") {
                settings.showFocusModeHintOnStart = false
                timerStore.toggle()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("建议在系统设置中开启专注模式，减少通知打扰。iFocus 无法代替系统一键开关勿扰。")
        }
    }
    
    /// Start/resume work with optional Focus-mode hint (settings-controlled, default on).
    /// Hint only for a **fresh** work start — not pause/resume of an in-progress session.
    private func requestStartOrToggle() {
        let willStartWork = !timerStore.isRunning
            && !timerStore.isSessionInProgress
            && timerStore.mode == .work
            && settings.showFocusModeHintOnStart
        if willStartWork {
            showFocusModeHint = true
        } else {
            timerStore.toggle()
        }
    }
    
    private func syncAmbientMotion() {
        if timerStore.isRunning {
            ringBreath = false
            playInvite = false
            DispatchQueue.main.async {
                ringBreath = true
            }
        } else {
            ringBreath = false
            playInvite = false
            if !timerStore.isSessionInProgress {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        playInvite = true
                    }
                }
            }
        }
    }
    
    private func openSystemFocusSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Focus-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
    
    // MARK: - Ambient
    
    private var ambientBackground: some View {
        ZStack {
            AppTheme.contentBackground(for: colorScheme)
            
            RadialGradient(
                colors: [
                    modeColor.opacity(colorScheme == .light ? 0.14 : 0.18),
                    modeColor.opacity(colorScheme == .light ? 0.04 : 0.06),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 40,
                endRadius: 520
            )
            
            LinearGradient(
                colors: [
                    modeColor.opacity(colorScheme == .light ? 0.10 : 0.14),
                    modeColor.opacity(colorScheme == .light ? 0.04 : 0.06),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.32)
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: timerStore.mode)
    }
    
    // MARK: - Top meta
    
    private func topMeta(compact: Bool, scale: CGFloat) -> some View {
        VStack(spacing: compact ? 10 : 12) {
            // Status pill — centered
            HStack(spacing: 8) {
                PulseDot(
                    color: timerStore.isRunning
                        ? modeColor
                        : AppTheme.secondaryText(for: colorScheme),
                    isActive: timerStore.isRunning,
                    size: 7
                )
                
                Text(statusLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(timerStore.isRunning ? modeColor : AppTheme.secondaryText(for: colorScheme))
                
                if timerStore.mode == .work {
                    let mins = timerStore.totalSecondsToday / 60
                    Text("· 今日 \(mins) 分")
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.78 : 0.55))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                timerStore.isRunning
                                ? modeColor.opacity(0.28)
                                : AppTheme.separator(for: colorScheme),
                                lineWidth: 1
                            )
                    )
            )
            
            // Goal card — single unified block (label + bar + count inside)
            VStack(spacing: 10) {
                HStack {
                    Text(goalProgress >= 1 ? "今日目标已达成" : "今日目标")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(goalProgress >= 1 ? modeColor : AppTheme.secondaryText(for: colorScheme))
                    Spacer()
                    Text("\(timerStore.completedPomodoros) / \(settings.dailyGoal) 番茄")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                }
                
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.separator(for: colorScheme))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: goalProgress >= 1
                                    ? [Color(hex: "#10B981").opacity(0.85), Color(hex: "#10B981")]
                                    : [modeColor.opacity(0.75), modeColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(goalProgress > 0 ? 6 : 0, g.size.width * goalProgress))
                            .animation(.easeInOut(duration: 0.4), value: goalProgress)
                    }
                }
                .frame(height: 6)
                
                // Long-break cycle: visual “4 tomatoes then long rest”
                HStack(spacing: 8) {
                    Text("长休息")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < longBreakProgress.done
                                      ? AppTheme.accent
                                      : AppTheme.separator(for: colorScheme))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Spacer()
                    Text(longBreakHintText)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 420 * scale)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.82 : 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                    )
            )
            
            if timerStore.isPauseIdleTooLong {
                Button {
                    timerStore.start()
                } label: {
                    Text("已暂停 \(timerStore.pauseIdleMinutes) 分钟 · 点此继续")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: "#D97706"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: "#F59E0B").opacity(0.15))
                                .overlay(Capsule().stroke(Color(hex: "#F59E0B").opacity(0.35), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let celebration = timerStore.celebrationMessage {
                Text(celebration)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(modeColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(modeColor.opacity(0.12))
                            .overlay(Capsule().stroke(modeColor.opacity(0.25), lineWidth: 1))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                            if timerStore.celebrationMessage == celebration {
                                withAnimation { timerStore.celebrationMessage = nil }
                            }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.25), value: timerStore.celebrationMessage)
        .animation(.easeOut(duration: 0.25), value: timerStore.isPauseIdleTooLong)
        .onChange(of: timerStore.celebrationMessage) { message in
            guard message != nil else { return }
            celebratePulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                celebratePulse = false
            }
        }
    }
    
    private var longBreakHintText: String {
        if timerStore.mode == .longBreak {
            return "正在长休息"
        }
        let until = timerStore.workSessionsUntilLongBreak
        if until == 4 && timerStore.completedPomodoros > 0 && timerStore.completedPomodoros % 4 == 0 {
            return "刚完成一轮 · 下一轮 4 个"
        }
        if until == 1 {
            return "再 1 个进入长休息"
        }
        return "再 \(until) 个进入长休息"
    }
    
    // MARK: - Task
    
    private func taskFocusBlock(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("专注任务")
                .font(.caption.weight(.bold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 4)
            
            if let task = taskStore.activeTask {
                selectedTaskRow(task, compact: compact)
            } else {
                emptyTaskPicker(compact: compact)
            }
        }
    }
    
    private func selectedTaskRow(_ task: FocusTask, compact: Bool) -> some View {
        Menu {
            taskMenuContent
        } label: {
            HStack(spacing: 12) {
                categoryGlyph(task.category.icon, color: task.category.color, size: compact ? 36 : 40)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: compact ? 14 : 15, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    Text("\(task.category.rawValue) · \(task.completedPomodoros)/\(task.estimatedPomodoros) 番茄")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
                
                Spacer(minLength: 6)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .padding(compact ? 10 : 12)
            .background(taskBlockBackground(emphasized: true))
        }
        .menuStyle(.borderlessButton)
        .disabled(timerStore.isRunning)
        .opacity(timerStore.isRunning ? 0.85 : 1)
    }
    
    private func emptyTaskPicker(compact: Bool) -> some View {
        let items = taskStore.incompleteTasks
        return Menu {
            taskMenuContent
        } label: {
            HStack(spacing: 12) {
                categoryGlyph("list.bullet", color: modeColor, size: compact ? 38 : 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(items.isEmpty ? "暂无任务 · 可自由专注" : "选择要专注的任务")
                        .font(.system(size: compact ? 14.5 : 16, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text(items.isEmpty
                         ? "空格即可开始，或先去清单添加"
                         : "共 \(items.count) 个未完成 · 点此打开列表")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text(items.isEmpty ? "开始" : "选择任务")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(modeColor)
                            .shadow(color: modeColor.opacity(0.35), radius: 8, y: 3)
                    )
            }
            .padding(compact ? 12 : 14)
            .background(taskBlockBackground(emphasized: false))
        }
        .menuStyle(.borderlessButton)
    }
    
    private func categoryGlyph(_ systemName: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    @ViewBuilder
    private var taskMenuContent: some View {
        let items = taskStore.incompleteTasks
        
        Button {
            timerStore.requestStartWorkFocus(taskId: nil)
        } label: {
            Label("自由专注（不关联任务）", systemImage: "sparkles")
        }
        
        if !items.isEmpty {
            Divider()
            ForEach(items) { task in
                Button {
                    timerStore.requestStartWorkFocus(taskId: task.id)
                } label: {
                    Label {
                        Text("\(task.title)  ·  \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    } icon: {
                        Image(systemName: task.category.icon)
                    }
                }
            }
        }
        
        Divider()
        Button {
            viewState.selectedScreen = .todayTask
        } label: {
            Label("去「今天」添加任务…", systemImage: "plus.circle")
        }
    }
    
    private func taskBlockBackground(emphasized: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.95 : 0.75))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        emphasized ? modeColor.opacity(0.5) : modeColor.opacity(0.32),
                        style: StrokeStyle(lineWidth: emphasized ? 1.5 : 1.25, dash: emphasized ? [] : [5, 4])
                    )
            )
            .shadow(color: modeColor.opacity(emphasized ? 0.12 : 0.10), radius: 14, y: 5)
    }
    
    // MARK: - Mode
    
    private func modeSwitcher(compact: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(TimerMode.allCases) { mode in
                let selected = timerStore.mode == mode
                Button {
                    timerStore.requestSetMode(mode)
                } label: {
                    VStack(spacing: 2) {
                        Text(mode.rawValue)
                            .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        Text(durationLabel(for: mode))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .opacity(0.75)
                    }
                    .foregroundColor(selected ? .white : AppTheme.primaryText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 8 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? mode.accent : AppTheme.cardBackground(for: colorScheme).opacity(0.75))
                            .shadow(color: selected ? mode.accent.opacity(0.28) : .clear, radius: 8, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? Color.clear : AppTheme.separator(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(SoftScaleButtonStyle())
                .disabled(timerStore.isRunning)
                .opacity(timerStore.isRunning ? 0.55 : (timerStore.isSessionInProgress && !selected ? 0.75 : 1))
            }
        }
        .opacity(timerStore.isRunning ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.2), value: timerStore.mode)
    }
    
    private func durationLabel(for mode: TimerMode) -> String {
        switch mode {
        case .work: return "\(settings.workMinutes) 分钟"
        case .shortBreak: return "\(settings.shortBreakMinutes) 分钟"
        case .longBreak: return "\(settings.longBreakMinutes) 分钟"
        }
    }
    
    // MARK: - Ring
    
    private func timerRing(size: CGFloat) -> some View {
        let line = max(12, size * 0.06)
        let glowBoost = timerStore.isRunning ? 1.0 : 0.55
        
        return ZStack {
            // Outer soft bloom — breathes while running
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity((colorScheme == .light ? 0.14 : 0.22) * glowBoost),
                            modeColor.opacity((colorScheme == .light ? 0.05 : 0.08) * glowBoost),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.18,
                        endRadius: size * (timerStore.isRunning ? 0.62 : 0.55)
                    )
                )
                .frame(width: size * 1.22, height: size * 1.22)
                .scaleEffect(timerStore.isRunning && ringBreath ? 1.06 : 1)
                .opacity(timerStore.isRunning && ringBreath ? 0.85 : 1)
            
            Circle()
                .stroke(modeColor.opacity(colorScheme == .light ? 0.10 : 0.14), lineWidth: line)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0.001), 1)))
                .stroke(
                    AngularGradient(
                        colors: [modeColor.opacity(0.55), modeColor, modeColor.opacity(0.85)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)
                .shadow(color: modeColor.opacity(timerStore.isRunning ? 0.42 : 0.28), radius: timerStore.isRunning ? 16 : 12, y: 0)
            
            VStack(spacing: 6) {
                Text(displayTime)
                    .font(.system(size: max(44, size * 0.24), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                
                Text(modeTitle)
                    .font(.system(size: max(12, size * 0.05), weight: .semibold))
                    .foregroundColor(modeColor)
                
                if timerStore.isRunning && timerStore.mode == .work {
                    Text("保持节奏")
                        .font(.system(size: max(10, size * 0.038), weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                        .transition(.opacity)
                }
            }
        }
        .frame(width: size * 1.22, height: size * 1.22)
        .animation(.easeInOut(duration: 0.35), value: timerStore.isRunning)
    }
    
    // MARK: - Controls
    
    private func controlButtons(compact: Bool, scale: CGFloat) -> some View {
        let controlScale = min(1.25, scale)
        let main: CGFloat = (compact ? 64 : 72) * controlScale
        let side: CGFloat = (compact ? 44 : 50) * controlScale
        
        return HStack(spacing: (compact ? 24 : 30) * controlScale) {
            controlCircle(
                systemName: "forward.end.fill",
                title: "跳过",
                size: side,
                tint: AppTheme.secondaryText(for: colorScheme),
                fill: AppTheme.cardBackground(for: colorScheme).opacity(0.75)
            ) {
                timerStore.skipToNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .help("立即跳过当前段 (⌘→)")
            
            Button {
                requestStartOrToggle()
            } label: {
                ZStack {
                    // Soft invite ring when idle
                    if !timerStore.isRunning {
                        Circle()
                            .stroke(modeColor.opacity(0.28), lineWidth: 2)
                            .frame(width: main + 14, height: main + 14)
                            .scaleEffect(playInvite ? 1.08 : 0.96)
                            .opacity(playInvite ? 0.25 : 0.55)
                    }
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [modeColor, modeColor.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: main, height: main)
                        .shadow(
                            color: modeColor.opacity(timerStore.isRunning ? 0.5 : 0.38),
                            radius: timerStore.isRunning ? 16 : 12,
                            y: 6
                        )
                    
                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: main * 0.34, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: timerStore.isRunning ? 0 : 2)
                }
            }
            .buttonStyle(SoftScaleButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .help(timerStore.isRunning ? "暂停 (空格)" : "开始 (空格)")
            
            controlCircle(
                systemName: "arrow.clockwise",
                title: "重置",
                size: side,
                tint: AppTheme.secondaryText(for: colorScheme),
                fill: AppTheme.cardBackground(for: colorScheme).opacity(0.75)
            ) {
                requestReset()
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("重置 (⌘R)")
            .confirmationDialog(
                "重置当前计时？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("重置", role: .destructive) {
                    timerStore.celebrationMessage = nil
                    timerStore.reset()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("进行中的时段不会记入专注记录。")
            }
        }
    }
    
    private func requestReset() {
        if timerStore.isSessionInProgress || timerStore.isRunning {
            showResetConfirm = true
        } else {
            timerStore.celebrationMessage = nil
            timerStore.reset()
        }
    }
    
    private func controlCircle(
        systemName: String,
        title: String,
        size: CGFloat,
        tint: Color,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(fill)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(AppTheme.separator(for: colorScheme), lineWidth: 1))
                    Image(systemName: systemName)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var sessionHint: some View {
        HStack(spacing: 8) {
            if timerStore.mode == .work {
                if timerStore.isRunning {
                    KeyCap(label: "空格")
                    Text("暂停")
                    Text("·")
                        .opacity(0.4)
                    KeyCap(label: "⌘→")
                    Text("跳过")
                } else if let title = taskStore.activeTask?.title, !title.isEmpty {
                    KeyCap(label: "空格")
                    Text("开始 · \(title)")
                        .lineLimit(1)
                } else {
                    KeyCap(label: "空格")
                    Text("自由专注")
                    Text("·")
                        .opacity(0.4)
                    Text("上方可选任务")
                }
            } else {
                KeyCap(label: "空格")
                Text(timerStore.isRunning ? "暂停休息" : "开始休息")
                Text("·")
                    .opacity(0.4)
                KeyCap(label: "⌘→")
                Text("跳过")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        .lineLimit(1)
        .frame(maxWidth: 380)
        .animation(.easeOut(duration: 0.2), value: timerStore.isRunning)
        .animation(.easeOut(duration: 0.2), value: timerStore.mode)
    }
}
