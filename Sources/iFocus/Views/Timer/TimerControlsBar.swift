import SwiftUI

/// Mode chips + play/skip/reset + session keyboard hint (below the ring).
/// Pure move from TimerView — no layout token changes.
struct TimerModeSwitcher: View {
    let layout: WindowLayoutMetrics
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
        case .work: return "\(settings.workMinutes)′"
        case .shortBreak: return "\(settings.shortBreakMinutes)′"
        case .longBreak: return "\(settings.longBreakMinutes)′"
        }
    }
}

struct TimerControlsBar: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    let playInvite: Bool
    @Binding var showResetConfirm: Bool
    var onPlayToggle: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let main = layout.controlMainSize
        let side = layout.controlSideSize
        let showLabels = layout.showControlLabels

        return HStack(spacing: layout.controlSpacing) {
            controlCircle(
                systemName: "forward.end.fill",
                title: "跳过",
                size: side,
                showTitle: showLabels,
                tint: AppTheme.secondaryText(for: colorScheme).opacity(timerStore.canSkipSegment ? 1 : 0.35),
                fill: AppTheme.cardBackground(for: colorScheme).opacity(0.75)
            ) {
                timerStore.skipToNext()
            }
            .disabled(!timerStore.canSkipSegment)
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .help(timerStore.canSkipSegment ? "立即跳过当前段 (⌘→)" : "严格模式：不可跳过")

            Button(action: onPlayToggle) {
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
}

struct TimerSessionHint: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if timerStore.mode == .work {
                if timerStore.isRunning {
                    KeyCap(label: "空格")
                    Text("暂停")
                    if timerStore.canSkipSegment {
                        Text("·").opacity(0.4)
                        KeyCap(label: "⌘→")
                        Text("跳过")
                    } else {
                        Text("·").opacity(0.4)
                        Text("严格模式")
                    }
                } else if let title = taskStore.activeTask?.title, !title.isEmpty {
                    KeyCap(label: "空格")
                    Text("开始 · \(title)")
                        .lineLimit(1)
                } else {
                    KeyCap(label: "空格")
                    Text("自由专注")
                    Text("·").opacity(0.4)
                    Text("上方可选任务")
                }
            } else {
                KeyCap(label: "空格")
                Text(timerStore.isRunning ? "暂停休息" : "开始休息")
                if timerStore.canSkipSegment {
                    Text("·").opacity(0.4)
                    KeyCap(label: "⌘→")
                    Text("跳过")
                }
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
