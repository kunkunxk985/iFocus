import SwiftUI
import Charts
import AppKit
import iFocusCore

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case today = "今日"
    case days7 = "近7天"
    case days30 = "近30天"
    case month = "本月"
    
    var id: String { rawValue }
}

/// Stats dashboard — selectable time range + A-tier insights.
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    /// Local only — do not put clock ticks on ContentView.
    @State private var clockVersion: UInt = 0
    @State private var range: AnalyticsRange = .days7
    @AppStorage("analyticsShowInsights") private var showInsights = true
    @AppStorage("analyticsShowRecent") private var showRecent = true

    // MARK: - Derived metrics

    private var sessionPairs: [(timestamp: Date, minutes: Int)] {
        taskStore.focusSessions.map { ($0.timestamp, $0.durationMinutes) }
    }
    
    private var sessionsInRange: [FocusSession] {
        let bounds = rangeBounds
        return taskStore.focusSessions.filter { session in
            let day = calendar.startOfDay(for: session.timestamp)
            return day >= bounds.from && day <= bounds.through
        }
    }
    
    private var pairsInRange: [(timestamp: Date, minutes: Int)] {
        sessionsInRange.map { ($0.timestamp, $0.durationMinutes) }
    }

    private var calendar: Calendar { .current }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var yesterdayStart: Date {
        calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart.addingTimeInterval(-86_400)
    }

    private var weekStart: Date {
        calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
    }
    
    private var rangeBounds: (from: Date, through: Date) {
        switch range {
        case .today:
            return (todayStart, todayStart)
        case .days7:
            return (weekStart, todayStart)
        case .days30:
            let from = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
            return (from, todayStart)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: todayStart)
            let start = calendar.date(from: comps) ?? todayStart
            return (start, todayStart)
        }
    }

    private var goalProgress: Double {
        guard settings.dailyGoal > 0 else { return 0 }
        return min(Double(timerStore.completedPomodoros) / Double(settings.dailyGoal), 1.0)
    }

    /// Live minutes today (history + running work segment).
    private var totalMinutesToday: Int {
        _ = clockVersion
        return timerStore.totalSecondsToday / 60
    }

    private var yesterdayTotals: FocusStats.DayFocusTotals {
        FocusStats.dayTotals(sessions: sessionPairs, on: yesterdayStart, calendar: calendar)
    }

    private var rangeTotals: FocusStats.DayFocusTotals {
        FocusStats.rangeTotals(
            sessions: sessionPairs,
            from: rangeBounds.from,
            through: rangeBounds.through,
            calendar: calendar
        )
    }
    
    private var weekTotals: FocusStats.DayFocusTotals { rangeTotals }

    private var streakCurrent: Int {
        FocusStats.streaks(
            sessionTimestamps: taskStore.focusSessions.map(\.timestamp),
            relativeTo: Date(),
            calendar: calendar
        ).current
    }

    private var freeShare: Double {
        let total = sessionsInRange.count
        let free = sessionsInRange.filter { $0.taskId == nil }.count
        return FocusStats.freeFocusShare(freeCount: free, totalCount: total)
    }

    private var dayOverDayLabel: String {
        FocusStats.dayOverDayMinutesLabel(
            todayMinutes: totalMinutesToday,
            yesterdayMinutes: yesterdayTotals.minutes
        )
    }

    private var goalRemaining: Int {
        max(0, settings.dailyGoal - timerStore.completedPomodoros)
    }

    private var insights: [String] {
        FocusStats.smartInsights(
            todayPomodoros: timerStore.completedPomodoros,
            todayMinutes: totalMinutesToday,
            yesterdayMinutes: yesterdayTotals.minutes,
            dailyGoal: settings.dailyGoal,
            currentStreak: streakCurrent,
            freeFocusShare: freeShare,
            hasAnyHistory: !taskStore.focusSessions.isEmpty
        )
    }

    private var categoryTop: [(name: String, icon: String, color: Color, minutes: Int)] {
        var minutesStats = [TaskCategory: Int]()
        for session in sessionsInRange {
            let cat: TaskCategory
            if let c = session.taskCategory {
                cat = c
            } else if let id = session.taskId,
                      let task = taskStore.tasks.first(where: { $0.id == id }) {
                cat = task.category
            } else {
                cat = .other
            }
            minutesStats[cat, default: 0] += session.durationMinutes
        }
        return minutesStats
            .map { (name: $0.key.rawValue, icon: $0.key.icon, color: $0.key.color, minutes: $0.value) }
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes > $1.minutes }
            .prefix(3)
            .map { $0 }
    }

    private var recentSessions: [FocusSession] {
        Array(sessionsInRange.sorted(by: { $0.timestamp > $1.timestamp }).prefix(8))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 40
            let topInset = AppTheme.detailTopInset
            let availableW = max(0, geo.size.width - pad * 2)
            let contentW = min(availableW, min(1760, max(1040, availableW * 0.84)))
            let contentH = max(0, geo.size.height - topInset)
            let primaryRowHeight = min(300, max(220, contentH * 0.30))
            let secondaryRowHeight = min(220, max(150, contentH * 0.20))
            let recentMinHeight = min(160, max(104, contentH * 0.14))

            ScrollView {
                let density = settings.uiDensity
                VStack(alignment: .leading, spacing: density.sectionSpacing) {
                    HStack(alignment: .top) {
                        PageTitle(
                            title: "数据统计",
                            subtitle: rangeSubtitle,
                            systemImage: "chart.bar.fill"
                        )
                        Spacer(minLength: 12)
                        Button {
                            shareWeeklyReport()
                        } label: {
                            Label("导出摘要", systemImage: "square.and.arrow.up")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("用邮件草稿导出当前时间范围摘要")
                        .padding(.top, 8)
                    }
                    
                    rangeChipsBar
                        .frame(maxWidth: 520)

                    summaryGrid

                    HStack(alignment: .top, spacing: 16) {
                        goalCard
                            .frame(maxWidth: contentW * 0.38)
                        weeklyCard
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: primaryRowHeight * density.scale)
                    
                    if range == .today {
                        todayTimelineCard
                            .frame(height: min(200, max(140, contentH * 0.18)) * density.scale)
                        todayHourCard
                            .frame(height: min(160, max(120, contentH * 0.14)) * density.scale)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        categoryCard
                            .frame(maxWidth: contentW * 0.34)
                        freeFocusCard
                            .frame(maxWidth: contentW * 0.28)
                        collapsibleAnalyticsCard(
                            title: "智能建议",
                            icon: "lightbulb.fill",
                            isExpanded: $showInsights
                        ) {
                            insightsCardBody
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: secondaryRowHeight * 0.55 * density.scale)

                    collapsibleAnalyticsCard(
                        title: "最近专注记录",
                        icon: "clock.arrow.circlepath",
                        isExpanded: $showRecent
                    ) {
                        recentSessionsBody
                    }
                    .frame(minHeight: showRecent ? recentMinHeight * density.scale : 44)
                    .padding(.bottom, 28)
                }
                .frame(width: contentW, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pad * density.scale)
                .padding(.top, topInset)
                .animation(.easeInOut(duration: 0.2), value: showInsights)
                .animation(.easeInOut(duration: 0.2), value: showRecent)
            }
            .softScroll()
            .frame(width: geo.size.width, height: contentH + topInset, alignment: .top)
        }
        .onReceive(timerStore.clockTick) { _ in
            guard timerStore.isRunning, timerStore.mode == .work else { return }
            clockVersion &+= 1
        }
    }

    private var rangeSubtitle: String {
        let mins = rangeTotals.minutes
        let pomos = rangeTotals.pomodoros
        let time = FocusStats.formatTotalMinutes(mins)
        if range == .today {
            return "\(range.rawValue) · \(pomos) 个番茄 · \(time)  ·  \(dayOverDayLabel)"
        }
        return "\(range.rawValue) · \(pomos) 个番茄 · \(time)"
    }
    
    private var rangeChipsBar: some View {
        HStack(spacing: 8) {
            ForEach(AnalyticsRange.allCases) { r in
                let selected = range == r
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        range = r
                    }
                } label: {
                    Text(r.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundColor(selected ? .white : AppTheme.primaryText(for: colorScheme).opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected
                                      ? AppTheme.accent
                                      : AppTheme.cardBackground(for: colorScheme))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selected ? Color.clear : AppTheme.separatorLow(for: colorScheme),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: selected ? AppTheme.accent.opacity(0.25) : .clear,
                            radius: 6,
                            y: 2
                        )
                }
                .buttonStyle(SoftScaleButtonStyle())
            }
            Spacer(minLength: 0)
        }
    }
    
    private var todayHourMinutes: [Int] {
        FocusStats.minutesByHourOfDay(
            sessions: sessionPairs,
            on: todayStart,
            calendar: calendar
        )
    }
    
    private var todayTimelineBlocks: [FocusStats.TimelineBlock] {
        let sessions = taskStore.focusSessions.map {
            (timestamp: $0.timestamp, minutes: $0.durationMinutes, title: $0.taskTitle)
        }
        return FocusStats.timelineBlocks(sessions: sessions, on: todayStart, calendar: calendar)
    }
    
    private var todayTimelineCard: some View {
        let blocks = todayTimelineBlocks
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
    
    private var todayHourCard: some View {
        let hours = todayHourMinutes
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

    // MARK: - KPI row

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                systemImage: "timer",
                value: "\(timerStore.completedPomodoros)/\(settings.dailyGoal)",
                label: goalRemaining == 0 && timerStore.completedPomodoros > 0
                    ? "今日番茄 · 已达标"
                    : (goalRemaining > 0 ? "今日番茄 · 还差 \(goalRemaining)" : "今日番茄"),
                tint: AppTheme.accent
            )
            StatCard(
                systemImage: "clock.fill",
                value: FocusStats.formatTotalMinutes(totalMinutesToday)
                    .replacingOccurrences(of: "分钟", with: "分")
                    .replacingOccurrences(of: "小时", with: "时"),
                label: "今日专注",
                tint: Color(hex: "#3B82F6")
            )
            StatCard(
                systemImage: "flame.fill",
                value: "\(streakCurrent)",
                label: streakCurrent > 0 ? "连续专注天数" : "连续天数 · 待开启",
                tint: Color(hex: "#F59E0B")
            )
            StatCard(
                systemImage: "chart.line.uptrend.xyaxis",
                value: dayOverDayShortValue,
                label: dayOverDayLabel,
                tint: dayOverDayTint
            )
        }
    }

    private var dayOverDayShortValue: String {
        if yesterdayTotals.minutes <= 0 {
            return totalMinutesToday > 0 ? "—" : "0"
        }
        guard let pct = FocusStats.percentChange(
            from: yesterdayTotals.minutes,
            to: totalMinutesToday
        ) else { return "—" }
        if pct > 0 { return "+\(pct)%" }
        return "\(pct)%"
    }

    private var dayOverDayTint: Color {
        if yesterdayTotals.minutes <= 0 { return Color(hex: "#6B7280") }
        guard let pct = FocusStats.percentChange(
            from: yesterdayTotals.minutes,
            to: totalMinutesToday
        ) else { return Color(hex: "#6B7280") }
        if pct > 0 { return Color(hex: "#10B981") }
        if pct < 0 { return Color(hex: "#EF4444") }
        return Color(hex: "#6B7280")
    }

    // MARK: - Goal + week chart

    private var goalCard: some View {
        AnalyticsCard(title: "今日目标", icon: "scope") {
            GeometryReader { g in
                let ring = min(132, min(g.size.width * 0.55, g.size.height * 0.52))
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.14), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: goalProgress)
                            .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: goalProgress)
                        VStack(spacing: 2) {
                            Text("\(Int(goalProgress * 100))%")
                                .font(.system(size: max(24, ring * 0.22), weight: .bold, design: .rounded))
                            Text(goalRemaining == 0 && timerStore.completedPomodoros > 0 ? "已完成" : "完成")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        }
                    }
                    .frame(width: ring, height: ring)

                    VStack(spacing: 8) {
                        ProgressRow(
                            label: "已完成",
                            valueText: "\(timerStore.completedPomodoros) 个",
                            color: AppTheme.accent
                        )
                        ProgressRow(
                            label: goalRemaining == 0 ? "目标" : "还剩",
                            valueText: goalRemaining == 0
                                ? "\(settings.dailyGoal) 个"
                                : "\(goalRemaining) 个",
                            color: .gray
                        )
                        ProgressRow(
                            label: "昨日",
                            valueText: "\(yesterdayTotals.pomodoros) 个 · \(yesterdayTotals.minutes) 分",
                            color: Color(hex: "#8B5CF6")
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var weeklyCard: some View {
        let chartSessions: [FocusSession] = {
            switch range {
            case .today: return sessionsInRange
            case .days7, .days30, .month: return sessionsInRange
            }
        }()
        let dayCount: Int = {
            switch range {
            case .today: return 1
            case .days7: return 7
            case .days30: return 30
            case .month:
                let days = calendar.dateComponents([.day], from: rangeBounds.from, to: rangeBounds.through).day ?? 0
                return max(1, days + 1)
            }
        }()
        return AnalyticsCard(title: "\(range.rawValue)趋势", icon: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    weekMeta(label: "番茄", value: "\(rangeTotals.pomodoros)")
                    weekMeta(label: "专注", value: FocusStats.formatTotalMinutes(rangeTotals.minutes))
                    Spacer()
                }
                if range == .today {
                    TodayHourChart(hourMinutes: todayHourMinutes)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WeeklyFocusChart(sessions: chartSessions, dayCount: dayCount)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func weekMeta(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
    }

    // MARK: - Category / free / insights

    private var categoryCard: some View {
        AnalyticsCard(title: "\(range.rawValue)分类 Top", icon: "square.grid.2x2.fill") {
            if categoryTop.isEmpty {
                EmptyStateView(systemImage: "tray", title: "暂无分类数据")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let total = max(1, categoryTop.reduce(0) { $0 + $1.minutes })
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(categoryTop.enumerated()), id: \.offset) { _, item in
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

    private var freeFocusCard: some View {
        AnalyticsCard(title: "任务绑定", icon: "link") {
            let pct = Int((freeShare * 100).rounded())
            let boundPct = max(0, 100 - pct)
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

    private var insightsCardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(insights.enumerated()), id: \.offset) { _, text in
                TipRow(text: text)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Recent

    private var recentSessionsBody: some View {
        Group {
            if recentSessions.isEmpty {
                EmptyStateView(systemImage: "tray", title: "暂无专注记录")
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentSessions) { session in
                        sessionRow(session)
                        if session.id != recentSessions.last?.id {
                            Divider().opacity(0.55)
                        }
                    }
                }
            }
        }
    }
    
    private func collapsibleAnalyticsCard<Content: View>(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(settings.uiDensity.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: 16))
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        let cat = resolvedCategory(for: session)
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

    private func resolvedCategory(for session: FocusSession) -> TaskCategory? {
        if let c = session.taskCategory { return c }
        if let id = session.taskId,
           let task = taskStore.tasks.first(where: { $0.id == id }) {
            return task.category
        }
        return nil
    }
    
    private func shareWeeklyReport() {
        let name = settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "小番茄" : name
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        let end = formatter.string(from: rangeBounds.through)
        let start = formatter.string(from: rangeBounds.from)
        
        var lines: [String] = [
            "\(who) 的 iFocus 专注摘要 · \(range.rawValue)（\(start) – \(end)）",
            "",
            "· 番茄：\(rangeTotals.pomodoros) 个",
            "· 专注：\(FocusStats.formatTotalMinutes(rangeTotals.minutes))",
            "· 今日：\(timerStore.completedPomodoros) 个 / \(FocusStats.formatTotalMinutes(totalMinutesToday))",
            "· 连续天数：\(streakCurrent) 天",
            "· 任务绑定率：\(Int(((1 - freeShare) * 100).rounded()))%",
            "",
            "分类："
        ]
        
        if categoryTop.isEmpty {
            lines.append("· 暂无分类数据")
        } else {
            for item in categoryTop {
                lines.append("· \(item.name)：\(item.minutes) 分钟")
            }
        }
        
        lines.append("")
        lines.append(dayOverDayLabel)
        lines.append("")
        lines.append("-- 来自 iFocus macOS")
        
        let body = lines.joined(separator: "\n")
        let subject = "iFocus 周报 \(end)"
        let allowed = CharacterSet.urlQueryAllowed
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Shared chrome

private struct AnalyticsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: 16))
    }
}

private struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoftCardBackground(cornerRadius: 16))
    }
}

private struct ProgressRow: View {
    let label: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(valueText).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

private struct TipRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#F59E0B"))
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let title: String

    var body: some View {
        AppEmptyState(systemImage: systemImage, title: title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Today timeline (block view)

struct TodayTimelineView: View {
    let blocks: [FocusStats.TimelineBlock]
    @Environment(\.colorScheme) private var colorScheme
    
    private let hourLabels = [0, 6, 12, 18, 24]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = max(36, geo.size.height - 18)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.separator(for: colorScheme).opacity(0.35))
                        .frame(height: h)
                    
                    ForEach(blocks) { block in
                        let prog = block.dayProgress()
                        let x = prog.start * w
                        let width = max(8, (prog.end - prog.start) * w)
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.85))
                                .frame(width: width, height: h * 0.72)
                                .overlay(
                                    Text(block.title)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 4)
                                        .opacity(width > 48 ? 1 : 0)
                                )
                                .help("\(block.title) · \(block.minutes) 分")
                        }
                        .offset(x: x, y: h * 0.14)
                    }
                }
            }
            
            HStack {
                ForEach(hourLabels, id: \.self) { hour in
                    Text(String(format: "%02d", hour == 24 ? 24 : hour))
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    if hour < 24 { Spacer(minLength: 0) }
                }
            }
        }
    }
}

