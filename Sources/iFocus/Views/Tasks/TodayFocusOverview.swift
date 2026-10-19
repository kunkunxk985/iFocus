import SwiftUI

/// Compact daily goal summary with one clear route to the focus timer.
struct TodayFocusOverview: View {
    @EnvironmentObject private var timerStore: TimerStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme

    private var dailyGoal: Int {
        max(1, settings.dailyGoal)
    }

    private var progress: Double {
        min(1, Double(max(0, timerStore.completedPomodoros)) / Double(dailyGoal))
    }

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text("专注目标")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(timerStore.completedPomodoros)")
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                    Text("/ \(dailyGoal) 个番茄")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                }

                ProgressView(value: progress)
                    .tint(progress >= 1 ? Color(hex: "#10B981") : AppTheme.accent)
                    .frame(maxWidth: 300)
                    .accessibilityLabel("今日番茄目标")
                    .accessibilityValue("\(timerStore.completedPomodoros) / \(dailyGoal)")
            }

            Spacer(minLength: 8)

            Button {
                viewState.selectedScreen = .timer
            } label: {
                Label("专注钟", systemImage: "timer")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(AppTheme.accent)
            .help("打开专注钟")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(
            AppTheme.squircle(radius: 16)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            AppTheme.squircle(radius: 16)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8)
        )
        .shadow(color: AppTheme.softShadow(for: colorScheme).opacity(0.55), radius: 8, x: 0, y: 3)
    }
}
