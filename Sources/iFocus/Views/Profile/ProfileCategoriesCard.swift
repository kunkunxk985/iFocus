import SwiftUI
import iFocusCore

struct ProfileCategoryStat: Identifiable {
    var id: String { category.id }
    let category: TaskCategory
    let minutes: Int
    let count: Int
}

struct ProfileCategoriesCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let stats: [ProfileCategoryStat]
    let isEmpty: Bool
    
    var body: some View {
        let totalMinutes = max(1, stats.reduce(0) { $0 + $1.minutes })
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                        .frame(width: 22, height: 22)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
                Text("专注时间分配")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
            }
            .padding(.bottom, 2)
            
            VStack(spacing: 12) {
                if isEmpty {
                    Text("暂无专注记录")
                        .font(.system(size: 12.5))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else {
                    ForEach(Array(stats.prefix(4).enumerated()), id: \.element.id) { index, item in
                        let pct = CGFloat(item.minutes) / CGFloat(totalMinutes)
                        let pctInt = Int((Double(item.minutes) / Double(totalMinutes) * 100).rounded())
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center, spacing: 10) {
                                if index == 0, pctInt > 0 {
                                    AnalyticsProgressRing(
                                        progress: Double(pct),
                                        size: 44,
                                        lineWidth: 5,
                                        tint: item.category.color,
                                        title: "\(pctInt)%",
                                        subtitle: "占比"
                                    )
                                    .frame(width: 48)
                                }
                                Label(item.category.name, systemImage: item.category.icon)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(item.category.color)

                                Text("\(pctInt)%")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(item.category.color)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(
                                        Capsule()
                                            .fill(item.category.color.opacity(colorScheme == .light ? 0.10 : 0.18))
                                    )

                                Spacer()

                                Text(FocusStats.formatTotalMinutes(item.minutes))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.separatorLow(for: colorScheme))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [item.category.color, item.category.color.opacity(0.85)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: item.category.color.opacity(0.3), radius: 2, x: 0, y: 0)
                                        .frame(width: max(6, geo.size.width * pct), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(minHeight: 200, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}
