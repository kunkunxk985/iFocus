import SwiftUI
import AppKit
import iFocusCore

/// One record page: who you are, then this range, then the longer picture.
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
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
                    Color.black.opacity(colorScheme == .light ? 0.20 : 0.45)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(AppTheme.springInteractive) {
                                isEditingProfile = false
                            }
                        }
                    EditProfileSheet(
                        tempUsername: $tempUsername,
                        isPresented: $isEditingProfile
                    )
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .animation(AppTheme.springInteractive, value: isEditingProfile)
        .onChange(of: isEditingProfile) { isPresented in
            viewState.isModalOverlayPresented = isPresented
        }
        .onDisappear {
            viewState.isModalOverlayPresented = false
        }
        .onExitCommand {
            if isEditingProfile {
                withAnimation(AppTheme.springInteractive) {
                    isEditingProfile = false
                }
            }
        }
    }

    private func header(model: AnalyticsDashboardModel) -> some View {
        PageTitle(
            title: "我的记录",
            subtitle: model.rangeSubtitle,
            systemImage: "chart.bar"
        )
        .overlay(alignment: .trailing) {
            HStack(spacing: 8) {
                Button {
                    tempUsername = displayName
                    withAnimation(AppTheme.springInteractive) {
                        isEditingProfile = true
                    }
                } label: {
                    PageHeaderActionPillLabel(
                        title: "编辑资料",
                        systemImage: "person.crop.circle"
                    )
                }
                .buttonStyle(.plain)

                if model.hasAnyHistory {
                    Button(action: shareReport) {
                        PageHeaderActionPillLabel(
                            title: "导出摘要",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.plain)
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

    private func chipTitle(for r: AnalyticsTimeRange) -> String {
        switch r {
        case .today: return "今天"
        case .days7: return "7天"
        case .days30: return "30天"
        case .month: return "本月"
        }
    }

    private var rangeChipsBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(AnalyticsTimeRange.allCases) { r in
                    let selected = range == r
                    Button {
                        withAnimation(AppTheme.springInteractive) { range = r }
                    } label: {
                        Text(chipTitle(for: r))
                            .font(.system(size: 12, weight: selected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(
                                selected
                                    ? .white
                                    : AppTheme.secondaryText(for: colorScheme).opacity(0.88)
                            )
                            .padding(.horizontal, 13)
                            .padding(.vertical, 5.5)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(AppTheme.accent)
                                        .shadow(color: AppTheme.accent.opacity(0.28), radius: 3, y: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
            )
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
