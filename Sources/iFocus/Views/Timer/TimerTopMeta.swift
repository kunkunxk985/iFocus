import SwiftUI

/// Status + goal — one quiet card (no second “rhythm” strip).
struct TimerTopMeta: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    let goalProgress: Double
    @Binding var celebratePulse: Bool
    var onDecorativeMotionChange: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var untilLong: Int { timerStore.workSessionsUntilLongBreak }

    private var focusMinutesToday: Int {
        timerStore.totalSecondsToday / 60
    }

    private var longBreakContext: String {
        if timerStore.mode == .longBreak { return "长休息" }
        if untilLong == 1 { return "再 1 个长休" }
        return "再 \(untilLong) 个长休"
    }

    var body: some View {
        VStack(spacing: TimerLayoutMath.lerp(10, 14, layout.eased)) {
            // Goal — progress and today's focus read as one quiet unit.
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goalProgress >= 1 ? "今日目标已达成" : "今日目标")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(
                            goalProgress >= 1
                            ? AppTheme.success
                            : AppTheme.secondaryText(for: colorScheme)
                        )
                    Spacer()
                    Text("\(timerStore.completedPomodoros) / \(settings.dailyGoal)")
                        .font(TypeScale.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.82))
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.separatorLow(for: colorScheme))
                        if goalProgress > 0 {
                            Capsule()
                                .fill(goalProgress >= 1 ? AppTheme.success : modeColor)
                                .frame(width: max(6, g.size.width * goalProgress))
                                .animation(.easeInOut(duration: 0.35), value: goalProgress)
                        }
                    }
                }
                .frame(height: 4)

                HStack(alignment: .firstTextBaseline) {
                    Text("已专注 \(focusMinutesToday) 分")
                    Spacer()
                    Text(longBreakContext)
                }
                .font(TypeScale.meta)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, layout.goalCardPaddingV)
            .frame(maxWidth: layout.goalCardMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.65 : 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                            .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                    )
            )

            if timerStore.isPauseIdleTooLong {
                Button {
                    timerStore.start()
                } label: {
                    Text("已暂停 \(timerStore.pauseIdleMinutes) 分钟 · 继续")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.paused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else if let celebration = timerStore.celebrationMessage {
                HStack(spacing: 10) {
                    Text(celebration)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(2)
                    if !timerStore.isRunning, !timerStore.isSessionInProgress {
                        Button {
                            timerStore.startPreparedSegment()
                        } label: {
                            Text("开始\(timerStore.mode.rawValue)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(modeColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: layout.goalCardMaxWidth)
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        if timerStore.celebrationMessage == celebration {
                            withAnimation { timerStore.celebrationMessage = nil }
                        }
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: timerStore.celebrationMessage)
        .animation(.easeOut(duration: 0.2), value: timerStore.isPauseIdleTooLong)
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

struct TimerImmersiveStatusPill: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let title = taskStore.activeTask?.title,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.8))
                .lineLimit(1)
        }
    }
}
