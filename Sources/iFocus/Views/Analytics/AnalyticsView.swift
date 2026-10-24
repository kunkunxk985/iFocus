import SwiftUI
import AppKit
import iFocusCore

/// One record page: who you are, then this range, then the longer picture.
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    /// Dashboard numbers are minute-granularity. Ignore per-second ticks inside the same minute.
    @State private var liveMinuteBucket: Int = -1
    @State private var range: AnalyticsTimeRange = .today
    @State private var isEditingProfile = false
    @State private var tempUsername = ""

    private var model: AnalyticsDashboardModel {
        _ = clockVersion
        return AnalyticsDashboardModel.build(
            range: range,
            focusSessions: taskStore.focusSessions,
            tasks: taskStore.tasks,
            dailyGoal: settings.dailyGoal,
            completedPomodoros: timerStore.completedPomodoros,
            totalSecondsToday: timerStore.totalSecondsToday,
            isWorkMode: timerStore.mode == .work,
            sessionLive: timerStore.isSessionInProgress || timerStore.isRunning
        )
    }

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 36
            let topInset = AppTheme.detailTopInset
            let availableW = max(0, geo.size.width - pad * 2)
            let contentW = min(availableW, min(1100, max(720, availableW * 0.88)))
            let contentH = max(0, geo.size.height - topInset)
            let chartHeight = min(280, max(200, contentH * 0.42))
            let m = model

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(model: m)
                    identityRow
                    rangeChipsBar

                    if !m.hasAnyHistory {
                        AnalyticsCards.emptyShell(colorScheme: colorScheme)
                    } else {
                        AnalyticsCards.weeklyCard(model: m, colorScheme: colorScheme)
                            .frame(height: chartHeight)
                    }

                    ProfileHeatmapCard(
                        grid: heatmapGrid,
                        monthLabels: heatmapMonthLabels
                    )

                    HStack(alignment: .top, spacing: 20) {
                        ProfileInsightsCard(
                            maxSingleFocusSession: taskStore.focusSessions.map(\.durationMinutes).max() ?? 0,
                            averageDailyLabel: FocusStats.formatTotalMinutes(
                                FocusStats.averageDailyFocusMinutes(
                                    sessionTimestamps: sessionTimestamps,
                                    totalMinutes: totalMinutes
                                )
                            ),
                            peakHours: FocusStats.peakFocusHoursString(sessionTimestamps: sessionTimestamps),
                            completionRate: FocusStats.completionRate(
                                total: taskStore.tasks.count,
                                completed: taskStore.tasks.filter(\.isCompleted).count
                            )
                        )
                        .frame(maxWidth: .infinity)

                        ProfileCategoriesCard(
                            stats: categoryStats,
                            isEmpty: taskStore.focusSessions.isEmpty
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: contentW, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pad)
                .padding(.top, topInset)
                .padding(.bottom, timerStore.isSessionInProgress ? 96 : 32)
            }
            .softScroll()
            .frame(width: geo.size.width, height: contentH + topInset, alignment: .top)
        }
        .onAppear {
            liveMinuteBucket = timerStore.totalSecondsToday / 60
        }
        .onReceive(timerStore.clockTick) { _ in
            guard timerStore.isRunning, timerStore.mode == .work else { return }
            let bucket = timerStore.totalSecondsToday / 60
            guard bucket != liveMinuteBucket else { return }
            liveMinuteBucket = bucket
            clockVersion &+= 1
        }
        .overlay {
            if isEditingProfile {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { isEditingProfile = false }
                    EditProfileSheet(
                        tempUsername: $tempUsername,
                        isPresented: $isEditingProfile
                    )
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isEditingProfile)
    }

    private func header(model: AnalyticsDashboardModel) -> some View {
        PageTitle(
            title: "我的记录",
            subtitle: model.rangeSubtitle,
            systemImage: "chart.bar"
        )
        .overlay(alignment: .trailing) {
            HStack(spacing: 14) {
                Button("编辑资料") {
                    tempUsername = displayName
                    isEditingProfile = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                if model.hasAnyHistory {
                    Button("导出摘要", action: shareReport)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .help("导出摘要（邮件或剪贴板）")
                        .accessibilityLabel("导出摘要")
                }
            }
        }
    }

    private var displayName: String {
        let name = settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "小番茄" : name
    }

    private var sessionTimestamps: [Date] {
        taskStore.focusSessions.map(\.timestamp)
    }

    private var totalMinutes: Int {
        taskStore.focusSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var heatmapGrid: [[FocusStats.ContributionCell]] {
        let pairs = taskStore.focusSessions.map { ($0.timestamp, $0.durationMinutes) }
        let byDay = FocusStats.minutesByDay(sessions: pairs)
        return FocusStats.contributionGrid(minutesByDay: byDay)
    }

    private var heatmapMonthLabels: [Int: String] {
        FocusStats.monthLabels(for: heatmapGrid)
    }

    private var categoryStats: [ProfileCategoryStat] {
        var minutesByID = [String: Int]()
        var countByID = [String: Int]()
        var categoriesByID = Dictionary(
            uniqueKeysWithValues: taskStore.categoriesInUse.map { ($0.id, $0) }
        )
        for session in taskStore.focusSessions {
            let category: TaskCategory
            if let stored = session.taskCategory {
                category = stored
            } else if let taskId = session.taskId,
                      let task = taskStore.tasks.first(where: { $0.id == taskId }) {
                category = task.category
            } else {
                category = .other
            }
            if categoriesByID[category.id] == nil {
                categoriesByID[category.id] = category
            }
            minutesByID[category.id, default: 0] += session.durationMinutes
            countByID[category.id, default: 0] += 1
        }
        return taskStore.categoriesInUse.map { cat in
            ProfileCategoryStat(
                category: categoriesByID[cat.id] ?? cat,
                minutes: minutesByID[cat.id] ?? 0,
                count: countByID[cat.id] ?? 0
            )
        }
        .sorted { $0.minutes > $1.minutes }
    }

    private var identityRow: some View {
        let streak = FocusStats.streaks(sessionTimestamps: sessionTimestamps)
        return HStack(spacing: 12) {
            UnifiedAvatarView(
                path: settings.avatarPath,
                colorIndex: settings.avatarColorIndex,
                username: displayName,
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text("连续 \(streak.current) 天 · 累计 \(FocusStats.formatTotalMinutes(totalMinutes))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Spacer(minLength: 0)
        }
    }

    private var rangeChipsBar: some View {
        HStack(spacing: 6) {
            ForEach(AnalyticsTimeRange.allCases) { r in
                let selected = range == r
                Button {
                    withAnimation(AppTheme.springInteractive) { range = r }
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundColor(
                            selected
                            ? AppTheme.primaryText(for: colorScheme)
                            : AppTheme.secondaryText(for: colorScheme).opacity(0.85)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.22))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func shareReport() {
        let report = model.reportText(username: settings.username)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encodedSubject = report.subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = report.body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report.body, forType: .string)
            return
        }
        let urlString = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlString), urlString.count < 7000 {
            NSWorkspace.shared.open(url)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(report.subject)\n\n\(report.body)", forType: .string)
        }
    }
}
