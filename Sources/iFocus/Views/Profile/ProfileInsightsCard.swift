import SwiftUI

struct ProfileInsightsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let maxSingleFocusSession: Int
    let averageDailyLabel: String
    let peakHours: String
    let completionRate: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("活动洞察")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.bottom, 4)
            
            InsightRow(label: "单次最长专注", value: "\(maxSingleFocusSession)分钟")
            InsightRow(label: "平均每日专注", value: averageDailyLabel)
            InsightRow(label: "最常专注时段", value: peakHours)
            InsightRow(label: "任务完成率", value: completionRate)
        }
        .padding(18)
        .frame(minHeight: 200)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

struct InsightRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
        .font(.subheadline)
    }
}
