import SwiftUI

struct TimerRingView: View {
    let size: CGFloat
    let progress: Double
    let displayTime: String
    let modeTitle: String
    let modeColor: Color
    let isRunning: Bool
    let decorativeMotion: Bool
    let ringBreath: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let line = max(12, size * 0.06)
        let glowBoost = isRunning ? (decorativeMotion ? 1.0 : 0.7) : 0.45

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity((colorScheme == .light ? 0.10 : 0.16) * glowBoost),
                            modeColor.opacity((colorScheme == .light ? 0.03 : 0.06) * glowBoost),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.18,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.18, height: size * 1.18)
                .scaleEffect(decorativeMotion && isRunning && ringBreath ? 1.04 : 1)

            Circle()
                .stroke(modeColor.opacity(colorScheme == .light ? 0.10 : 0.14), lineWidth: line)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0.001), 1)))
                .stroke(
                    decorativeMotion
                    ? AnyShapeStyle(AngularGradient(
                        colors: [modeColor.opacity(0.55), modeColor, modeColor.opacity(0.85)],
                        center: .center
                    ))
                    : AnyShapeStyle(modeColor),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)
                .shadow(
                    color: modeColor.opacity(isRunning ? (decorativeMotion ? 0.28 : 0.10) : 0.06),
                    radius: isRunning ? (decorativeMotion ? 12 : 5) : 3,
                    y: 0
                )

            VStack(spacing: 6) {
                Text(displayTime)
                    .font(.system(size: max(48, size * 0.26), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(modeTitle)
                    .font(.system(size: max(12, size * 0.048), weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
        .frame(width: size * 1.18, height: size * 1.18)
    }
}
