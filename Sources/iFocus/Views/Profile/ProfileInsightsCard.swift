import SwiftUI
import iFocusCore

struct ProfileInsightsCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let maxSingleFocusSession: Int
    let averageDailyLabel: String
    let peakHours: String
    let completionRate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)).frame(width: 22, height: 22)
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundColor(AppTheme.accent)
                }
                Text("统计洞察").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(AppTheme.primaryText(for: colorScheme))
            }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    tile(icon: "stopwatch", title: "单次最长", value: FocusStats.formatTotalMinutes(maxSingleFocusSession))
                    tile(icon: "clock.fill", title: "日均专注", value: averageDailyLabel)
                }
                HStack(spacing: 10) {
                    tile(icon: "sun.max.fill", title: "黄金时段", value: peakHours)
                    tile(icon: "checkmark.circle.fill", title: "任务完成率", value: completionRate)
                }
            }
        }
        .padding(18)
        .frame(minHeight: 168, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }

    private func tile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ZStack {
                    AppTheme.squircle(radius: 6).fill(AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.14)).frame(width: 24, height: 24)
                    Image(systemName: icon).font(.system(size: 11.5, weight: .bold)).foregroundColor(AppTheme.accent)
                }
                Text(title).font(.system(size: 11.5, weight: .medium)).foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.squircle(radius: 12).fill(AppTheme.accent.opacity(colorScheme == .light ? 0.06 : 0.08)))
        .overlay(AppTheme.squircle(radius: 12).strokeBorder(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.18), lineWidth: 0.8))
    }
}
