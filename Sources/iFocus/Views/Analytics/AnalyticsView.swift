import SwiftUI
import AppKit
import iFocusCore

/// Stats dashboard — thin composition over `AnalyticsDashboardModel`.
struct AnalyticsView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    /// Dashboard numbers are minute-granularity. Ignore per-second ticks inside the same minute.
    @State private var liveMinuteBucket: Int = -1
    @State private var range: AnalyticsTimeRange = .today
    @State private var showCustomizeCards = false
    @Namespace private var rangeNamespace

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
            let primaryRowHeight = min(260, max(180, contentH * 0.30))
            let detailHeight = min(148, max(110, contentH * 0.13)) * settings.uiDensity.scale
            let m = model

            ScrollView {
                let density = settings.uiDensity
                VStack(alignment: .leading, spacing: max(16, density.sectionSpacing + 2)) {
                    header(model: m)

                    rangeChipsBar

                    if !m.hasAnyHistory {
                        AnalyticsCards.emptyShell(colorScheme: colorScheme)
                    } else {
                        dashboardStack(
                            model: m,
                            contentW: contentW,
                            primaryRowHeight: primaryRowHeight,
                            detailHeight: detailHeight,
                            density: density
                        )
                    }
                }
                .frame(width: contentW, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pad * density.scale)
                .padding(.top, topInset)
                .padding(.bottom, timerStore.isSessionInProgress ? 96 : 32)
                .animation(.easeInOut(duration: 0.2), value: settings.analyticsShowGoal)
                .animation(.easeInOut(duration: 0.2), value: settings.analyticsShowRecent)
                .animation(.easeInOut(duration: 0.2), value: settings.anyAnalyticsCardEnabled)
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
    }

    private func header(model: AnalyticsDashboardModel) -> some View {
        PageTitle(
            title: "数据统计",
            subtitle: model.rangeSubtitle,
            systemImage: "chart.bar.fill"
        )
        .overlay(alignment: .trailing) {
            HStack(spacing: 14) {
                customizeCardsButton
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

    @ViewBuilder
    private func dashboardStack(
        model: AnalyticsDashboardModel,
        contentW: CGFloat,
        primaryRowHeight: CGFloat,
        detailHeight: CGFloat,
        density: UIDensity
    ) -> some View {
        if settings.analyticsShowInsight, let line = model.headlineInsight {
            AnalyticsCards.insightBanner(line, colorScheme: colorScheme)
        }

        if settings.analyticsShowKPI {
            AnalyticsCards.summaryGrid(model: model, colorScheme: colorScheme)
        }

        if settings.analyticsShowGoal || settings.analyticsShowTrend {
            HStack(alignment: .top, spacing: 16) {
                if settings.analyticsShowGoal {
                    AnalyticsCards.goalCard(model: model, colorScheme: colorScheme)
                        .frame(maxWidth: settings.analyticsShowTrend ? contentW * 0.38 : .infinity)
                }
                if settings.analyticsShowTrend {
                    AnalyticsCards.weeklyCard(model: model, colorScheme: colorScheme)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: primaryRowHeight * density.scale)
        }

        if range == .today, settings.analyticsShowTimeline {
            AnalyticsCards.timelineCard(model: model)
                .frame(height: detailHeight)
        }

        if range == .today, settings.analyticsShowHours {
            AnalyticsCards.hourCard(model: model)
                .frame(height: detailHeight * 0.9)
        }

        if settings.analyticsShowCategory || settings.analyticsShowTaskBinding {
            HStack(alignment: .top, spacing: 14) {
                if settings.analyticsShowCategory {
                    AnalyticsCards.categoryCard(model: model, colorScheme: colorScheme)
                        .frame(maxWidth: .infinity)
                }
                if settings.analyticsShowTaskBinding {
                    AnalyticsCards.freeFocusCard(model: model, colorScheme: colorScheme)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(minHeight: 120 * density.scale)
        }

        if settings.analyticsShowRecent {
            AnalyticsCard(title: "最近记录", icon: "clock.arrow.circlepath") {
                AnalyticsCards.recentBody(
                    model: model,
                    tasks: taskStore.tasks,
                    colorScheme: colorScheme
                )
            }
            .frame(minHeight: 120 * density.scale)
        }

        if !settings.anyAnalyticsCardEnabled {
            allCardsOffHint
        }
    }

    private var customizeCardsButton: some View {
        Button("自定义卡片") {
            showCustomizeCards.toggle()
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        .help("自定义展示卡片")
        .popover(isPresented: $showCustomizeCards, arrowEdge: .bottom) {
            AnalyticsCardVisibilityEditor(settings: settings, style: .compact)
                .padding(16)
                .frame(width: 300)
                .background(AppTheme.menuBackground(for: colorScheme))
        }
    }

    private var allCardsOffHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("所有卡片已关闭")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            Text("打开需要的内容，或一键恢复安静默认。")
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            HStack(spacing: 8) {
                Button("自定义展示…") { showCustomizeCards = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("恢复安静默认") {
                    settings.resetAnalyticsCardVisibilityToQuietDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
        .padding(.top, 4)
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
                                    .fill(AppTheme.cardBackground(for: colorScheme))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
                                    )
                                    .multiLayerShadow(elevation: .row, colorScheme: colorScheme)
                                    .matchedGeometryEffect(id: "activeRangePill", in: rangeNamespace)
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
