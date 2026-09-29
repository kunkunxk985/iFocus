import SwiftUI

/// Floating timer pill — Things 3 / Apple Notes refined craftsmanship.
/// Renders with translucent material (.ultraThinMaterial), continuous squircle corners,
/// subtle specular inner highlight stroke, and multi-layer floating shadow.
/// Owns its own clock subscription via timerStore.clockTick so task list and sheets stay calm.
struct FloatingFocusPill: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0

    var body: some View {
        HStack(spacing: 14) {
            Button {
                viewState.selectedScreen = .timer
            } label: {
                HStack(spacing: 10) {
                    PulseDot(
                        color: timerStore.mode.accent,
                        isActive: timerStore.isRunning,
                        size: 8,
                        allowsPulse: settings.decorativeMotionEnabled
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                            .lineLimit(1)
                        Text(timerStore.isRunning ? "进行中" : "已暂停")
                            .font(TypeScale.micro)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Text(liveTimeString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(TypeScale.trackingDisplay)
                .monospacedDigit()
                .foregroundColor(timerStore.mode.accent)
                .frame(minWidth: 58, alignment: .center)

            Button(action: {
                AppHaptics.buttonClick()
                timerStore.toggle()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    timerStore.mode.accent.opacity(1.0),
                                    timerStore.mode.accent.opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(
                            color: settings.decorativeMotionEnabled && timerStore.isRunning
                                ? timerStore.mode.accent.opacity(0.35)
                                : .clear,
                            radius: 6,
                            y: 2
                        )

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.40), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: timerStore.isRunning ? 0 : 1)
                }
            }
            .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.92, animation: AppTheme.springInteractive))
            .help(timerStore.isRunning ? "暂停 (空格)" : "继续 (空格)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.82 : 0.45))
        )
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    timerStore.mode.accent.opacity(timerStore.isRunning ? 0.28 : 0.12),
                    lineWidth: 1
                )
        )
        .multiLayerShadow(elevation: .floating, colorScheme: colorScheme)
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .onReceive(timerStore.clockTick) { _ in
            clockVersion &+= 1
        }
    }

    private var liveTimeString: String {
        _ = clockVersion
        return timerStore.timeString
    }

    private var primaryTitle: String {
        if timerStore.mode == .work {
            return taskStore.activeTask?.title ?? "自由专注"
        }
        return timerStore.mode.rawValue
    }
}
