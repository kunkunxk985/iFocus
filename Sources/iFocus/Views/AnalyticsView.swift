import SwiftUI
import Charts

/// Stats dashboard — fills the stage without system scrollbars at normal sizes.
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    /// Local only — do not put clock ticks on ContentView.
    @State private var clockVersion: UInt = 0

    private var goalProgress: Double {
        guard settings.dailyGoal > 0 else { return 0 }
        return min(Double(timerStore.completedPomodoros) / Double(settings.dailyGoal), 1.0)
    }

    private var totalMinutesToday: Int {
        _ = clockVersion
        return timerStore.totalSecondsToday / 60
    }

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 40
            let topInset = AppTheme.detailTopInset
            let contentW = min(1000, geo.size.width - pad * 2)
            let contentH = max(0, geo.size.height - topInset)
            
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "数据统计",
                    subtitle: "今天的进度与近期专注记录",
                    systemImage: "chart.bar.fill"
                )
                
                summaryGrid
                
                // Middle row shares remaining height
                HStack(alignment: .top, spacing: 16) {
                    goalCard
                        .frame(maxWidth: contentW * 0.40)
                    weeklyCard
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                
                // Bottom row
                HStack(alignment: .top, spacing: 16) {
                    recentSessionsCard
                        .frame(maxWidth: .infinity)
                    tipsCard
                        .frame(maxWidth: contentW * 0.38)
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 28)
            }
            .frame(width: contentW, height: contentH, alignment: .top)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, pad)
            .padding(.top, topInset)
        }
        .onReceive(timerStore.clockTick) { _ in
            // Only while a work segment is running does live minutes change.
            guard timerStore.isRunning, timerStore.mode == .work else { return }
            clockVersion &+= 1
        }
    }
    
    private var summaryGrid: some View {
        HStack(spacing: 14) {
            StatCard(systemImage: "timer", value: "\(timerStore.completedPomodoros)", label: "今日番茄", tint: AppTheme.accent)
            StatCard(systemImage: "clock.fill", value: "\(totalMinutesToday)", label: "专注分钟", tint: Color(hex: "#3B82F6"))
            StatCard(systemImage: "target", value: "\(settings.dailyGoal)", label: "每日目标", tint: Color(hex: "#10B981"))
        }
    }
    
    private var goalCard: some View {
        AnalyticsCard(title: "今日目标", icon: "scope") {
            GeometryReader { g in
                let ring = min(140, min(g.size.width * 0.55, g.size.height * 0.55))
                VStack(spacing: 14) {
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
                                .font(.system(size: max(26, ring * 0.22), weight: .bold, design: .rounded))
                            Text("完成")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        }
                    }
                    .frame(width: ring, height: ring)
                    
                    VStack(spacing: 8) {
                        ProgressRow(label: "已完成", value: timerStore.completedPomodoros, color: AppTheme.accent)
                        ProgressRow(label: "还剩", value: max(0, settings.dailyGoal - timerStore.completedPomodoros), color: .gray)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var weeklyCard: some View {
        AnalyticsCard(title: "本周趋势", icon: "calendar") {
            WeeklyFocusChart(sessions: taskStore.focusSessions)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var recentSessionsCard: some View {
        let recent = Array(taskStore.focusSessions.sorted(by: { $0.timestamp > $1.timestamp }).prefix(4))
        return AnalyticsCard(title: "最近专注记录", icon: "clock.arrow.circlepath") {
            if recent.isEmpty {
                EmptyStateView(systemImage: "tray", title: "暂无专注记录")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { session in
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(AppTheme.accent.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.taskTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(sessionDateFormatter.string(from: session.timestamp))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            }
                            Spacer()
                            Text("\(session.durationMinutes) 分")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                        .padding(.vertical, 8)
                        
                        if session.id != recent.last?.id {
                            Divider().opacity(0.6)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    private var tipsCard: some View {
        AnalyticsCard(title: "小贴士", icon: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(text: "每完成 4 个番茄钟，安排一次长休息。")
                TipRow(text: "专注前先选定任务，统计会更有意义。")
                TipRow(text: "如果任务被打断，可以重置当前番茄。")
                Spacer(minLength: 0)
            }
        }
    }
}

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
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftCardBackground(cornerRadius: 16))
    }
}

private struct ProgressRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text("\(value) 个").font(.subheadline.weight(.semibold))
        }
    }
}

private struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#10B981"))
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
        let id = UUID()
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
