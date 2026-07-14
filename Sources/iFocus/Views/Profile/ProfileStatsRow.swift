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
            statColumn(value: "\(todayPomodoros)个", label: "今日番茄")
            statDivider
            statColumn(value: FocusStats.formatTotalMinutes(totalMinutes), label: "累计专注")
            statDivider
            statColumn(value: "\(totalPomodoros)个", label: "累计番茄")
            statDivider
            statColumn(value: "\(currentStreak)天", label: "当前连续天数")
            statDivider
            statColumn(value: "\(longestStreak)天", label: "最长连续天数")
        }
        .padding(.vertical, 16)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
    
    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statDivider: some View {
        Rectangle()
            .fill(AppTheme.separatorLow(for: colorScheme))
            .frame(width: 1, height: 26)
    }
}
