import SwiftUI

/// Transient post-session card. It stays out of the timer controls and can be
/// dismissed; the next break is already running when auto-start is enabled.
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.success.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("专注完成")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text(summary.taskTitle)
                        .font(TypeScale.meta)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    timerStore.dismissSessionSummary()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.8)))
                }
                .buttonStyle(.plain)
                .help("关闭总结")
                .accessibilityLabel("关闭专注总结")
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(summary.minutes)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text("分钟")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))

                if let category = summary.category {
                    Text(category.name)
                        .font(TypeScale.tag)
                        .foregroundColor(category.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(category.color.opacity(0.12)))
                        .padding(.leading, 2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if nextSegmentRunning {
                    Label("\(timerStore.mode.rawValue)已开始", systemImage: "checkmark.circle.fill")
                        .font(TypeScale.meta)
                        .foregroundColor(timerStore.mode.accent)
                } else if canStartNextSegment {
                    Button {
                        timerStore.startPreparedSegment()
                        timerStore.dismissSessionSummary()
                    } label: {
                        Label("开始\(timerStore.mode.rawValue)", systemImage: "play.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(timerStore.mode.accent))
                    }
                    .buttonStyle(SoftScaleButtonStyle())
                } else {
                    Text("本轮专注已记入历史")
                        .font(TypeScale.meta)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .background(
            AppTheme.squircle(radius: AppTheme.cornerRadiusCard)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            AppTheme.squircle(radius: AppTheme.cornerRadiusCard)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: AppTheme.softShadow(for: colorScheme).opacity(0.9), radius: 16, y: 6)
    }
}
