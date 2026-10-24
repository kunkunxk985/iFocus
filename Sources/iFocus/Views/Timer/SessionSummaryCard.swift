import SwiftUI

/// One line after a work session. It sits over the window instead of covering the ring.
struct SessionSummaryCard: View {
    let summary: SessionSummary
    @EnvironmentObject private var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    private var nextSegmentRunning: Bool {
        timerStore.isRunning && timerStore.mode != .work
    }

    private var canStartNextSegment: Bool {
        !timerStore.isRunning && !timerStore.isSessionInProgress && timerStore.mode != .work
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(summary.minutes) 分钟")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(AppTheme.primaryText(for: colorScheme))

            Text(summary.taskTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)

            Spacer(minLength: 8)

            if nextSegmentRunning {
                Text("\(timerStore.mode.rawValue)已开始")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            } else if canStartNextSegment {
                Button("开始\(timerStore.mode.rawValue)") {
                    timerStore.startPreparedSegment()
                    timerStore.dismissSessionSummary()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(timerStore.mode.accent)
            }

            Button {
                timerStore.dismissSessionSummary()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("关闭")
            .accessibilityLabel("关闭专注总结")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 420)
        .background(
            Capsule()
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
    }
}
