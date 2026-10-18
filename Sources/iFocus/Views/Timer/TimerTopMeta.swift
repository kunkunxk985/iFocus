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

    private var goalSubtitle: String {
        let base = "\(timerStore.completedPomodoros)/\(settings.dailyGoal)"
        if timerStore.mode == .longBreak {
            return "\(base) · 长休息"
        }
        if untilLong == 1 {
            return "\(base) · 再 1 个长休"
        }
        return "\(base) · 再 \(untilLong) 个长休"
    }

    var body: some View {
        VStack(spacing: TimerLayoutMath.lerp(10, 14, layout.eased)) {
            if timerStore.mode == .work {
                let mins = timerStore.totalSecondsToday / 60
                Text("今日 \(mins) 分")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }

            // Goal — progress only, secondary line carries long-break context
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goalProgress >= 1 ? "今日目标已达成" : "今日目标")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(
                            goalProgress >= 1
                            ? modeColor
                            : AppTheme.secondaryText(for: colorScheme)
                        )
                    Spacer()
                    Text(goalSubtitle)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
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
                .frame(height: 4)
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
                        .foregroundColor(Color(hex: "#D97706"))
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
