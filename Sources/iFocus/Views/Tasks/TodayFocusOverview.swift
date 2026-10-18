import SwiftUI

/// Editorial daily-focus hero for the Today list: one useful visual anchor, not another KPI grid.
struct TodayFocusOverview: View {
    @EnvironmentObject private var timerStore: TimerStore
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme

    private var todayTasks: [FocusTask] {
        taskStore.tasks(for: .todayTask)
    }

    private var overdueCount: Int {
        todayTasks.filter(\.isOverdue).count
    }

    private var dailyGoal: Int {
        max(1, settings.dailyGoal)
    }

    private var progress: Double {
        min(1, Double(max(0, timerStore.completedPomodoros)) / Double(dailyGoal))
    }

    var body: some View {
        Button {
            viewState.selectedScreen = .timer
        } label: {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                        Text("DAILY FOCUS")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(1.25)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.9))
                        Circle()
                            .fill(AppTheme.separator(for: colorScheme))
                            .frame(width: 3, height: 3)
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.88))
                    }

                    Text("把注意力，留给眼前最重要的事。")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .tracking(-0.35)
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 14) {
                        Label("\(todayTasks.count) 项待办", systemImage: "checklist")
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        if overdueCount > 0 {
                            Label("\(overdueCount) 项逾期", systemImage: "clock.badge.exclamationmark")
                                .foregroundColor(Color(hex: "#D97706"))
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            Text("进入专注钟")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                }

                Spacer(minLength: 12)

                goalDial
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 19)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(heroSurface)
            .contentShape(AppTheme.squircle(radius: AppTheme.radiusXL))
        }
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.99))
        .help("打开专注钟")
        .accessibilityLabel(
            "今日专注，已完成 \(timerStore.completedPomodoros) 个番茄，目标 \(dailyGoal) 个；\(todayTasks.count) 项待办，\(overdueCount) 项逾期。打开专注钟。"
        )
        .accessibilityHint("前往专注钟页面")
    }

    private var goalDial: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent.opacity(0.48), AppTheme.accent, AppTheme.accent.opacity(0.82)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppTheme.accent.opacity(progress > 0 ? 0.24 : 0), radius: 5)
                VStack(spacing: 0) {
                    Text("\(timerStore.completedPomodoros)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text("/ \(dailyGoal)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("番茄目标")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.86))
                Text(progress >= 1 ? "今日已达成" : "还差 \(max(0, dailyGoal - timerStore.completedPomodoros)) 个")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(progress >= 1 ? Color(hex: "#10B981") : AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 14)
        .padding(.vertical, 8)
        .padding(.trailing, 14)
        .background(
            Capsule().fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.66 : 0.50))
        )
        .overlay(
            Capsule().strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("番茄目标：\(timerStore.completedPomodoros) / \(dailyGoal)，\(progress >= 1 ? "今日已达成" : "还差 \(max(0, dailyGoal - timerStore.completedPomodoros)) 个")")
    }

    private var heroSurface: some View {
        AppTheme.squircle(radius: AppTheme.radiusXL)
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white, Color(hex: "#F8F7F3"), AppTheme.accent.opacity(0.055)]
                        : [Color(hex: "#242429"), Color(hex: "#1D1D21"), AppTheme.accent.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.16), .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 145
                        )
                    )
                    .frame(width: 290, height: 290)
                    .offset(x: 74, y: 56)
                    .allowsHitTesting(false)
            }
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusXL)
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusXL)
                    .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
            )
            .clipShape(AppTheme.squircle(radius: AppTheme.radiusXL))
            .multiLayerShadow(elevation: .card, colorScheme: colorScheme)
    }
}
