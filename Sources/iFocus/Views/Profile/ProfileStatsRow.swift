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
            statColumn(icon: "timer", value: "\(todayPomodoros)", label: "今日番茄", tint: AppTheme.accent)
            statDivider
            statColumn(icon: "clock", value: FocusStats.formatTotalMinutes(totalMinutes), label: "累计专注", tint: Color(hex: "#3B82F6"))
            statDivider
            statColumn(icon: "checkmark.circle", value: "\(totalPomodoros)", label: "总完成", tint: Color(hex: "#10B981"))
            statDivider
            statColumn(icon: "flame", value: "\(currentStreak)", label: "连续天数", tint: Color(hex: "#F59E0B"))
            statDivider
            statColumn(icon: "trophy", value: "\(longestStreak)", label: "最高连续", tint: Color(hex: "#8B5CF6"))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
    
    private func statColumn(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statDivider: some View {
        LinearGradient(
            colors: [
                Color.clear,
                AppTheme.separatorLow(for: colorScheme),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: 28)
    }
}
