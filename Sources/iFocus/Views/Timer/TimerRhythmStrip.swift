import SwiftUI
import iFocusCore

/// Compact “today’s rhythm” strip under the goal/meta area — industry-style session context.
struct TimerRhythmStrip: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var every: Int { max(2, settings.longBreakEvery) }
    private var doneInCycle: Int {
        let mod = timerStore.completedPomodoros % every
        return mod == 0 && timerStore.completedPomodoros > 0 ? every : mod
    }
    private var untilLong: Int { timerStore.workSessionsUntilLongBreak }
    private var focusMinutesToday: Int { timerStore.totalSecondsToday / 60 }

    var body: some View {
        HStack(spacing: 14) {
            // Cycle dots toward long break
            HStack(spacing: 5) {
                ForEach(0..<every, id: \.self) { index in
                    Circle()
                        .fill(index < doneInCycle
                              ? modeColor
                              : AppTheme.separator(for: colorScheme))
                        .frame(width: 7, height: 7)
                }
            }
            .help("本轮已完成 \(doneInCycle)/\(every) · 再 \(untilLong) 个进入长休息")

            VStack(alignment: .leading, spacing: 2) {
                Text(cycleCaption)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(statsCaption)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: min(layout.goalCardMaxWidth, layout.width - layout.horizontalPadding * 2))
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.55 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cycleCaption)，\(statsCaption)")
    }

    private var cycleCaption: String {
        if timerStore.mode == .longBreak {
            return "长休息中"
        }
        if untilLong == every, timerStore.completedPomodoros == 0 {
            return "本轮 \(every) 个番茄 → 长休"
        }
        if untilLong == 1 {
            return "再 1 个进入长休"
        }
        return "再 \(untilLong) 个进入长休"
    }

    private var statsCaption: String {
        let goal = settings.dailyGoal
        let done = timerStore.completedPomodoros
        let time = FocusStats.formatTotalMinutes(focusMinutesToday)
            .replacingOccurrences(of: "分钟", with: "分")
            .replacingOccurrences(of: "小时", with: "时")
        if goal > 0 {
            return "今日 \(done)/\(goal) 番茄 · \(time)"
        }
        return "今日 \(done) 番茄 · \(time)"
    }
}
