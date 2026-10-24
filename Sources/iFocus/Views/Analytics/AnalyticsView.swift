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
                    rangeChipsBar

                    if !m.hasAnyHistory {
                        AnalyticsCards.emptyShell(colorScheme: colorScheme)
                    } else {
                        AnalyticsCards.weeklyCard(model: m, colorScheme: colorScheme)
                            .frame(height: chartHeight)
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
    }

    private func header(model: AnalyticsDashboardModel) -> some View {
        PageTitle(
            title: "数据统计",
            subtitle: model.rangeSubtitle,
            systemImage: "chart.bar.fill"
        )
        .overlay(alignment: .trailing) {
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
