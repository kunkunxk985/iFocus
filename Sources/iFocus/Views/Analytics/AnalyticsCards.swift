import SwiftUI
import Charts
import iFocusCore

/// Card-level UI for the analytics dashboard (no derivation — takes a model).
enum AnalyticsCards {
    @ViewBuilder
    static func insightBanner(_ line: String, colorScheme: ColorScheme) -> some View {
        Text(line)
            .font(.subheadline)
            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    static func emptyShell(colorScheme: ColorScheme) -> some View {
        VStack(spacing: 18) {
            AnalyticsProgressRing(
                progress: 0,
                size: 120,
                lineWidth: 11,
                tint: AppTheme.accent.opacity(0.55),
                title: "0",
                subtitle: "今日番茄"
            )
            Text("开始第一个番茄，这里会亮起进度")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                AppNavigation.post(.timer)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("去专注钟")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(AppTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }

    static func achievementHero(
        model: AnalyticsDashboardModel,
        totalMinutesAllTime: Int,
        displayName: String,
        avatarPath: String?,
        avatarColorIndex: Int,
        colorScheme: ColorScheme,
        decorativeMotion: Bool
    ) -> some View {
        let days = dayCount(for: model)
        let pomodoroProgress = pomodoroRingProgress(model: model, dayCount: days)
        let focusProgress = focusRingProgress(model: model, dayCount: days)
        let focusMinutes = model.range == .today ? model.totalMinutesToday : model.rangeTotals.minutes
        let pomodoroCount = model.range == .today ? model.completedPomodoros : model.rangeTotals.pomodoros
        let goalDone = model.range == .today && model.goalRemaining == 0 && model.completedPomodoros > 0

        return GeometryReader { geo in
            let ringSize = min(104, max(84, (geo.size.width - 48) / 3.2))
            let line = max(8, ringSize * 0.095)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    UnifiedAvatarView(
                        path: avatarPath,
                        colorIndex: avatarColorIndex,
                        username: displayName,
                        size: 52
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if goalDone {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .background(Circle().fill(AppTheme.cardBackground(for: colorScheme)).padding(-2))
                                .offset(x: 4, y: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        Text("累计 \(FocusStats.formatTotalMinutes(totalMinutesAllTime)) · 连续 \(model.streakCurrent) 天")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        motivationalLine(model: model, goalDone: goalDone, colorScheme: colorScheme)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 20) {
                    AnalyticsProgressRing(
                        progress: pomodoroProgress,
                        size: ringSize,
                        lineWidth: line,
                        tint: AppTheme.accent,
                        title: "\(pomodoroCount)",
                        subtitle: model.range == .today ? "今日番茄" : "\(model.range.rawValue)番茄",
                        celebrate: goalDone,
                        allowPulse: decorativeMotion
                    )
                    AnalyticsProgressRing(
                        progress: focusProgress,
                        size: ringSize,
                        lineWidth: line,
                        tint: Color(hex: "#14B8A6"),
                        title: FocusStats.formatTotalMinutes(focusMinutes)
                            .replacingOccurrences(of: "分钟", with: "分")
                            .replacingOccurrences(of: "小时", with: "时"),
                        subtitle: model.range == .today ? "今日专注" : "专注时长",
                        celebrate: focusProgress >= 0.999,
                        allowPulse: decorativeMotion && focusProgress >= 0.85
                    )
                }
                .frame(maxWidth: .infinity)

                if !model.recentSessions.isEmpty {
                    recentFocusStrip(model: model, colorScheme: colorScheme)
                }

                if model.range == .today {
                    focusCallToAction(goalDone: goalDone, colorScheme: colorScheme)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
            .overlay {
                if goalDone {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                        .strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 1.2)
                }
            }
        }
        .frame(height: goalDone || !model.recentSessions.isEmpty ? 292 : 252)
    }

    @ViewBuilder
    private static func motivationalLine(
        model: AnalyticsDashboardModel,
        goalDone: Bool,
        colorScheme: ColorScheme
    ) -> some View {
        if goalDone {
            Text("今日目标已完成")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.accent)
        } else if model.range == .today, model.goalRemaining > 0 {
            Text("还差 \(model.goalRemaining) 个番茄")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        } else if let line = model.headlineInsight {
            Text(line)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(2)
        }
    }

    private static func recentFocusStrip(
        model: AnalyticsDashboardModel,
        colorScheme: ColorScheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近完成")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
            HStack(spacing: 8) {
                ForEach(model.recentSessions.prefix(3)) { session in
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.accent.opacity(0.85))
                        Text(session.taskTitle)
                            .lineLimit(1)
                        Text("\(session.durationMinutes)分")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.65))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8)
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private static func focusCallToAction(goalDone: Bool, colorScheme: ColorScheme) -> some View {
        Button {
            AppNavigation.post(.timer)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(goalDone ? "继续专注" : "去专注钟")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(goalDone ? AppTheme.accent : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        goalDone
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.18)
                        : AppTheme.accent
                    )
            }
            .overlay {
                if goalDone {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private static func dayCount(for model: AnalyticsDashboardModel) -> Int {
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
    }

    private static func pomodoroRingProgress(model: AnalyticsDashboardModel, dayCount days: Int) -> Double {
        if model.range == .today {
            return model.goalProgress
        }
        let target = max(1, model.dailyGoal * days)
        return min(1, Double(model.rangeTotals.pomodoros) / Double(target))
    }

    private static func focusRingProgress(model: AnalyticsDashboardModel, dayCount days: Int) -> Double {
        let minutes = model.range == .today ? model.totalMinutesToday : model.rangeTotals.minutes
        let target = max(25, model.dailyGoal * 25 * days)
        return min(1, Double(minutes) / Double(target))
    }

    static func summaryGrid(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        HStack(spacing: 10) {
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
                label: model.streakCurrent > 0 ? "连续天数" : "连续天数",
                tint: AppTheme.secondaryText(for: colorScheme)
            )
        }
    }

    static func goalCard(model: AnalyticsDashboardModel, colorScheme: ColorScheme) -> some View {
        AnalyticsCard(title: "今日目标", icon: "scope") {
            GeometryReader { g in
                let ring = min(136, min(g.size.width * 0.56, g.size.height * 0.54))
                let clampedProg = CGFloat(min(max(model.goalProgress, 0.0), 1.0))
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    ZStack {
                        // Background track with recessed bevel
                        Circle()
                            .stroke(
                                colorScheme == .light
                                ? AppTheme.separatorLow(for: colorScheme).opacity(0.85)
                                : Color.white.opacity(0.06),
                                lineWidth: 13
                            )

                        // Active progress arc with soft ambient glow
                        Circle()
                            .trim(from: 0, to: clampedProg)
                            .stroke(
                                AppTheme.accent,
                                style: StrokeStyle(lineWidth: 13, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: AppTheme.accent.opacity(colorScheme == .light ? 0.25 : 0.35), radius: 4, x: 0, y: 1)
                            .animation(AppTheme.springInteractive, value: model.goalProgress)

                        VStack(spacing: 3) {
                            Text("\(Int(model.goalProgress * 100))%")
                                .font(.system(size: max(25, ring * 0.24), weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                            Text(model.goalRemaining == 0 && model.completedPomodoros > 0 ? "已达成" : "达成率")
                                .font(.system(size: 11, weight: .medium))
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
                            label: model.goalRemaining == 0 ? "目标" : "还差",
                            valueText: model.goalRemaining == 0
                                ? "\(model.dailyGoal) 个"
                                : "\(model.goalRemaining) 个",
                            color: Color(hex: "#9CA3AF")
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
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(item.color)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.minutes) 分")
                                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.separatorLow(for: colorScheme))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [item.color, item.color.opacity(0.85)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(6, g.size.width * CGFloat(item.minutes) / CGFloat(total)))
                                        .shadow(color: item.color.opacity(0.28), radius: 2, x: 0, y: 0)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(boundPct)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.accent)
                    Text("绑定任务占比")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
                ProgressRow(
                    label: "自由专注",
                    valueText: "\(pct)%",
                    color: Color(hex: "#6B7280")
                )
                Text(boundPct >= 50
                     ? "不错，多数时间都挂在任务上。"
                     : "多选任务再开始，分类与排行会更准。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.5))
                    )
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
                            Divider().opacity(0.4)
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
        let tint = cat?.color ?? AppTheme.accent
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(colorScheme == .light ? 0.12 : 0.20))
                    .frame(width: 28, height: 28)
                Image(systemName: cat?.icon ?? "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(sessionDateFormatter.string(from: session.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    if let cat {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(cat.color)
                    } else if session.taskId == nil {
                        Text("· 自由专注")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
            }
            Spacer()
            Text("\(session.durationMinutes) 分")
                .font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.16))
                )
        }
        .padding(.vertical, 7)
    }
}

let sessionDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    f.locale = Locale(identifier: "zh_CN")
    return f
}()
