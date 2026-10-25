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

struct EmptyStateView: View {
    let systemImage: String
    let title: String

    var body: some View {
        AppEmptyState(systemImage: systemImage, title: title, compact: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Compact stat ring for analytics (Pomodoro Todo–style progress at a glance).
struct AnalyticsProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let tint: Color
    let title: String
    let subtitle: String
    var celebrate: Bool = false
    var allowPulse: Bool = false

    @State private var breathe = false

    private var clamped: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if celebrate {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    tint.opacity(colorScheme == .light ? 0.22 : 0.32),
                                    tint.opacity(0.04),
                                    .clear
                                ],
                                center: .center,
                                startRadius: size * 0.2,
                                endRadius: size * 0.62
                            )
                        )
                        .frame(width: size * 1.15, height: size * 1.15)
                        .scaleEffect(breathe ? 1.06 : 1.0)
                        .opacity(breathe ? 1.0 : 0.88)
                }

                Circle()
                    .stroke(
                        colorScheme == .light
                        ? AppTheme.separatorLow(for: colorScheme).opacity(0.9)
                        : Color.white.opacity(0.08),
                        lineWidth: lineWidth
                    )

                Circle()
                    .trim(from: 0, to: max(clamped, clamped > 0 ? 0.02 : 0))
                    .stroke(
                        AngularGradient(
                            colors: [
                                tint.opacity(0.75),
                                tint,
                                tint.opacity(0.9)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(celebrate ? 0.45 : 0.25), radius: celebrate ? 6 : 3)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: max(10, size * 0.11), weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
                .frame(width: size * 0.72)
            }
            .frame(width: size, height: size)
            .scaleEffect(celebrate && breathe ? 1.02 : 1.0)
            .animation(AppTheme.springInteractive, value: clamped)
        }
        .frame(maxWidth: .infinity)
        .onAppear { updateBreathing(active: celebrate && allowPulse) }
        .onChange(of: celebrate) { _ in
            updateBreathing(active: celebrate && allowPulse)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subtitle)，\(title)")
    }

    private func updateBreathing(active: Bool) {
        guard active else {
            breathe = false
            return
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }
}

