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
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 2.5)
                            .frame(width: 24, height: 24)
                        Circle()
                            .trim(from: 0, to: max(0.02, liveProgress))
                            .stroke(
                                timerStore.mode.accent,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 24, height: 24)
                        PulseDot(
                            color: timerStore.mode.accent,
                            isActive: timerStore.isRunning,
                            size: 6.5,
                            allowsPulse: settings.decorativeMotionEnabled
                        )
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(primaryTitle)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                            .lineLimit(1)
                        Text(timerStore.isRunning ? "\(timerStore.mode.rawValue)进行中 · 点击返回专注钟" : "\(timerStore.mode.rawValue)已暂停 · 点击返回专注钟")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(liveTimeString)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .tracking(TypeScale.trackingDisplay)
                .monospacedDigit()
                .foregroundColor(timerStore.mode.accent)
                .frame(minWidth: 56, alignment: .trailing)

            HStack(spacing: 6) {
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
                                        timerStore.mode.accent.opacity(0.90)
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
                                lineWidth: 0.75
                            )
                            .frame(width: 32, height: 32)

                        Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: timerStore.isRunning ? 0 : 1)
                    }
                }
                .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.92, animation: AppTheme.springInteractive))
                .help(timerStore.isRunning ? "暂停 (空格)" : "继续 (空格)")
                .accessibilityLabel(timerStore.isRunning ? "暂停" : "继续")

                if timerStore.canSkipSegment {
                    Button {
                        AppHaptics.buttonClick()
                        timerStore.skipToNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(AppTheme.elevatedBackground(for: colorScheme))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.92, animation: AppTheme.springInteractive))
                    .help("跳过此段")
                    .accessibilityLabel("跳过此段")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 460)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.78 : 0.48))
        )
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    timerStore.mode.accent.opacity(timerStore.isRunning ? 0.30 : 0.16),
                    lineWidth: 0.75
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

    private var liveProgress: Double {
        _ = clockVersion
        return timerStore.progress
    }

    private var primaryTitle: String {
        if timerStore.mode == .work {
            return taskStore.activeTask?.title ?? "自由专注"
        }
        return timerStore.mode.rawValue
    }
}
