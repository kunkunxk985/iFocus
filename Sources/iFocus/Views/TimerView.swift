import SwiftUI
import AppKit

/// Focus stage shell — composition only; chrome lives under Views/Timer/.
/// Extracting subviews does not change layout tokens or visual hierarchy.
struct TimerView: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.windowLayout) private var stageLayout
    @EnvironmentObject var viewState: ContentViewState

    @State private var clockVersion: UInt = 0
    @State private var showResetConfirm = false
    @State private var showFocusModeHint = false
    @State private var celebratePulse = false
    @State private var ringBreath = false
    @State private var playInvite = false
    @AppStorage("timerImmersiveMode") private var immersiveMode = false

    private var modeColor: Color { timerStore.mode.accent }
    private var density: UIDensity { settings.uiDensity }

    private var progress: Double {
        _ = clockVersion
        return timerStore.progress
    }

    private var displayTime: String {
        _ = clockVersion
        return timerStore.timeString
    }

    private var modeTitle: String {
        switch timerStore.mode {
        case .work: return timerStore.isRunning ? "专注中" : "专注"
        case .shortBreak: return timerStore.isRunning ? "短休息中" : "短休息"
        case .longBreak: return timerStore.isRunning ? "长休息中" : "长休息"
        }
    }

    private var statusLabel: String {
        if timerStore.isRunning { return "进行中" }
        if timerStore.isSessionInProgress { return "已暂停" }
        return "待开始"
    }

    private var goalProgress: Double {
        guard settings.dailyGoal > 0 else { return 0 }
        return min(1, Double(timerStore.completedPomodoros) / Double(settings.dailyGoal))
    }

    var body: some View {
        GeometryReader { geo in
            let layout = WindowLayoutMetrics(
                width: max(geo.size.width, stageLayout.width * 0.78),
                height: max(geo.size.height, stageLayout.height * 0.96),
                densityScale: density.scale
            )
            let ringSize = TimerLayoutMath.ringSize(
                layout: layout,
                stageWidth: geo.size.width,
                stageHeight: geo.size.height,
                immersive: immersiveMode
            )

            ZStack {
                ambientBackground

                VStack(spacing: layout.sectionSpacing) {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                immersiveMode.toggle()
                            }
                        } label: {
                            Label(
                                immersiveMode ? "退出沉浸" : "沉浸模式",
                                systemImage: immersiveMode
                                    ? "arrow.down.right.and.arrow.up.left"
                                    : "arrow.up.left.and.arrow.down.right"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(AppTheme.cardBackground(for: colorScheme).opacity(0.75))
                                    .overlay(Capsule().stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1))
                            )
                        }
                        .buttonStyle(SoftScaleButtonStyle())
                        .help(immersiveMode ? "显示任务与模式" : "只保留环与控制")
                    }
                    .padding(.top, layout.stageTopChrome)

                    if !immersiveMode {
                        TimerTopMeta(
                            layout: layout,
                            modeColor: modeColor,
                            statusLabel: statusLabel,
                            goalProgress: goalProgress,
                            celebratePulse: $celebratePulse,
                            onDecorativeMotionChange: syncAmbientMotion
                        )

                        TimerRhythmStrip(layout: layout, modeColor: modeColor)
                            .transition(.opacity)

                        TimerTaskFocusBlock(layout: layout, modeColor: modeColor)
                            .frame(maxWidth: min(layout.taskBlockMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        TimerImmersiveStatusPill(modeColor: modeColor, statusLabel: statusLabel)
                    }

                    Spacer(minLength: max(2, layout.sectionSpacing * 0.35))

                    TimerRingView(
                        size: ringSize,
                        progress: progress,
                        displayTime: displayTime,
                        modeTitle: modeTitle,
                        modeColor: modeColor,
                        isRunning: timerStore.isRunning,
                        decorativeMotion: settings.decorativeMotionEnabled,
                        ringBreath: ringBreath
                    )
                    .scaleEffect(
                        settings.decorativeMotionEnabled && celebratePulse
                        ? 1.04
                        : (settings.decorativeMotionEnabled && timerStore.isRunning && ringBreath ? 1.015 : 1)
                    )
                    .animation(
                        settings.decorativeMotionEnabled ? .easeOut(duration: 0.35) : .linear(duration: 0),
                        value: celebratePulse
                    )
                    .animation(
                        settings.decorativeMotionEnabled && timerStore.isRunning
                        ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                        value: ringBreath
                    )

                    Spacer(minLength: max(2, layout.sectionSpacing * 0.35))

                    if !immersiveMode {
                        TimerModeSwitcher(layout: layout)
                            .frame(maxWidth: min(layout.modeSwitcherMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    TimerControlsBar(
                        layout: layout,
                        modeColor: modeColor,
                        playInvite: playInvite,
                        showResetConfirm: $showResetConfirm,
                        onPlayToggle: requestStartOrToggle
                    )

                    if !immersiveMode, layout.showSessionHint {
                        TimerSessionHint()
                            .padding(.bottom, TimerLayoutMath.lerp(10, 18, layout.eased))
                            .transition(.opacity)
                    } else {
                        Color.clear.frame(height: TimerLayoutMath.lerp(8, 16, layout.eased))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, layout.horizontalPadding)
                .animation(.easeInOut(duration: 0.22), value: immersiveMode)
                .animation(.easeInOut(duration: 0.18), value: layout.scale)
                .animation(.easeInOut(duration: 0.18), value: ringSize)
            }
            .frame(width: layout.width, height: layout.height)
        }
        .ignoresSafeArea()
        .onReceive(timerStore.clockTick) { _ in
            clockVersion &+= 1
        }
        .onAppear {
            clockVersion &+= 1
            syncAmbientMotion()
        }
        .onChange(of: timerStore.isRunning) { _ in
            syncAmbientMotion()
        }
        .confirmationDialog(
            "开始专注",
            isPresented: $showFocusModeHint,
            titleVisibility: .visible
        ) {
            Button("直接开始") { timerStore.toggle() }
            Button("打开系统专注设置…") {
                openSystemFocusSettings()
                timerStore.toggle()
            }
            Button("不再提示并开始") {
                settings.showFocusModeHintOnStart = false
                timerStore.toggle()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("建议在系统设置中开启专注模式，减少通知打扰。iFocus 无法代替系统一键开关勿扰。")
        }
    }

    private var ambientBackground: some View {
        let quiet = !settings.decorativeMotionEnabled
        return ZStack {
            AppTheme.contentBackground(for: colorScheme)
            RadialGradient(
                colors: [
                    modeColor.opacity(quiet
                                      ? (colorScheme == .light ? 0.05 : 0.08)
                                      : (colorScheme == .light ? 0.12 : 0.16)),
                    modeColor.opacity(quiet ? 0.02 : 0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 40,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: quiet ? 0.2 : 0.4), value: timerStore.mode)
    }

    private func requestStartOrToggle() {
        let willStartWork = !timerStore.isRunning
            && !timerStore.isSessionInProgress
            && timerStore.mode == .work
            && settings.showFocusModeHintOnStart
        if willStartWork {
            showFocusModeHint = true
        } else {
            timerStore.toggle()
        }
    }

    /// Keep ring-breath / play-invite motion identical to pre-extract TimerView.
    private func syncAmbientMotion() {
        guard settings.decorativeMotionEnabled else {
            ringBreath = false
            playInvite = false
            return
        }
        if timerStore.isRunning {
            ringBreath = false
            playInvite = false
            DispatchQueue.main.async {
                ringBreath = true
            }
        } else {
            ringBreath = false
            playInvite = false
            if !timerStore.isSessionInProgress {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        playInvite = true
                    }
                }
            }
        }
    }

    private func openSystemFocusSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Focus-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
