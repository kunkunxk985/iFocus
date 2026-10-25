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

    private var snapshot: AnalyticsPageSnapshot {
        _ = clockVersion
        return AnalyticsPageSnapshot.build(
            range: range,
            focusSessions: taskStore.focusSessions,
            tasks: taskStore.tasks,
            categoriesInUse: taskStore.categoriesInUse,
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
            let page = snapshot
            let m = page.model

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(model: m)
                    rangeChipsBar

                    if !m.hasAnyHistory {
                        AnalyticsCards.emptyShell(colorScheme: colorScheme)
                    } else {
                        AnalyticsCards.achievementHero(
                            model: m,
                            totalMinutesAllTime: page.totalMinutesAllTime,
                            displayName: displayName,
                            avatarPath: settings.avatarPath,
                            avatarColorIndex: settings.avatarColorIndex,
                            colorScheme: colorScheme,
                            decorativeMotion: settings.decorativeMotionEnabled
                        )

                        AnalyticsCards.weeklyCard(model: m, colorScheme: colorScheme)
                            .frame(height: chartHeight)
                    }

                    ProfileHeatmapCard(
                        grid: page.heatmapGrid,
                        monthLabels: page.heatmapMonthLabels
                    )

                    ProfileInsightsCard(
                        maxSingleFocusSession: page.maxSingleFocusSession,
                        averageDailyLabel: page.averageDailyLabel,
                        peakHours: page.peakHours,
                        completionRate: page.completionRate
                    )
                    .frame(maxWidth: .infinity)
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

    private var rangeChipsBar: some View {
        HStack(spacing: 6) {
            ForEach(AnalyticsTimeRange.allCases) { r in
                let selected = range == r
                Button {
                    withAnimation(AppTheme.springInteractive) { range = r }
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium, design: .rounded))
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
        let report = snapshot.model.reportText(username: settings.username)
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
