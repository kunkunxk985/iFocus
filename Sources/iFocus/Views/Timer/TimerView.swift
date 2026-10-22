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
    @StateObject private var focusMode = FocusModeController.shared
    @AppStorage("timerImmersiveMode") private var immersiveMode = false

    private var modeColor: Color { timerStore.mode.accent }
    private var density: UIDensity { settings.uiDensity }

    /// Native full-screen focus always presents the immersive stage, even if the
    /// windowed immersive preference is off.
    private var stageImmersive: Bool { immersiveMode || focusMode.isActive }

    private var progress: Double {
        _ = clockVersion
        return timerStore.progress
    }

    private var displayTime: String {
        _ = clockVersion
        return timerStore.timeString
    }

    private var isPaused: Bool {
        !timerStore.isRunning && timerStore.isSessionInProgress
    }

    private var modeTitle: String {
        let base: String
        switch timerStore.mode {
        case .work: base = "专注"
        case .shortBreak: base = "短休息"
        case .longBreak: base = "长休息"
        }
        if isPaused { return "\(base) · 已暂停" }
        return timerStore.isRunning ? "\(base)中" : base
    }

    private func stageControlButton(
        systemName: String,
        help: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help(help)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Shown after a count-up stopped at the cap: the time is logged, one click continues.
    private func capRestartButton(_ cap: TimerStore.CapRestart) -> some View {
        Button {
            timerStore.restartAfterCap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(TimerMode.work.accent)
                Text("已记下 \(TimerStore.countUpCapMinutes / 60) 小时 · 再开一段")
                    .fontWeight(.semibold)
                Text(cap.taskTitle)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(AppTheme.cardBackground(for: colorScheme)))
            .overlay(Capsule().strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help("从 00:00 开始下一段正计时，记在同一个任务上")
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
            let baseRingSize = TimerLayoutMath.ringSize(
                layout: layout,
                stageWidth: geo.size.width,
                stageHeight: geo.size.height,
                immersive: stageImmersive
            )
            // Full-screen focus gives the ring more of the stage than windowed immersive.
            let ringSize = baseRingSize * (focusMode.isActive ? 1.22 : 1)

            ZStack {
                ambientBackground

                VStack(spacing: layout.sectionSpacing) {
                    HStack(spacing: 4) {
                        Spacer()

                        if focusMode.isActive {
                            Button {
                                FocusModeController.shared.exit()
                            } label: {
                                Label("退出专注", systemImage: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.cardBackground(for: colorScheme).opacity(0.82))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(SoftScaleButtonStyle())
                            .help("退出专注模式 (Esc)")
                            .accessibilityLabel("退出专注模式")
                        } else {
                            stageControlButton(
                                systemName: "pip",
                                help: "迷你计时窗",
                                accessibilityLabel: "显示迷你计时窗"
                            ) {
                                NotificationCenter.default.post(name: AppNavigation.toggleMiniTimer, object: nil)
                            }
                            stageControlButton(
                                systemName: "arrow.up.left.and.arrow.down.right",
                                help: "全屏专注模式",
                                accessibilityLabel: "进入全屏专注模式"
                            ) {
                                NotificationCenter.default.post(name: AppNavigation.toggleFocusMode, object: nil)
                            }
                            stageControlButton(
                                systemName: immersiveMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical",
                                help: immersiveMode ? "退出沉浸" : "沉浸模式：只保留环与控制",
                                accessibilityLabel: immersiveMode ? "退出沉浸模式" : "进入沉浸模式"
                            ) {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    immersiveMode.toggle()
                                }
                            }
                        }
                    }
                    .padding(.top, layout.stageTopChrome)

                    if !stageImmersive {
                        TimerTopMeta(
                            layout: layout,
                            modeColor: modeColor,
                            goalProgress: goalProgress,
                            celebratePulse: $celebratePulse,
                            onDecorativeMotionChange: syncAmbientMotion
                        )

                        TimerTaskFocusBlock(layout: layout, modeColor: modeColor)
                            .frame(maxWidth: min(layout.taskBlockMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        TimerImmersiveStatusPill()
                    }

                    Spacer(minLength: 4)

                    TimerRingView(
                        size: ringSize,
                        progress: progress,
                        displayTime: displayTime,
                        modeTitle: modeTitle,
                        modeColor: modeColor,
                        isRunning: timerStore.isRunning,
                        decorativeMotion: settings.decorativeMotionEnabled,
                        ringBreath: ringBreath,
                        isWorkMode: timerStore.mode == .work,
                        sessionIndex: timerStore.completedPomodoros + 1,
                        completedInCycle: timerStore.completedPomodoros % max(1, settings.longBreakEvery),
                        cycleLength: max(1, settings.longBreakEvery),
                        isPaused: isPaused
                    )
                    .scaleEffect(
                        settings.decorativeMotionEnabled && celebratePulse
                        ? 1.04
                        : (settings.decorativeMotionEnabled && timerStore.isRunning && timerStore.mode == .work && ringBreath ? 1.015 : 1)
                    )
                    .animation(
                        settings.decorativeMotionEnabled ? .easeOut(duration: 0.35) : .linear(duration: 0),
                        value: celebratePulse
                    )
                    .animation(
                        settings.decorativeMotionEnabled && timerStore.isRunning && timerStore.mode == .work
                        ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                        value: ringBreath
                    )

                    if let cap = timerStore.capRestart, !timerStore.isRunning, !timerStore.isSessionInProgress {
                        capRestartButton(cap)
                            .padding(.top, 10)
                            .transition(.opacity)
                    }

                    if !stageImmersive {
                        TimerModeSwitcher(layout: layout)
                            .frame(maxWidth: min(layout.modeSwitcherMaxWidth, layout.width - layout.horizontalPadding * 2))
                            .padding(.top, 14)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    TimerControlsBar(
                        layout: layout,
                        modeColor: modeColor,
                        playInvite: playInvite,
                        showResetConfirm: $showResetConfirm,
                        onPlayToggle: requestStartOrToggle
                    )
                    .padding(.top, 8)

                    Spacer(minLength: 4)
                    Color.clear.frame(height: TimerLayoutMath.lerp(4, 10, layout.eased))
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, layout.horizontalPadding)
                .animation(.easeInOut(duration: 0.22), value: stageImmersive)
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
        .onChange(of: timerStore.mode) { _ in
            syncAmbientMotion()
        }
        .confirmationDialog(
            "开始专注",
            isPresented: $showFocusModeHint,
            titleVisibility: .visible
        ) {
            Button("直接开始") { timerStore.toggle() }
            Button("打开系统专注设置…") {
                SystemSettingsLinks.openFocus()
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
                                      ? (colorScheme == .light ? 0.04 : 0.07)
                                      : (colorScheme == .light ? 0.11 : 0.15)),
                    modeColor.opacity(quiet
                                      ? (colorScheme == .light ? 0.015 : 0.03)
                                      : (colorScheme == .light ? 0.035 : 0.055)),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 30,
                endRadius: 500
            )

            if focusMode.isActive {
                Color.black.opacity(colorScheme == .light ? 0.10 : 0.14)
            }
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

    /// Keep ring-breath / play-invite motion synced with mode and focus state.
    private func syncAmbientMotion() {
        guard settings.decorativeMotionEnabled else {
            ringBreath = false
            playInvite = false
            return
        }
        if timerStore.isRunning {
            ringBreath = false
            playInvite = false
            if timerStore.mode == .work {
                DispatchQueue.main.async {
                    ringBreath = true
                }
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

}
