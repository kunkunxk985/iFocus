import SwiftUI

/// The menu-bar popover: the quickest way to see the current session and steer it
/// without opening the main window. The full NSMenu remains on right-click.
struct MenuBarPanelView: View {
    @ObservedObject var timerStore: TimerStore
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var settings: SettingsStore

    let onClose: () -> Void
    let onOpenMain: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0

    private var modeColor: Color { timerStore.mode.accent }

    private var stateLabel: String {
        if timerStore.isRunning { return "\(timerStore.mode.rawValue)中" }
        if timerStore.isPauseIdleTooLong { return "暂停过久" }
        if timerStore.isSessionInProgress { return "已暂停" }
        return "待开始"
    }

    private var taskTitle: String {
        if let title = taskStore.activeTask?.title, !title.isEmpty { return title }
        return timerStore.mode == .work ? "自由专注" : "—"
    }

    private var time: String {
        _ = clockVersion
        return timerStore.timeString
    }

    private var progress: Double {
        _ = clockVersion
        return timerStore.progress
    }

    private var tasks: [FocusTask] {
        Array(taskStore.incompleteTasks.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // 1. Top Hero: Status + Countdown + Play/Skip Controls
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        PulseDot(
                            color: modeColor,
                            isActive: timerStore.isRunning,
                            size: 6.5,
                            allowsPulse: settings.decorativeMotionEnabled
                        )
                        Text(stateLabel)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        Text("·")
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                        Text("今日 \(timerStore.completedPomodoros)/\(settings.dailyGoal) · \(timerStore.totalSecondsToday / 60)分")
                            .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                    }

                    Text(time)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .tracking(-0.5)
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    Button {
                        AppHaptics.buttonClick()
                        timerStore.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [modeColor, modeColor.opacity(0.88)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: modeColor.opacity(0.32), radius: 5, y: 2)
                            Circle()
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
                                .frame(width: 38, height: 38)
                            Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: timerStore.isRunning ? 0 : 1)
                        }
                    }
                    .buttonStyle(SoftScaleButtonStyle())
                    .help(timerStore.isRunning ? "暂停" : (timerStore.isSessionInProgress ? "继续" : "开始"))
                    .accessibilityLabel(timerStore.isRunning ? "暂停" : (timerStore.isSessionInProgress ? "继续" : "开始"))

                    Button {
                        AppHaptics.buttonClick()
                        timerStore.skipToNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(AppTheme.elevatedBackground(for: colorScheme))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(SoftScaleButtonStyle())
                    .disabled(!timerStore.canSkipSegment)
                    .help("跳过此段")
                    .accessibilityLabel("跳过此段")
                }
            }

            // 2. Smooth Progress Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.separatorLow(for: colorScheme))
                    if progress > 0.01 {
                        Capsule()
                            .fill(modeColor)
                            .frame(width: max(4, geometry.size.width * progress))
                    }
                }
            }
            .frame(height: 4.5)

            // 3. Interactive Frosted Task Selector Pill
            Menu {
                if tasks.isEmpty {
                    Text("暂无待办任务")
                } else {
                    ForEach(tasks) { task in
                        Button {
                            AppHaptics.buttonClick()
                            timerStore.requestStartWorkFocus(taskId: task.id)
                            onClose()
                        } label: {
                            Label(
                                task.title,
                                systemImage: taskStore.activeTaskId == task.id ? "checkmark" : "circle"
                            )
                        }
                    }
                    Divider()
                }
                Button {
                    AppHaptics.buttonClick()
                    timerStore.requestStartWorkFocus(taskId: nil)
                    onClose()
                } label: {
                    Label("自由专注", systemImage: "sparkles")
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: taskStore.activeTask != nil ? "target" : "sparkles")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(modeColor)
                    Text(taskTitle)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("切换任务")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("切换当前专注任务：\(taskTitle)")

            Rectangle()
                .fill(AppTheme.separatorLow(for: colorScheme))
                .frame(height: 0.5)
                .padding(.vertical, 1)

            // 4. Unified Control Center Action Bar
            HStack(spacing: 6) {
                Button {
                    AppHaptics.buttonClick()
                    onOpenMain()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11, weight: .semibold))
                        Text("打开主窗口")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.accent.opacity(0.28), lineWidth: 0.5)
                    )
                }
                .buttonStyle(SoftScaleButtonStyle())
                .accessibilityLabel("打开主窗口")

                Spacer(minLength: 4)

                panelIconButton(systemName: "pip.enter", help: "悬浮迷你计时窗") {
                    NotificationCenter.default.post(name: AppNavigation.toggleMiniTimer, object: nil)
                    onClose()
                }

                panelIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: "全屏沉浸专注") {
                    NotificationCenter.default.post(name: AppNavigation.toggleFocusMode, object: nil)
                    onClose()
                }

                panelIconButton(systemName: "gearshape", help: "偏好设置") {
                    onOpenSettings()
                }

                panelIconButton(systemName: "power", help: "退出 iFocus") {
                    onQuit()
                }
            }
        }
        .padding(16)
        .frame(width: 300, height: 214, alignment: .top)
        .tint(AppTheme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onReceive(timerStore.clockTick) { _ in clockVersion &+= 1 }
        .accessibilityElement(children: .contain)
    }

    private func panelIconButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            AppHaptics.buttonClick()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    Circle()
                        .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
                )
                .contentShape(Circle())
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}
