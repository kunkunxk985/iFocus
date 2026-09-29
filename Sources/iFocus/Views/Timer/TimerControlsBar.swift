import SwiftUI

/// Mode chips + play/skip/reset + session keyboard hint (below the ring).
/// Tactile pill mode switcher with smooth sliding spring active indicator,
/// and floating dual-layer embossed control buttons.
struct TimerModeSwitcher: View {
    let layout: WindowLayoutMetrics
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var modeSwitcherNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TimerMode.allCases) { mode in
                let selected = timerStore.mode == mode
                let modeAccentColor = accent(for: mode)

                Button {
                    AppHaptics.modeSwitched()
                    timerStore.requestSetMode(mode)
                } label: {
                    VStack(spacing: 2) {
                        Text(mode.rawValue)
                            .font(.system(size: layout.modeChipFont, weight: selected ? .semibold : .medium))
                        Text(durationLabel(for: mode))
                            .font(.system(size: 10, weight: selected ? .semibold : .regular).monospacedDigit())
                            .opacity(selected ? 0.90 : 0.65)
                    }
                    .foregroundColor(selected ? .white : AppTheme.primaryText(for: colorScheme).opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.modeChipVerticalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.96, animation: AppTheme.springInteractive))
                .background {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(modeAccentColor)
                            .matchedGeometryEffect(id: "activeModeIndicator", in: modeSwitcherNamespace)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.38),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: modeAccentColor.opacity(colorScheme == .light ? 0.28 : 0.40),
                                radius: 8,
                                x: 0,
                                y: 3
                            )
                    }
                }
                .disabled(timerStore.isRunning)
            }
        }
        .padding(3.5)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.72 : 0.40))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
        )
        .multiLayerShadow(elevation: .row, colorScheme: colorScheme)
        .opacity(timerStore.isRunning ? 0.55 : 1)
        .animation(AppTheme.springInteractive, value: timerStore.mode)
    }

    private func accent(for mode: TimerMode) -> Color {
        switch mode {
        case .work:
            // Work mode MUST dynamically track AppTheme.accent via timerStore.mode.accent
            return timerStore.mode == .work ? timerStore.mode.accent : AppTheme.accent
        case .shortBreak:
            return TimerMode.shortBreak.accent
        case .longBreak:
            return TimerMode.longBreak.accent
        }
    }

    private func durationLabel(for mode: TimerMode) -> String {
        switch mode {
        case .work: return "\(settings.workMinutes)′"
        case .shortBreak: return "\(settings.shortBreakMinutes)′"
        case .longBreak: return "\(settings.longBreakMinutes)′"
        }
    }
}

struct TimerControlsBar: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    let playInvite: Bool
    @Binding var showResetConfirm: Bool
    var onPlayToggle: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let main = layout.controlMainSize
        let side = layout.controlSideSize
        let showLabels = layout.showControlLabels

        return HStack(spacing: layout.controlSpacing) {
            // MARK: - Skip Button (Embossed circular control)
            EmbossedControlButton(
                systemName: "forward.end.fill",
                title: "跳过",
                size: side,
                showTitle: showLabels,
                tint: AppTheme.secondaryText(for: colorScheme).opacity(timerStore.canSkipSegment ? 1 : 0.35),
                disabled: !timerStore.canSkipSegment
            ) {
                AppHaptics.buttonClick()
                timerStore.skipToNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .help(timerStore.canSkipSegment ? "立即跳过当前段 (⌘→)" : "严格模式：不可跳过")

            // MARK: - Main Play/Pause Button (Floating Dual-Layer Micro-Structure)
            Button(action: {
                AppHaptics.buttonClick()
                onPlayToggle()
            }) {
                ZStack {
                    if settings.decorativeMotionEnabled, !timerStore.isRunning {
                        Circle()
                            .stroke(modeColor.opacity(0.24), lineWidth: 1.5)
                            .frame(width: main + 14, height: main + 14)
                            .scaleEffect(playInvite ? 1.08 : 0.96)
                            .opacity(playInvite ? 0.20 : 0.48)
                    }

                    // Base floating layer with ambient & contact shadows
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    modeColor.opacity(1.0),
                                    modeColor.opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: main, height: main)
                        .shadow(
                            color: modeColor.opacity(settings.decorativeMotionEnabled ? (colorScheme == .light ? 0.30 : 0.45) : 0.14),
                            radius: settings.decorativeMotionEnabled ? 16 : 8,
                            x: 0,
                            y: 6
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .light ? 0.12 : 0.35),
                            radius: 3.5,
                            x: 0,
                            y: 2
                        )

                    // Specular top highlight bevel
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.42),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: main, height: main)

                    // Outer hairline rim
                    Circle()
                        .strokeBorder(Color.white.opacity(colorScheme == .light ? 0.20 : 0.10), lineWidth: 0.75)
                        .frame(width: main, height: main)

                    // Center Play/Pause Glyph
                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: main * 0.35, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: timerStore.isRunning ? 0 : 2)
                        .shadow(color: Color.black.opacity(0.25), radius: 1.5, y: 1)
                }
            }
            .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.94, animation: AppTheme.springInteractive))
            .keyboardShortcut(.space, modifiers: [])
            .help(timerStore.isRunning ? "暂停 (空格)" : "开始 (空格)")

            // MARK: - Reset Button (Embossed circular control)
            EmbossedControlButton(
                systemName: "arrow.clockwise",
                title: "重置",
                size: side,
                showTitle: showLabels,
                tint: AppTheme.secondaryText(for: colorScheme),
                disabled: false
            ) {
                requestReset()
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("重置 (⌘R)")
            .confirmationDialog(
                "重置当前计时？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("重置", role: .destructive) {
                    AppHaptics.buttonClick()
                    timerStore.celebrationMessage = nil
                    timerStore.reset()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("进行中的时段不会记入专注记录。")
            }
        }
    }

    private func requestReset() {
        AppHaptics.buttonClick()
        if timerStore.isSessionInProgress || timerStore.isRunning {
            showResetConfirm = true
        } else {
            timerStore.celebrationMessage = nil
            timerStore.reset()
        }
    }
}