// MARK: - Today hour distribution

struct TodayHourChart: View {
    let hourMinutes: [Int]
    
    private struct HourBar: Identifiable {
        let id: Int
        let label: String
        let minutes: Int
    }
    
    private var data: [HourBar] {
        hourMinutes.enumerated().map { index, mins in
            HourBar(
                id: index,
                label: index % 3 == 0 ? String(format: "%02d", index) : "",
                minutes: mins
            )
        }
    }
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("时", item.id),
                y: .value("分钟", item.minutes)
            )
            .foregroundStyle(AppTheme.accent.gradient)
            .cornerRadius(2)
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) {
                        Text(String(format: "%02d", h))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Weekly Focus Chart

struct WeeklyFocusChart: View {
    let sessions: [FocusSession]
    var dayCount: Int = 7
    @Environment(\.colorScheme) private var colorScheme

    struct DayFocus: Identifiable {
        var id: String { label }
        let label: String
        let minutes: Int
    }

    private var chartData: [DayFocus] {
        let calendar = Calendar.current
        var data: [DayFocus] = []
        let today = calendar.startOfDay(for: Date())
        let days = max(1, min(dayCount, 62))

        let formatter = DateFormatter()
        formatter.dateFormat = days > 14 ? "M/d" : "MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")

        for i in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let daySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let mins = daySessions.reduce(0) { $0 + $1.durationMinutes }
            data.append(DayFocus(label: formatter.string(from: day), minutes: mins))
        }
        return data
    }

    var body: some View {
        Chart {
            ForEach(chartData) { item in
                BarMark(
                    x: .value("日期", item.label),
                    y: .value("分钟", item.minutes)
                )
                .foregroundStyle(AppTheme.accent.gradient)
                .cornerRadius(4)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
}

private let sessionDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    f.locale = Locale(identifier: "zh_CN")
    return f
}()
