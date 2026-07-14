import SwiftUI
import AppKit

/// Immersive focus surface — scales to the available stage so min-window
/// always shows task picker, ring, mode chips, and play controls together.
struct TimerView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.windowLayout) private var stageLayout
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
            // Full-window fluid tokens come from ContentView; local geo is the stage bounds
            // (sidebar already subtracted). Blend so widthFluid isn't stuck at 0 on the pane.
            let layout = WindowLayoutMetrics(
                width: max(geo.size.width, stageLayout.width * 0.78),
                height: max(geo.size.height, stageLayout.height * 0.96),
                densityScale: density.scale
            )
            // Ring must fit *this* pane, not the full window.
            let ringSize = TimerLayoutMath.ringSize(
                layout: layout,
                stageWidth: geo.size.width,
                stageHeight: geo.size.height,
                immersive: immersiveMode
            )

            ZStack {
                ambientBackground

                VStack(spacing: layout.sectionSpacing) {
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
                    .padding(.top, layout.stageTopChrome)

                    if !immersiveMode {
                        topMeta(layout: layout)

                        taskFocusBlock(layout: layout)
                            .frame(maxWidth: min(layout.taskBlockMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        immersiveStatusPill
                    }

                    Spacer(minLength: max(2, layout.sectionSpacing * 0.35))

                    TimerRingView(
                        size: ringSize,
                        progress: progress,
                        displayTime: displayTime,
                        modeTitle: modeTitle,
                        modeColor: modeColor,
                        isRunning: timerStore.isRunning,
                        decorativeMotion: settings.decorativeMotionEnabled,
                        ringBreath: ringBreath
                    )
                        .scaleEffect(
                            settings.decorativeMotionEnabled && celebratePulse
                            ? 1.04
                            : (settings.decorativeMotionEnabled && timerStore.isRunning && ringBreath ? 1.015 : 1)
                        )
                        .animation(
                            settings.decorativeMotionEnabled
                            ? .easeOut(duration: 0.35)
                            : .linear(duration: 0),
                            value: celebratePulse
                        )
                        .animation(
                            settings.decorativeMotionEnabled && timerStore.isRunning
                            ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.2),
                            value: ringBreath
                        )

                    Spacer(minLength: max(2, layout.sectionSpacing * 0.35))

                    if !immersiveMode {
                        modeSwitcher(layout: layout)
                            .frame(maxWidth: min(layout.modeSwitcherMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    controlButtons(layout: layout)

                    if !immersiveMode, layout.showSessionHint {
                        sessionHint
                            .padding(.bottom, TimerLayoutMath.lerp(10, 18, layout.eased))
                            .transition(.opacity)
                    } else {
                        Color.clear.frame(height: TimerLayoutMath.lerp(8, 16, layout.eased))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, layout.horizontalPadding)
                .animation(.easeInOut(duration: 0.22), value: immersiveMode)
                // Fluid resize — continuous, not snap-to-compact.
                .animation(.easeInOut(duration: 0.18), value: layout.scale)
                .animation(.easeInOut(duration: 0.18), value: ringSize)
            }
            .frame(width: layout.width, height: layout.height)
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
        guard settings.decorativeMotionEnabled else {
            ringBreath = false
            playInvite = false
            return
        }
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
        let quiet = !settings.decorativeMotionEnabled
        return ZStack {
            AppTheme.contentBackground(for: colorScheme)
            
            // Quiet tool: barely-there wash. Decorative mode: slightly richer wash.
            RadialGradient(
                colors: [
                    modeColor.opacity(quiet
                                      ? (colorScheme == .light ? 0.05 : 0.08)
                                      : (colorScheme == .light ? 0.12 : 0.16)),
                    modeColor.opacity(quiet ? 0.02 : 0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 40,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: quiet ? 0.2 : 0.4), value: timerStore.mode)
    }
    
    private var immersiveStatusPill: some View {
        HStack(spacing: 8) {
            PulseDot(
                color: timerStore.isRunning
                    ? modeColor
                    : AppTheme.secondaryText(for: colorScheme),
                isActive: timerStore.isRunning,
                size: 7,
                allowsPulse: settings.decorativeMotionEnabled
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

    // MARK: - Top meta
    
    private func topMeta(layout: WindowLayoutMetrics) -> some View {
        VStack(spacing: TimerLayoutMath.lerp(8, 12, layout.eased)) {
            // Status pill — centered
            HStack(spacing: 8) {
                PulseDot(
                    color: timerStore.isRunning
                        ? modeColor
                        : AppTheme.secondaryText(for: colorScheme),
                    isActive: timerStore.isRunning,
                    size: 7,
                    allowsPulse: settings.decorativeMotionEnabled
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
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.7 : 0.48))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                timerStore.isRunning
                                ? modeColor.opacity(0.18)
                                : AppTheme.separatorLow(for: colorScheme),
                                lineWidth: 1
                            )
                    )
            )
            
            // Goal card — single unified block (label + bar + count inside)
            VStack(spacing: TimerLayoutMath.lerp(8, 10, layout.eased)) {
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
                            .fill(AppTheme.separatorLow(for: colorScheme))
                        Capsule()
                            .fill(goalProgress >= 1 ? Color(hex: "#10B981") : modeColor)
                            .frame(width: max(goalProgress > 0 ? 6 : 0, g.size.width * goalProgress))
                            .animation(.easeInOut(duration: 0.35), value: goalProgress)
                    }
                }
                .frame(height: 5)
                
                if layout.showLongBreakRow {
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
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, layout.goalCardPaddingV)
            .frame(maxWidth: layout.goalCardMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.7 : 0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
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
            guard message != nil, settings.decorativeMotionEnabled else { return }
            celebratePulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                celebratePulse = false
            }
        }
        .onChange(of: settings.decorativeMotionEnabled) { _ in
            syncAmbientMotion()
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
    
    private func taskFocusBlock(layout: WindowLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("专注任务")
                .font(.caption.weight(.bold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 4)
            
            if let task = taskStore.activeTask {
                selectedTaskRow(task, layout: layout)
            } else {
                emptyTaskPicker(layout: layout)
            }
        }
    }
    
    private func selectedTaskRow(_ task: FocusTask, layout: WindowLayoutMetrics) -> some View {
        let glyph = TimerLayoutMath.lerp(34, 42, layout.eased)
        let titleSize = TimerLayoutMath.lerp(13.5, 15.5, layout.eased)
        let pad = TimerLayoutMath.lerp(9, 13, layout.eased)
        return Menu {
            taskMenuContent
        } label: {
            HStack(spacing: 12) {
                categoryGlyph(task.category.icon, color: task.category.color, size: glyph)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: titleSize, weight: .semibold))
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
            .padding(pad)
            .background(taskBlockBackground(emphasized: true))
        }
        .menuStyle(.borderlessButton)
        .disabled(timerStore.isRunning)
        .opacity(timerStore.isRunning ? 0.85 : 1)
    }

    private func emptyTaskPicker(layout: WindowLayoutMetrics) -> some View {
        let items = taskStore.incompleteTasks
        let glyph = TimerLayoutMath.lerp(36, 44, layout.eased)
        let titleSize = TimerLayoutMath.lerp(14, 16, layout.eased)
        let pad = TimerLayoutMath.lerp(10, 14, layout.eased)
        return Menu {
            taskMenuContent
        } label: {
            HStack(spacing: 12) {
                categoryGlyph("list.bullet", color: modeColor, size: glyph)

                VStack(alignment: .leading, spacing: 4) {
                    Text(items.isEmpty ? "暂无任务 · 可自由专注" : "选择要专注的任务")
                        .font(.system(size: titleSize, weight: .semibold))
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
                            .shadow(color: modeColor.opacity(0.22), radius: 6, y: 2)
                    )
            }
            .padding(pad)
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
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.96 : 0.78))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                    .stroke(
                        emphasized
                        ? modeColor.opacity(0.28)
                        : AppTheme.separator(for: colorScheme),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: AppTheme.softShadow(for: colorScheme).opacity(emphasized ? 1 : 0.5),
                radius: emphasized ? 8 : 4,
                y: emphasized ? 2 : 1
            )
    }
    
    // MARK: - Mode
    
    private func modeSwitcher(layout: WindowLayoutMetrics) -> some View {
        HStack(spacing: 8) {
            ForEach(TimerMode.allCases) { mode in
                let selected = timerStore.mode == mode
                Button {
                    timerStore.requestSetMode(mode)
                } label: {
                    VStack(spacing: 2) {
                        Text(mode.rawValue)
                            .font(.system(size: layout.modeChipFont, weight: .semibold))
                        Text(durationLabel(for: mode))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .opacity(0.75)
                    }
                    .foregroundColor(selected ? .white : AppTheme.primaryText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.modeChipVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                            .fill(selected ? mode.accent : AppTheme.cardBackground(for: colorScheme).opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                            .stroke(selected ? Color.clear : AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
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
    
    
    // MARK: - Controls
    
    private func controlButtons(layout: WindowLayoutMetrics) -> some View {
        let main = layout.controlMainSize
        let side = layout.controlSideSize
        let showLabels = layout.showControlLabels

        return HStack(spacing: layout.controlSpacing) {
            controlCircle(
                systemName: "forward.end.fill",
                title: "跳过",
                size: side,
                showTitle: showLabels,
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
                    if settings.decorativeMotionEnabled, !timerStore.isRunning {
                        Circle()
                            .stroke(modeColor.opacity(0.22), lineWidth: 1.5)
                            .frame(width: main + 12, height: main + 12)
                            .scaleEffect(playInvite ? 1.06 : 0.98)
                            .opacity(playInvite ? 0.2 : 0.45)
                    }

                    Circle()
                        .fill(modeColor)
                        .frame(width: main, height: main)
                        .shadow(
                            color: modeColor.opacity(settings.decorativeMotionEnabled ? 0.28 : 0.12),
                            radius: settings.decorativeMotionEnabled ? 10 : 4,
                            y: 3
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
                showTitle: showLabels,
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
        showTitle: Bool = true,
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
                if showTitle {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(tint)
                }
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
