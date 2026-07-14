import SwiftUI
import iFocusCore

struct ProfileStatsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let todayPomodoros: Int
    let totalMinutes: Int
    let totalPomodoros: Int
    let currentStreak: Int
    let longestStreak: Int
    
    var body: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(todayPomodoros)", label: "今日")
            statDivider
            statColumn(value: FocusStats.formatTotalMinutes(totalMinutes), label: "累计")
            statDivider
            statColumn(value: "\(totalPomodoros)", label: "番茄")
            statDivider
            statColumn(value: "\(currentStreak)", label: "连续")
            statDivider
            statColumn(value: "\(longestStreak)", label: "最长")
        }
        .padding(.vertical, 14)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
    
    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statDivider: some View {
        Rectangle()
            .fill(AppTheme.separatorLow(for: colorScheme))
            .frame(width: 1, height: 26)
    }
}
