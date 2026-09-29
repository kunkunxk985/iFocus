import SwiftUI

// MARK: - Shared chrome

struct AnalyticsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                        .frame(width: 22, height: 22)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Spacer()
            }
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
    @State private var isHovering = false

    var body: some View {
        let shape = AppTheme.squircle(radius: AppTheme.cornerRadiusCard)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                    .lineLimit(1)
                Spacer()
                ZStack {
                    Circle()
                        .fill(tint.opacity(colorScheme == .light ? 0.10 : 0.18))
                        .frame(width: 22, height: 22)
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(tint)
                }
            }

            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(
                    emphasizeValue
                    ? tint
                    : AppTheme.primaryText(for: colorScheme)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape
                    .fill(AppTheme.cardBackground(for: colorScheme))

                // Subtle micro-gradient tint for depth
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(colorScheme == .light ? 0.06 : 0.09),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                shape
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)

                shape
                    .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
            }
            .multiLayerShadow(elevation: isHovering ? .elevated : .card, colorScheme: colorScheme)
        }
        .onHover { h in
            withAnimation(AppTheme.springInteractive) {
                isHovering = h
            }
        }
        .accessibilityLabel("\(label)，\(value)")
        .accessibilityValue(systemImage)
    }
}

struct ProgressRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 0)
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer()
            Text(valueText)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
    }
}

struct TipRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20))
                    .frame(width: 20, height: 20)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.accent)
            }
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

