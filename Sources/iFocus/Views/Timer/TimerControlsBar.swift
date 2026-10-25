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
                    .foregroundColor(selected ? .white : AppTheme.secondaryText(for: colorScheme))
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
                    }
                }
                .disabled(timerStore.isRunning)
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(colorScheme == .light ? 0.85 : 0.55))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .light ? 0.025 : 0.08),
            radius: 6,
            y: 2
        )
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
        case .work: return settings.countUpWork ? "正计时" : "\(settings.workMinutes)′"
        case .shortBreak: return "\(settings.shortBreakMinutes)′"
        case .longBreak: return "\(settings.longBreakMinutes)′"
        }
    }
}

struct TimerControlsBar: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    @Binding var showResetConfirm: Bool
    var onPlayToggle: () -> Void

    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    private var playHelp: String {
        if timerStore.isRunning { return "暂停 (空格)" }
        if timerStore.isSessionInProgress { return "继续 (空格)" }
        return "开始 (空格)"
    }

    var body: some View {
        let main = layout.controlMainSize
        let side = layout.controlSideSize
        let showLabels = layout.showControlLabels

        return HStack(spacing: layout.controlSpacing) {
            // MARK: - Skip Button (Embossed circular control)
            // In a count-up focus this control ends the segment and logs it.
            EmbossedControlButton(
                systemName: timerStore.finishesOnSkip ? "checkmark" : "forward.end.fill",
                title: timerStore.finishesOnSkip ? "完成" : "跳过",
                size: side,
                showTitle: showLabels,
                tint: AppTheme.secondaryText(for: colorScheme).opacity(timerStore.canSkipSegment ? 1 : 0.35),
                disabled: !timerStore.canSkipSegment
            ) {
                AppHaptics.buttonClick()
                timerStore.skipToNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .help(
                timerStore.finishesOnSkip
                    ? "完成并记录 (⌘→)"
                    : (timerStore.canSkipSegment ? "立即跳过当前段 (⌘→)" : "严格模式：不可跳过")
            )

            // MARK: - Main Play/Pause Button (Floating Dual-Layer Micro-Structure)
            Button(action: {
                AppHaptics.buttonClick()
                onPlayToggle()
            }) {
                ZStack {
                    Circle()
                        .fill(modeColor)
                        .frame(width: main, height: main)
                        .shadow(
                            color: modeColor.opacity(colorScheme == .light ? 0.32 : 0.44),
                            radius: timerStore.isRunning ? 14 : 10,
                            y: timerStore.isRunning ? 6 : 4
                        )

                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: main * 0.35, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: timerStore.isRunning ? 0 : 2)
                }
            }
            .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.94, animation: AppTheme.springInteractive))
            .keyboardShortcut(.space, modifiers: [])
            .help(playHelp)
            .accessibilityLabel(playHelp)

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
            .timerResetConfirmation(isPresented: $showResetConfirm, timerStore: timerStore)
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

extension View {
    /// Confirms a mid-session reset. During focus it also offers 「结束并记录」 so
    /// stopping early can keep the time already spent instead of discarding it.
    /// The clock is not `@Published`, so minutes are read inside the action closures
    /// (evaluated when the dialog opens) rather than captured with the view body.
    func timerResetConfirmation(isPresented: Binding<Bool>, timerStore: TimerStore) -> some View {
        confirmationDialog(
            timerStore.mode == .work ? "结束这段专注？" : "重置当前计时？",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let minutes = timerStore.earlyFinishMinutes {
                Button("结束并记录 \(minutes) 分钟") {
                    AppHaptics.buttonClick()
                    timerStore.finishEarlyAndLog()
                }
            }
            Button(timerStore.mode == .work ? "重置（不记录）" : "重置", role: .destructive) {
                AppHaptics.buttonClick()
                timerStore.celebrationMessage = nil
                timerStore.reset()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                timerStore.earlyFinishMinutes == nil
                    ? "进行中的时段不会记入专注记录。"
                    : "可以把已经专注的时间记下来，也可以直接丢弃。"
            )
        }
    }
}

/// Flat side control. The play button carries the colour; these stay quiet.
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
                    Circle()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                        .frame(width: size, height: size)
                        .overlay(
                            Circle()
                                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .light ? 0.025 : 0.10),
                            radius: isHovering ? 6 : 3,
                            y: isHovering ? 2 : 1
                        )

                    Image(systemName: systemName)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundColor(tint.opacity(disabled ? 0.35 : (isHovering ? 1 : 0.8)))
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
        .accessibilityLabel(title)
        .disabled(disabled)
    }
}
