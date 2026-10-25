import SwiftUI
import iFocusCore

struct ProfileHeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let grid: [[FocusStats.ContributionCell]]
    let monthLabels: [Int: String]
    @State private var hoveredCell: FocusStats.ContributionCell? = nil
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }
    
    private var activeDaysCount: Int {
        grid.flatMap { $0 }.filter { $0.minutes > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                            .frame(width: 22, height: 22)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                    }
                    Text("专注热力图")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                }

                Spacer()

                if let cell = hoveredCell {
                    Text("\(dateFormatter.string(from: cell.date)) · \(cell.minutes) 分钟")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.16))
                        )
                        .transition(.opacity)
                } else {
                    Text("累计打卡 \(activeDaysCount) 天")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 3.5) {
                        ForEach(0..<grid.count, id: \.self) { colIndex in
                            VStack(spacing: 3.5) {
                                ForEach(Array(grid[colIndex].enumerated()), id: \.offset) { _, cell in
                                    let isHovered = hoveredCell?.date == cell.date
                                    let level = FocusStats.intensityLevel(minutes: cell.minutes)
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(colorForLevel(level))
                                        .frame(width: 10.5, height: 10.5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                                .strokeBorder(
                                                    isHovered
                                                    ? AppTheme.primaryText(for: colorScheme).opacity(0.8)
                                                    : (level == 0 ? (colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.05)) : Color.clear),
                                                    lineWidth: isHovered ? 1 : 0.5
                                                )
                                        )
                                        .scaleEffect(isHovered ? 1.25 : 1.0)
                                        .animation(AppTheme.springInteractive, value: isHovered)
                                        .zIndex(isHovered ? 1 : 0)
                                        .onHover { h in
                                            withAnimation(AppTheme.springInteractive) {
                                                hoveredCell = h ? cell : nil
                                            }
                                        }
                                        .help("\(dateFormatter.string(from: cell.date)): 专注 \(cell.minutes) 分钟")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 3.5) {
                        ForEach(0..<grid.count, id: \.self) { c in
                            Group {
                                if let label = monthLabels[c] {
                                    Text(label)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.8))
                                } else {
                                    Text("")
                                        .font(.system(size: 9))
                                }
                            }
                            .frame(width: 10.5, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .softScroll()

            // Refined bottom legend
            HStack(spacing: 4) {
                Spacer()
                Text("少")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                ForEach(0...4, id: \.self) { lvl in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colorForLevel(lvl))
                        .frame(width: 9, height: 9)
                }
                Text("多")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0:
            return colorScheme == .light ? Color.black.opacity(0.045) : Color.white.opacity(0.06)
        case 1:
            return AppTheme.accent.opacity(colorScheme == .light ? 0.28 : 0.32)
        case 2:
            return AppTheme.accent.opacity(colorScheme == .light ? 0.52 : 0.58)
        case 3:
            return AppTheme.accent.opacity(colorScheme == .light ? 0.76 : 0.82)
        default:
            return AppTheme.accent
        }
    }
}
