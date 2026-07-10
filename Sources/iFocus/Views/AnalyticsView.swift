import SwiftUI
import Charts
import AppKit
import iFocusCore

/// Stats dashboard — today / week operations board (A-tier insights).
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    /// Local only — do not put clock ticks on ContentView.
    @State private var clockVersion: UInt = 0

    // MARK: - Derived metrics

    private var sessionPairs: [(timestamp: Date, minutes: Int)] {
        taskStore.focusSessions.map { ($0.timestamp, $0.durationMinutes) }
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

    private var weekTotals: FocusStats.DayFocusTotals {
        FocusStats.rangeTotals(
            sessions: sessionPairs,
            from: weekStart,
            through: todayStart,
            calendar: calendar
        )
    }

    private var streakCurrent: Int {
        FocusStats.streaks(
            sessionTimestamps: taskStore.focusSessions.map(\.timestamp),
            relativeTo: Date(),
            calendar: calendar
        ).current
    }

    private var freeShare: Double {
        let total = taskStore.focusSessions.count
        let free = taskStore.focusSessions.filter { $0.taskId == nil }.count
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
        for session in taskStore.focusSessions {
            // Prefer sessions in the rolling week for analytics relevance.
            let day = calendar.startOfDay(for: session.timestamp)
            guard day >= weekStart else { continue }
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
        Array(taskStore.focusSessions.sorted(by: { $0.timestamp > $1.timestamp }).prefix(8))
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        PageTitle(
                            title: "数据统计",
                            subtitle: weekSubtitle,
                            systemImage: "chart.bar.fill"
                        )
                        Spacer(minLength: 12)
                        Button {
                            shareWeeklyReport()
                        } label: {
                            Label("导出周报", systemImage: "square.and.arrow.up")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("用邮件草稿生成近 7 天专注摘要")
                        .padding(.top, 8)
                    }

                    summaryGrid

                    HStack(alignment: .top, spacing: 16) {
                        goalCard
                            .frame(maxWidth: contentW * 0.38)
                        weeklyCard
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: primaryRowHeight)

                    HStack(alignment: .top, spacing: 16) {
                        categoryCard
                            .frame(maxWidth: contentW * 0.34)
                        freeFocusCard
                            .frame(maxWidth: contentW * 0.28)
                        insightsCard
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: secondaryRowHeight)

                    recentSessionsCard
                        .frame(minHeight: recentMinHeight)
                        .padding(.bottom, 28)
                }
                .frame(width: contentW, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pad)
                .padding(.top, topInset)
            }
            .softScroll()
            .frame(width: geo.size.width, height: contentH + topInset, alignment: .top)
        }
        .onReceive(timerStore.clockTick) { _ in
            guard timerStore.isRunning, timerStore.mode == .work else { return }
            clockVersion &+= 1
        }
    }

    private var weekSubtitle: String {
        let mins = weekTotals.minutes
        let pomos = weekTotals.pomodoros
        let time = FocusStats.formatTotalMinutes(mins)
        return "近 7 天 · \(pomos) 个番茄 · \(time)  ·  \(dayOverDayLabel)"
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
        AnalyticsCard(title: "近 7 天趋势", icon: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    weekMeta(label: "本周番茄", value: "\(weekTotals.pomodoros)")
                    weekMeta(label: "本周专注", value: FocusStats.formatTotalMinutes(weekTotals.minutes))
                    Spacer()
                }
                WeeklyFocusChart(sessions: taskStore.focusSessions)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        AnalyticsCard(title: "本周分类 Top", icon: "square.grid.2x2.fill") {
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

    private var insightsCard: some View {
        AnalyticsCard(title: "智能建议", icon: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(insights.enumerated()), id: \.offset) { _, text in
                    TipRow(text: text)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Recent

    private var recentSessionsCard: some View {
        AnalyticsCard(title: "最近专注记录", icon: "clock.arrow.circlepath") {
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
        let end = formatter.string(from: Date())
        let start = formatter.string(from: weekStart)
        
        var lines: [String] = [
            "\(who) 的 iFocus 近 7 天专注周报（\(start) – \(end)）",
            "",
            "· 番茄：\(weekTotals.pomodoros) 个",
            "· 专注：\(FocusStats.formatTotalMinutes(weekTotals.minutes))",
            "· 今日：\(timerStore.completedPomodoros) 个 / \(FocusStats.formatTotalMinutes(totalMinutesToday))",
            "· 连续天数：\(streakCurrent) 天",
            "· 任务绑定率：\(Int(((1 - freeShare) * 100).rounded()))%",
            "",
            "本周分类："
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
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Weekly Focus Chart

struct WeeklyFocusChart: View {
    let sessions: [FocusSession]
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

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")

        for i in (0..<7).reversed() {
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
