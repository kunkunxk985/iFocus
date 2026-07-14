import SwiftUI

/// Status pill + goal card + pause/celebration chips (above the ring).
/// Pure move from TimerView — layout tokens and visuals unchanged.
struct TimerTopMeta: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    let statusLabel: String
    let goalProgress: Double
    @Binding var celebratePulse: Bool
    var onDecorativeMotionChange: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var longBreakProgress: (done: Int, total: Int) {
        let until = timerStore.workSessionsUntilLongBreak
        return (4 - until, 4)
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

    var body: some View {
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

            // Goal card
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
                // Industry UX: after a segment ends (auto-start off), offer one-tap next start.
                VStack(spacing: 8) {
                    Text(celebration)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(modeColor)
                        .multilineTextAlignment(.center)
                    if !timerStore.isRunning, !timerStore.isSessionInProgress {
                        Button {
                            timerStore.startPreparedSegment()
                        } label: {
                            Text("开始\(timerStore.mode.rawValue)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(modeColor))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(modeColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(modeColor.opacity(0.25), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
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
            onDecorativeMotionChange()
        }
    }
}

/// Compact status when immersive mode hides the full meta stack.
struct TimerImmersiveStatusPill: View {
    let modeColor: Color
    let statusLabel: String
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
}
