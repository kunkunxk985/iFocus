import SwiftUI

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
    
    private var modeColor: Color { timerStore.mode.accent }
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
            
            // Reserve vertical space for fixed chrome so the ring absorbs the rest.
            let reserved: CGFloat =
                topChrome
                + (compact ? 8 : 14)   // after top chrome
                + (compact ? 64 : 78)  // status + goal
                + (compact ? 14 : 18)  // gap
                + (compact ? 68 : 78)  // task block
                + (compact ? 10 : 14)  // gap
                + (compact ? 56 : 72)  // mode chips
                + (compact ? 10 : 14)  // gap
                + (compact ? 72 : 88)  // controls
                + (compact ? 20 : 28)  // hint + bottom
            
            let ringBudget = max(160, h - reserved)
            let ringSize = min(
                compact ? 240 : 300 * stageScale,
                min(ringBudget, w * 0.48)
            )
            
            ZStack {
                ambientBackground
                
                VStack(spacing: compact ? 12 : 16) {
                    topMeta(compact: compact, scale: stageScale)
                        .padding(.top, topChrome + (compact ? 6 : 10))
                    
                    taskFocusBlock(compact: compact)
                        .frame(maxWidth: min(480 * stageScale, w - 40))
                    
                    Spacer(minLength: 4)
                    
                    timerRing(size: ringSize)
                    
                    Spacer(minLength: 4)
                    
                    modeSwitcher(compact: compact)
                        .frame(maxWidth: min(400 * stageScale, w - 48))
                    
                    controlButtons(compact: compact, scale: stageScale)
                    
                    sessionHint
                        .padding(.bottom, compact ? 12 : 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, compact ? 20 : 28)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onReceive(timerStore.clockTick) { _ in
            clockVersion &+= 1
        }
        .onAppear { clockVersion &+= 1 }
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
                Circle()
                    .fill(timerStore.isRunning ? modeColor : AppTheme.secondaryText(for: colorScheme).opacity(0.35))
                    .frame(width: 7, height: 7)
                    .shadow(color: timerStore.isRunning ? modeColor.opacity(0.6) : .clear, radius: 4)
                
                Text(statusLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(timerStore.isRunning ? modeColor : AppTheme.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.78 : 0.55))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    )
            )
            
            // Goal card — single unified block (label + bar + count inside)
            VStack(spacing: 8) {
                HStack {
                    Text("今日目标")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
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
                                    colors: [modeColor.opacity(0.75), modeColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, g.size.width * goalProgress))
                            .animation(.easeInOut(duration: 0.4), value: goalProgress)
                    }
                }
                .frame(height: 6)
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
        }
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
            timerStore.selectTask(nil)
        } label: {
            Label("自由专注（不关联任务）", systemImage: "sparkles")
        }
        
        if !items.isEmpty {
            Divider()
            ForEach(items) { task in
                Button {
                    timerStore.selectTask(task.id)
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
                    timerStore.setMode(mode)
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
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? Color.clear : AppTheme.separator(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(timerStore.isRunning)
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
        
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity(colorScheme == .light ? 0.10 : 0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.12, height: size * 1.12)
            
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
                .shadow(color: modeColor.opacity(0.3), radius: 12, y: 0)
            
            VStack(spacing: 6) {
                Text(displayTime)
                    .font(.system(size: max(44, size * 0.24), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                
                Text(modeTitle)
                    .font(.system(size: max(12, size * 0.05), weight: .semibold))
                    .foregroundColor(modeColor)
            }
        }
        .frame(width: size * 1.12, height: size * 1.12)
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
                timerStore.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(modeColor)
                        .frame(width: main, height: main)
                        .shadow(color: modeColor.opacity(0.4), radius: 12, y: 6)
                    
                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: main * 0.34, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: timerStore.isRunning ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(timerStore.isRunning ? "暂停 (空格)" : "开始 (空格)")
            
            controlCircle(
                systemName: "arrow.clockwise",
                title: "重置",
                size: side,
                tint: AppTheme.secondaryText(for: colorScheme),
                fill: AppTheme.cardBackground(for: colorScheme).opacity(0.75)
            ) {
                timerStore.reset()
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("重置 (⌘R)")
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
        Group {
            if timerStore.mode == .work {
                Text(taskStore.activeTask == nil
                      ? "空格开始 · 上方可选任务"
                      : "空格开始 · 将记入「\(taskStore.activeTask?.title ?? "")」")
            } else {
                Text("休息中 · ⌘→ 跳过")
            }
        }
        .font(.caption2)
        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        .lineLimit(1)
        .frame(maxWidth: 340)
    }
}