/// Embossed circular side control (Skip/Reset) with specular border,
/// ambient drop shadow, and spring hover feedback.
struct EmbossedControlButton: View {
    let systemName: String
    let title: String
    let size: CGFloat
    let showTitle: Bool
    let tint: Color
    var disabled: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    // Embossed base plate
                    Circle()
                        .fill(
                            AppTheme.cardBackground(for: colorScheme)
                                .opacity(colorScheme == .light ? (isHovering ? 0.95 : 0.82) : (isHovering ? 0.42 : 0.28))
                        )
                        .frame(width: size, height: size)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .light ? 0.05 : 0.25),
                            radius: isHovering ? 5 : 3,
                            x: 0,
                            y: isHovering ? 2.5 : 1.5
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .light ? 0.03 : 0.18),
                            radius: 1,
                            x: 0,
                            y: 0.5
                        )

                    // Outer hairline separator border
                    Circle()
                        .strokeBorder(AppTheme.separator(for: colorScheme), lineWidth: 1)
                        .frame(width: size, height: size)

                    // Specular inner highlight border
                    Circle()
                        .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
                        .frame(width: size, height: size)

                    Image(systemName: systemName)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundColor(tint)
                }
                .scaleEffect(isHovering && !disabled ? 1.04 : 1.0)
                .animation(AppTheme.springSnappy, value: isHovering)

                if showTitle {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(tint)
                }
            }
        }
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.94, animation: AppTheme.springInteractive))
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(disabled)
    }
}

struct TimerSessionHint: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if timerStore.mode == .work {
                if timerStore.isRunning {
                    KeyCap(label: "空格")
                    Text("暂停")
                    if timerStore.canSkipSegment {
                        Text("·").opacity(0.4)
                        KeyCap(label: "⌘→")
                        Text("跳过")
                    } else {
                        Text("·").opacity(0.4)
                        Text("严格模式")
                    }
                } else if let title = taskStore.activeTask?.title, !title.isEmpty {
                    KeyCap(label: "空格")
                    Text("开始 · \(title)")
                        .lineLimit(1)
                } else {
                    KeyCap(label: "空格")
                    Text("自由专注")
                    Text("·").opacity(0.4)
                    Text("上方可选任务")
                }
            } else {
                KeyCap(label: "空格")
                Text(timerStore.isRunning ? "暂停休息" : "开始休息")
                if timerStore.canSkipSegment {
                    Text("·").opacity(0.4)
                    KeyCap(label: "⌘→")
                    Text("跳过")
                }
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        .lineLimit(1)
        .frame(maxWidth: 380)
        .animation(.easeOut(duration: 0.2), value: timerStore.isRunning)
        .animation(.easeOut(duration: 0.2), value: timerStore.mode)
    }
}
