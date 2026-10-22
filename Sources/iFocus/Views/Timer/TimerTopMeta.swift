import SwiftUI

/// One quiet line under the ring, plus pause and celebration follow-ups.
struct TimerTopMeta: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    let goalProgress: Double
    @Binding var celebratePulse: Bool
    var onDecorativeMotionChange: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var focusMinutesToday: Int {
        timerStore.totalSecondsToday / 60
    }

    private var todaySummary: String {
        let minutes = focusMinutesToday
        guard settings.dailyGoal > 0 else { return "已专注 \(minutes) 分" }
        if goalProgress >= 1 {
            return "今日目标已达成 · 已专注 \(minutes) 分"
        }
        return "今天 \(timerStore.completedPomodoros)/\(settings.dailyGoal) · 已专注 \(minutes) 分"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(todaySummary)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundColor(
                    goalProgress >= 1 && settings.dailyGoal > 0
                    ? AppTheme.success
                    : AppTheme.secondaryText(for: colorScheme)
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
