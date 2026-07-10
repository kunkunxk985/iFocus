import SwiftUI
import iFocusCore

struct ProfileHeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let grid: [[FocusStats.ContributionCell]]
    let monthLabels: [Int: String]
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("专注热力图")
                    .font(.headline)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Spacer()
                Text("每日")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
            }
            
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(0..<grid.count, id: \.self) { colIndex in
                            VStack(spacing: 3) {
                                ForEach(Array(grid[colIndex].enumerated()), id: \.offset) { _, cell in
                                    RoundedRectangle(cornerRadius: 1.8)
                                        .fill(colorForMinutes(cell.minutes))
                                        .frame(width: 10, height: 10)
                                        .help("\(dateFormatter.string(from: cell.date)): 专注 \(cell.minutes) 分钟")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 3) {
                        ForEach(0..<grid.count, id: \.self) { c in
                            Group {
                                if let label = monthLabels[c] {
                                    Text(label)
                                        .font(.system(size: 9))
                                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                } else {
                                    Text("")
                                        .font(.system(size: 9))
                                }
                            }
                            .frame(width: 10, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .softScroll()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
        )
    }
    
    private func colorForMinutes(_ mins: Int) -> Color {
        switch FocusStats.intensityLevel(minutes: mins) {
        case 0:
            return colorScheme == .light ? Color(hex: "#EBEDF0") : Color.white.opacity(0.08)
        case 1:
            return AppTheme.accent.opacity(0.24)
        case 2:
            return AppTheme.accent.opacity(0.52)
        case 3:
            return AppTheme.accent.opacity(0.78)
        default:
            return AppTheme.accent
        }
    }
}
