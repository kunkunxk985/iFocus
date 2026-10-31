import SwiftUI
import iFocusCore

struct ProfileHeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let grid: [[FocusStats.ContributionCell]]
    let monthLabels: [Int: String]
    @State private var hoveredCell: FocusStats.ContributionCell? = nil
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }
    
    private var activeDaysCount: Int {
        grid.flatMap { $0 }.filter { $0.minutes > 0 }.count
    }

    private func tooltipText(for cell: FocusStats.ContributionCell) -> String {
        "\(dateFormatter.string(from: cell.date)) · \(FocusStats.formatTotalMinutes(cell.minutes))"
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
                    Text(tooltipText(for: cell))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.16))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.accent.opacity(colorScheme == .light ? 0.20 : 0.28), lineWidth: 0.8)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
                                    AppTheme.squircle(radius: 2.8)
                                        .fill(colorForLevel(level))
                                        .frame(width: 10.5, height: 10.5)
                                        .overlay(
                                            AppTheme.squircle(radius: 2.8)
                                                .strokeBorder(
                                                    isHovered
                                                    ? AppTheme.primaryText(for: colorScheme).opacity(0.85)
                                                    : (level == 0 ? AppTheme.separatorLow(for: colorScheme).opacity(0.35) : Color.clear),
                                                    lineWidth: isHovered ? 1.2 : 0.5
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
                                        .help(tooltipText(for: cell))
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
                                        .fixedSize()
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
                    AppTheme.squircle(radius: 2.0)
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
    
    static func opacity(for level: Int) -> Double {
        switch level {
        case 0: return 0.045
        case 1: return 0.25
        case 2: return 0.50
        case 3: return 0.75
        default: return 1.00
        }
    }
    
    static func colorForLevel(
        _ level: Int,
        scheme: ColorScheme = .light,
        accent: Color = AppTheme.accent
    ) -> Color {
        if level <= 0 {
            return scheme == .light ? Color.black.opacity(opacity(for: 0)) : Color.white.opacity(0.06)
        }
        return accent.opacity(opacity(for: level))
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        Self.colorForLevel(level, scheme: colorScheme, accent: AppTheme.accent)
    }
}
