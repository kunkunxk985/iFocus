import SwiftUI

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
                    Circle()
                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                        .frame(width: 22, height: 22)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
                Text("活动洞察")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
            }
            .padding(.bottom, 2)
            
            VStack(spacing: 10) {
                InsightRow(icon: "bolt.fill", iconTint: Color(hex: "#F59E0B"), label: "单次最长专注", value: "\(maxSingleFocusSession) 分钟")
                Divider().opacity(0.4)
                InsightRow(icon: "hourglass", iconTint: Color(hex: "#3B82F6"), label: "平均每日专注", value: averageDailyLabel)
                Divider().opacity(0.4)
                InsightRow(icon: "clock.fill", iconTint: Color(hex: "#8B5CF6"), label: "最常专注时段", value: peakHours)
                Divider().opacity(0.4)
                InsightRow(icon: "checkmark.seal.fill", iconTint: Color(hex: "#10B981"), label: "任务完成率", value: completionRate)
            }
        }
        .padding(18)
        .frame(minHeight: 200, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

struct InsightRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let iconTint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(iconTint)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))

            Spacer()

            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
    }
}
