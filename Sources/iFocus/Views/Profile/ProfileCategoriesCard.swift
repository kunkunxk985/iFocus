import SwiftUI
import iFocusCore

struct ProfileCategoryStat: Identifiable {
    let id = UUID()
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
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("专注时间分配")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                if isEmpty {
                    Text("暂无专注记录")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else {
                    ForEach(stats.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(item.category.rawValue, systemImage: item.category.icon)
                                    .font(.subheadline.bold())
                                    .foregroundColor(item.category.color)
                                Spacer()
                                Text(FocusStats.formatTotalMinutes(item.minutes))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                            }
                            
                            GeometryReader { geo in
                                let pct = CGFloat(item.minutes) / CGFloat(totalMinutes)
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.separatorLow(for: colorScheme))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(item.category.color)
                                        .frame(width: max(8, geo.size.width * pct), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minHeight: 200, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
        )
    }
}
