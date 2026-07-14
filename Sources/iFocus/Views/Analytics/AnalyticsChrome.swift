import SwiftUI

// MARK: - Shared chrome

struct AnalyticsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let value: String
    let label: String
    let tint: Color
    var emphasizeValue: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        emphasizeValue
                        ? tint.opacity(0.12)
                        : AppTheme.elevatedBackground(for: colorScheme)
                    )
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(
                        emphasizeValue
                        ? AppTheme.accent
                        : AppTheme.primaryText(for: colorScheme)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

struct ProgressRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer()
            Text(valueText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
    }
}

struct TipRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.accent.opacity(0.85))
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String

    var body: some View {
        AppEmptyState(systemImage: systemImage, title: title, compact: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

