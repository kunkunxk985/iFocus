import SwiftUI

/// Single source of truth for analytics card labels + bindings.
/// Used by Settings → 统计 and the in-page 「自定义」 popover.
enum AnalyticsDisplayCard: String, CaseIterable, Identifiable {
    case insight
    case kpi
    case goal
    case trend
    case timeline
    case hours
    case category
    case taskBinding
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insight: return "一句话洞察"
        case .kpi: return "今日概览"
        case .goal: return "今日目标"
        case .trend: return "趋势图"
        case .timeline: return "今日时间线"
        case .hours: return "时段分布"
        case .category: return "分类 Top"
        case .taskBinding: return "任务绑定"
        case .recent: return "最近记录"
        }
    }

    var subtitle: String {
        switch self {
        case .insight: return "顶部的智能摘要"
        case .kpi: return "番茄 / 时长 / 连续天数"
        case .goal: return "目标完成环"
        case .trend: return "范围内每日专注趋势"
        case .timeline: return "仅「今日」范围有效"
        case .hours: return "仅「今日」范围有效"
        case .category: return "按分类统计专注"
        case .taskBinding: return "自由专注占比"
        case .recent: return "近期专注会话列表"
        }
    }

    /// Core cards stay on in the quiet default.
    var isCore: Bool {
        switch self {
        case .insight, .kpi, .goal, .trend: return true
        case .timeline, .hours, .category, .taskBinding, .recent: return false
        }
    }

    static var coreCards: [AnalyticsDisplayCard] { allCases.filter(\.isCore) }
    static var detailCards: [AnalyticsDisplayCard] { allCases.filter { !$0.isCore } }

    func binding(in settings: SettingsStore) -> Binding<Bool> {
        switch self {
        case .insight: return Binding(get: { settings.analyticsShowInsight }, set: { settings.analyticsShowInsight = $0 })
        case .kpi: return Binding(get: { settings.analyticsShowKPI }, set: { settings.analyticsShowKPI = $0 })
        case .goal: return Binding(get: { settings.analyticsShowGoal }, set: { settings.analyticsShowGoal = $0 })
        case .trend: return Binding(get: { settings.analyticsShowTrend }, set: { settings.analyticsShowTrend = $0 })
        case .timeline: return Binding(get: { settings.analyticsShowTimeline }, set: { settings.analyticsShowTimeline = $0 })
        case .hours: return Binding(get: { settings.analyticsShowHours }, set: { settings.analyticsShowHours = $0 })
        case .category: return Binding(get: { settings.analyticsShowCategory }, set: { settings.analyticsShowCategory = $0 })
        case .taskBinding: return Binding(get: { settings.analyticsShowTaskBinding }, set: { settings.analyticsShowTaskBinding = $0 })
        case .recent: return Binding(get: { settings.analyticsShowRecent }, set: { settings.analyticsShowRecent = $0 })
        }
    }
}

/// Compact or full editor for which analytics cards are visible.
struct AnalyticsCardVisibilityEditor: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    /// `compact` = popover on analytics page; `full` = Settings panel body (no outer cards).
    var style: Style = .full

    enum Style {
        case compact
        case full
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 12 : 14) {
            if style == .compact {
                Text("自定义展示")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text("开关即时生效。默认安静布局，需要时再打开细节。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            presetRow

            sectionHeader("核心")
            cardGroup(AnalyticsDisplayCard.coreCards)

            sectionHeader("细节")
            cardGroup(AnalyticsDisplayCard.detailCards)
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            presetChip(
                title: "安静",
                subtitle: "核心开",
                isActive: settings.isAnalyticsQuietDefault,
                action: { settings.resetAnalyticsCardVisibilityToQuietDefaults() }
            )
            presetChip(
                title: "完整",
                subtitle: "全部开",
                isActive: settings.isAnalyticsFullLayout,
                action: { settings.enableAllAnalyticsCards() }
            )
            Spacer(minLength: 0)
        }
    }

    private func presetChip(title: String, subtitle: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundColor(isActive ? .white : AppTheme.primaryText(for: colorScheme).opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AppTheme.accent : AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActive ? Color.clear : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help(title == "安静" ? "恢复安静默认：核心开、细节关" : "打开全部卡片")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            .padding(.top, style == .compact ? 2 : 0)
    }

    private func cardGroup(_ cards: [AnalyticsDisplayCard]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    Divider().opacity(0.45)
                }
                toggleRow(card)
            }
        }
        .padding(.horizontal, style == .compact ? 10 : 0)
        .padding(.vertical, style == .compact ? 4 : 0)
        .background {
            if style == .compact {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(0.55))
            }
        }
    }

    private func toggleRow(_ card: AnalyticsDisplayCard) -> some View {
        Toggle(isOn: card.binding(in: settings)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(card.subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, style == .compact ? 8 : 0)
    }
}
