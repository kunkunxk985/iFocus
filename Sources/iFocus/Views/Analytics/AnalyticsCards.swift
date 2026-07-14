import SwiftUI
import Charts
import iFocusCore

/// Card-level UI for the analytics dashboard (no derivation — takes a model).
enum AnalyticsCards {
    @ViewBuilder
    static func insightBanner(_ line: String, colorScheme: ColorScheme) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                .padding(.top, 2)
            Text(line)
                .font(.subheadline)
                .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusControl, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
        )
    }

    static func emptyShell(colorScheme: ColorScheme) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
                .frame(width: 48, height: 48)
                .background(Circle().fill(AppTheme.elevatedBackground(for: colorScheme)))

            Text("完成一次专注后，这里会变清晰")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))

            Text("现在只需开始第一个番茄。")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                AppNavigation.post(.timer)
            } label: {
                Text("去专注钟")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }

    static func summaryGrid(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        HStack(spacing: 12) {
            StatCard(
                systemImage: "timer",
                value: "\(model.completedPomodoros)/\(model.dailyGoal)",
                label: model.goalRemaining > 0
                    ? "今日番茄 · 还差 \(model.goalRemaining)"
                    : "今日番茄",
                tint: AppTheme.accent,
                emphasizeValue: true
            )
            StatCard(
                systemImage: "clock",
                value: FocusStats.formatTotalMinutes(model.totalMinutesToday)
                    .replacingOccurrences(of: "分钟", with: "分")
                    .replacingOccurrences(of: "小时", with: "时"),
                label: "今日专注",
                tint: AppTheme.accent.opacity(0.75)
            )
            StatCard(
                systemImage: "flame",
                value: "\(model.streakCurrent)",
                label: model.streakCurrent > 0 ? "连续天数" : "连续 · 待开启",
                tint: AppTheme.secondaryText(for: colorScheme)
            )
        }
    }

    static func goalCard(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        AnalyticsCard(title: "今日目标", icon: "scope") {
            GeometryReader { g in
                let ring = min(132, min(g.size.width * 0.55, g.size.height * 0.52))
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.14), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: model.goalProgress)
                            .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: model.goalProgress)
                        VStack(spacing: 2) {
                            Text("\(Int(model.goalProgress * 100))%")
                                .font(.system(size: max(24, ring * 0.22), weight: .bold, design: .rounded))
                            Text(model.goalRemaining == 0 && model.completedPomodoros > 0 ? "已完成" : "完成")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        }
                    }
                    .frame(width: ring, height: ring)

                    VStack(spacing: 8) {
                        ProgressRow(
                            label: "已完成",
                            valueText: "\(model.completedPomodoros) 个",
                            color: AppTheme.accent
                        )
                        ProgressRow(
                            label: model.goalRemaining == 0 ? "目标" : "还剩",
                            valueText: model.goalRemaining == 0
                                ? "\(model.dailyGoal) 个"
                                : "\(model.goalRemaining) 个",
                            color: .gray
                        )
                        ProgressRow(
                            label: "昨日",
                            valueText: "\(model.yesterdayMinutes) 分",
                            color: Color(hex: "#8B5CF6")
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    static func weeklyCard(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        let dayCount: Int = {
            switch model.range {
            case .today: return 1
            case .days7: return 7
            case .days30: return 30
            case .month:
                let days = model.calendar.dateComponents(
                    [.day],
                    from: model.rangeBounds.from,
                    to: model.rangeBounds.through
                ).day ?? 0
                return max(1, days + 1)
            }
        }()
        return AnalyticsCard(title: "\(model.range.rawValue)趋势", icon: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    weekMeta("番茄", "\(model.rangeTotals.pomodoros)", colorScheme)
                    weekMeta(
                        "专注",
                        FocusStats.formatTotalMinutes(model.rangeTotals.minutes),
                        colorScheme
                    )
                    Spacer()
                }
                if model.range == .today {
                    TodayHourChart(hourMinutes: model.todayHourMinutes)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WeeklyFocusChart(sessions: model.sessionsInRange, dayCount: dayCount)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private static func weekMeta(_ label: String, _ value: String, _ colorScheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
    }

    static func timelineCard(model: AnalyticsDashboardModel) -> some View {
        let blocks = model.todayTimelineBlocks
        return AnalyticsCard(title: "今日时间线", icon: "timeline.selection") {
            if blocks.isEmpty {
                EmptyStateView(systemImage: "calendar", title: "完成专注后会显示时间块")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TodayTimelineView(blocks: blocks)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    static func hourCard(model: AnalyticsDashboardModel) -> some View {
        let hours = model.todayHourMinutes
        let peak = FocusStats.peakHourLabel(fromHourMinutes: hours)
        return AnalyticsCard(
            title: peak.map { "今日时段分布 · 高峰 \($0)" } ?? "今日时段分布",
            icon: "clock.arrow.circlepath"
        ) {
            if hours.allSatisfy({ $0 == 0 }) {
                EmptyStateView(systemImage: "clock", title: "今天还没有按时段记录")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TodayHourChart(hourMinutes: hours)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    static func categoryCard(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        AnalyticsCard(title: "\(model.range.rawValue)分类 Top", icon: "square.grid.2x2.fill") {
            if model.categoryTop.isEmpty {
                EmptyStateView(systemImage: "tray", title: "暂无分类数据")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let total = max(1, model.categoryTop.reduce(0) { $0 + $1.minutes })
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(model.categoryTop.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(item.name, systemImage: item.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(item.color)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.minutes) 分")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AppTheme.separator(for: colorScheme))
                                    Capsule()
                                        .fill(item.color.opacity(0.85))
                                        .frame(width: max(4, g.size.width * CGFloat(item.minutes) / CGFloat(total)))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    static func freeFocusCard(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        let pct = Int((model.freeShare * 100).rounded())
        let boundPct = max(0, 100 - pct)
        return AnalyticsCard(title: "任务绑定", icon: "link") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(boundPct)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                Text("绑定任务的专注占比")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                ProgressRow(
                    label: "自由专注",
                    valueText: "\(pct)%",
                    color: Color(hex: "#6B7280")
                )
                Text(boundPct >= 50
                     ? "不错，多数时间都挂在任务上。"
                     : "多选任务再开始，分类与排行会更准。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    static func recentBody(
        model: AnalyticsDashboardModel,
        tasks: [FocusTask],
        colorScheme: ColorScheme
    ) -> some View {
        Group {
            if model.recentSessions.isEmpty {
                EmptyStateView(systemImage: "tray", title: "暂无专注记录")
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.recentSessions) { session in
                        sessionRow(session, model: model, tasks: tasks, colorScheme: colorScheme)
                        if session.id != model.recentSessions.last?.id {
                            Divider().opacity(0.55)
                        }
                    }
                }
            }
        }
    }

    private static func sessionRow(
        _ session: FocusSession,
        model: AnalyticsDashboardModel,
        tasks: [FocusTask],
        colorScheme: ColorScheme
    ) -> some View {
        let cat = model.resolvedCategory(for: session, tasks: tasks)
        return HStack(spacing: 12) {
            Image(systemName: cat?.icon ?? "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cat?.color ?? AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill((cat?.color ?? AppTheme.accent).opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(sessionDateFormatter.string(from: session.timestamp))
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    if let cat {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        Text(cat.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(cat.color)
                    } else if session.taskId == nil {
                        Text("· 自由专注")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
            }
            Spacer()
            Text("\(session.durationMinutes) 分")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(AppTheme.accent)
        }
        .padding(.vertical, 8)
    }
}

let sessionDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    f.locale = Locale(identifier: "zh_CN")
    return f
}()
