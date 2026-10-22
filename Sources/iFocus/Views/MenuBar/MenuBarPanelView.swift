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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(modeColor)
                            .frame(width: 6, height: 6)
                        Text(stateLabel)
                            .font(TypeScale.eyebrow)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }

                    Text(time)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .contentTransition(.numericText())

                    Text(taskTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Button {
                        timerStore.toggle()
                    } label: {
                        Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(modeColor))
                    }
                    .buttonStyle(SoftScaleButtonStyle())
                    .help(timerStore.isRunning ? "暂停" : (timerStore.isSessionInProgress ? "继续" : "开始"))
                    .accessibilityLabel(timerStore.isRunning ? "暂停" : (timerStore.isSessionInProgress ? "继续" : "开始"))

                    Button {
                        timerStore.skipToNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(AppTheme.elevatedBackground(for: colorScheme)))
                    }
                    .buttonStyle(SoftScaleButtonStyle())
                    .disabled(!timerStore.canSkipSegment)
                    .help("跳过此段")
                    .accessibilityLabel("跳过此段")
                }
            }

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
            .frame(height: 4)

            HStack(spacing: 6) {
                Text("今日 \(timerStore.completedPomodoros) / \(settings.dailyGoal) 番茄")
                Spacer()
                Text("\(timerStore.totalSecondsToday / 60) 分")
            }
            .font(TypeScale.meta)
            .foregroundColor(AppTheme.secondaryText(for: colorScheme))

            Divider()
                .opacity(0.7)

            HStack(spacing: 8) {
                Button {
                    onOpenMain()
                } label: {
                    Label("专注钟", systemImage: "timer")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AppTheme.accent)

                Menu {
                    if tasks.isEmpty {
                        Text("暂无待办任务")
                    } else {
                        ForEach(tasks) { task in
                            Button {
                                timerStore.requestStartWorkFocus(taskId: task.id)
                                onClose()
                            } label: {
                                Label(
                                    "\(task.title)  ·  \(task.completedPomodoros)/\(task.estimatedPomodoros)",
                                    systemImage: task.category.icon
                                )
                            }
                        }
                        Divider()
                        Button {
                            timerStore.requestStartWorkFocus(taskId: nil)
                            onClose()
                        } label: {
                            Label("自由专注", systemImage: "sparkles")
                        }
                    }
                } label: {
                    Label("任务", systemImage: "list.bullet")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer(minLength: 4)

                panelIcon("pip", help: "迷你计时窗") {
                    NotificationCenter.default.post(name: AppNavigation.toggleMiniTimer, object: nil)
                    onClose()
                }
                panelIcon("arrow.up.left.and.arrow.down.right", help: "全屏专注模式") {
                    NotificationCenter.default.post(name: AppNavigation.toggleFocusMode, object: nil)
                    onClose()
                }
                panelIcon("gearshape", help: "设置") {
                    onOpenSettings()
                }
            }

            HStack {
                Button("退出 iFocus") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))

                Spacer()

                Text("右键状态图标可打开完整菜单")
                    .font(.system(size: 9.5))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
            }
        }
        .padding(16)
        .frame(width: 300, height: 244, alignment: .top)
        .tint(AppTheme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onReceive(timerStore.clockTick) { _ in clockVersion &+= 1 }
        .accessibilityElement(children: .contain)
    }

    private func panelIcon(
        _ systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.75))
                )
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}
