import SwiftUI

struct ContentView: View {
    @StateObject private var viewState = ContentViewState()
    @State private var isAccountMenuPresented = false
    @State private var showResetConfirm = false
    @State private var showResumeSessionAlert = false
    @State private var didApplySmartLanding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = false
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        if sidebarCollapsed { return AppTheme.collapsedSidebarWidth }
        let fluid = min(1, max(0, (availableWidth - WindowLayoutMetrics.minimum.width)
                               / max(1, WindowLayoutMetrics.reference.width - WindowLayoutMetrics.minimum.width)))
        return 208 + fluid * 44
    }

    private var shouldShowFloatingPill: Bool {
        viewState.selectedScreen != .timer && timerStore.isSessionInProgress
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = WindowLayoutMetrics(
                width: geometry.size.width,
                height: geometry.size.height,
                densityScale: settings.uiDensity.scale
            )
            ZStack(alignment: .topLeading) {
                AppTheme.contentBackground(for: colorScheme)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    AppSidebar(
                        sidebarCollapsed: $sidebarCollapsed,
                        isAccountMenuPresented: $isAccountMenuPresented,
                        onPresentAccountMenu: presentAccountMenu,
                        onDismissAccountMenu: dismissAccountMenu
                    )
                    .frame(width: sidebarWidth(for: geometry.size.width))
                    .animation(.easeInOut(duration: 0.2), value: sidebarCollapsed)

                    detailPane
                        .environment(\.windowLayout, layout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.16), value: layout.scale)

                if isAccountMenuPresented {
                    // Tap-catcher above content, below popover — dismiss account menu.
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissAccountMenu()
                        }
                        .zIndex(25)

                    AccountMenuPopover(
                        onProfile: {
                            viewState.selectedScreen = .profile
                            dismissAccountMenu()
                        },
                        onSettings: {
                            openWindow(id: "settings")
                            dismissAccountMenu()
                        }
                    )
                        .padding(.leading, 14)
                        .padding(.bottom, 78)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .transition(accountMenuTransition)
                        .zIndex(30)
                }
                
                if !hasCompletedOnboarding {
                    OnboardingOverlay {
                        withAnimation(.easeOut(duration: 0.25)) {
                            hasCompletedOnboarding = true
                            applySmartLaunchLandingIfNeeded(force: true)
                            // After first-run, offer pending resume if any.
                            if timerStore.pendingResumeSnapshot != nil {
                                showResumeSessionAlert = true
                            }
                        }
                    }
                    .transition(.opacity)
                    .zIndex(40)
                }
                
                if timerStore.showDailyGoalCelebration {
                    DailyGoalCelebrationOverlay(
                        completed: timerStore.completedPomodoros,
                        goal: settings.dailyGoal,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                timerStore.dismissDailyGoalCelebration()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }
            }
        }
        // Draw under the transparent titlebar so no system white strip shows through.
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .environmentObject(viewState)
        .animation(accountMenuAnimation, value: isAccountMenuPresented)
        .animation(.easeOut(duration: 0.25), value: hasCompletedOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: timerStore.showDailyGoalCelebration)
        .onAppear {
            // Keep AppStorage sidebar flag in sync for traffic-light layout.
            WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
            WindowChrome.layoutMainWindowTrafficLights()
            applySmartLaunchLandingIfNeeded()
            // Offer resume after quit mid-session — wait until onboarding is done.
            if hasCompletedOnboarding, timerStore.pendingResumeSnapshot != nil {
                showResumeSessionAlert = true
            }
        }
        .onChange(of: sidebarCollapsed) { collapsed in
            WindowLayoutStore.isSidebarCollapsed = collapsed
            WindowChrome.layoutMainWindowTrafficLights()
        }
        .onChange(of: viewState.selectedScreen) { _ in
            if isAccountMenuPresented {
                dismissAccountMenu()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.navigate)) { note in
            if let screen = note.object as? AppScreen {
                viewState.selectedScreen = screen
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.openSettings)) { _ in
            openWindow(id: "settings")
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.toggleTimer)) { _ in
            timerStore.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.resetTimer)) { _ in
            if timerStore.isSessionInProgress || timerStore.isRunning {
                showResetConfirm = true
            } else {
                timerStore.celebrationMessage = nil
                timerStore.reset()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.skipTimer)) { _ in
            if timerStore.canSkipSegment {
                timerStore.skipToNext()
            }
        }
        .confirmationDialog(
            "重置当前计时？",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                timerStore.celebrationMessage = nil
                timerStore.reset()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("进行中的时段不会记入专注记录。")
        }
        .alert(
            "恢复专注会话？",
            isPresented: $showResumeSessionAlert
        ) {
            Button("恢复") {
                if timerStore.resumeFromPendingSnapshot() {
                    viewState.selectedScreen = .timer
                }
            }
            Button("丢弃", role: .destructive) {
                timerStore.discardPendingResume()
            }
            Button("稍后", role: .cancel) {
                // Keep pending — banner stays until resume / discard.
            }
        } message: {
            Text(resumeAlertMessage)
        }
        .confirmationDialog(
            "丢弃当前时段？",
            isPresented: Binding(
                get: { timerStore.pendingSessionDiscard != nil },
                set: { if !$0 { timerStore.cancelPendingSessionDiscard() } }
            ),
            titleVisibility: .visible
        ) {
            Button("确定丢弃并继续", role: .destructive) {
                timerStore.confirmPendingSessionDiscard()
            }
            Button("取消", role: .cancel) {
                timerStore.cancelPendingSessionDiscard()
            }
        } message: {
            Text(timerStore.pendingSessionDiscard?.message ?? "")
        }
        .alert(
            "数据文件异常",
            isPresented: Binding(
                get: { taskStore.dataLoadErrorMessage != nil },
                set: { if !$0 { /* keep until user acts */ } }
            )
        ) {
            Button("打开数据文件夹") {
                settings.openDataFolderInFinder()
            }
            Button("重新加载") {
                _ = taskStore.reloadFromDisk()
            }
            Button("从空白开始", role: .destructive) {
                taskStore.acknowledgeCorruptLoadAndStartFresh()
            }
        } message: {
            Text(taskStore.dataLoadErrorMessage ?? "")
        }
        // IMPORTANT: never subscribe to `clockTick` on this root view.
        // Per-second invalidation re-renders the whole tree (task list + edit sheet)
        // and freezes macOS DatePicker / controls. Clock UI lives in leaf views only.
    }
    
    /// Quiet-tool launch: open 今天 when there is work waiting; otherwise 专注钟.
    private func applySmartLaunchLandingIfNeeded(force: Bool = false) {
        guard settings.smartLaunchLanding else { return }
        guard force || !didApplySmartLanding else { return }
        didApplySmartLanding = true
        // Don't yank user if a deep link already navigated, or session resume is pending.
        if timerStore.pendingResumeSnapshot != nil {
            viewState.selectedScreen = .timer
            return
        }
        let counts = taskStore.sidebarBadgeCounts()
        if counts.today > 0 || counts.overdue > 0 {
            viewState.selectedScreen = .todayTask
        } else {
            viewState.selectedScreen = .timer
        }
    }
    
    private var resumeAlertMessage: String {
        guard let snap = timerStore.pendingResumeSnapshot else {
            return "有未完成的计时可以恢复。"
        }
        let modeName = snap.timerMode?.rawValue ?? "计时"
        let remaining = Int(snap.timeRemaining.rounded())
        let m = remaining / 60
        let s = remaining % 60
        let timePart = String(format: "%d:%02d", m, s)
        let prefix = snap.resumeReasonLabel
        if let title = snap.workTaskTitle, !title.isEmpty, snap.timerMode == .work {
            return "\(prefix)「\(title)」· \(modeName) 还剩 \(timePart)。恢复后处于暂停，可点继续。选「稍后」可在顶部横幅再处理。"
        }
        return "\(prefix)\(modeName) 还剩 \(timePart)。恢复后处于暂停。选「稍后」可在顶部横幅再处理。"
    }
    
    private var detailPane: some View {
        ZStack {
            Group {
                switch viewState.selectedScreen {
                case .timer:
                    TimerView()
                        .transition(pageTransition)
                case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .completedTask, .inboxTask:
                    TaskListView()
                        .transition(pageTransition)
                case .analytics:
                    AnalyticsView()
                        .transition(pageTransition)
                case .profile:
                    ProfileView()
                        .transition(pageTransition)
                case nil:
                    AppEmptyState(
                        systemImage: "sidebar.left",
                        title: "选择一个功能开始",
                        subtitle: "从左侧打开专注钟、清单或数据统计"
                    )
                    .transition(pageTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
            .id(viewState.selectedScreen)
            .animation(.easeInOut(duration: 0.22), value: viewState.selectedScreen)

            // Top: recoverable session after quit / crash (survives "稍后").
            if timerStore.pendingResumeSnapshot != nil {
                VStack {
                    PendingResumeBanner(
                        message: resumeBannerShortMessage,
                        onResume: {
                            if timerStore.resumeFromPendingSnapshot() {
                                viewState.selectedScreen = .timer
                            }
                        },
                        onDiscard: {
                            timerStore.discardPendingResume()
                        }
                    )
                    Spacer(minLength: 0)
                }
                .padding(.top, AppTheme.detailTopInset - 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(12)
            }
            
            // Bottom: leave-timer floating pill.
            if shouldShowFloatingPill {
                VStack {
                    Spacer(minLength: 0)
                    FloatingFocusPill()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: shouldShowFloatingPill)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timerStore.pendingResumeSnapshot != nil)
    }
    
    private var resumeBannerShortMessage: String {
        guard let snap = timerStore.pendingResumeSnapshot else { return "有未完成的专注会话" }
        let modeName = snap.timerMode?.rawValue ?? "计时"
        let remaining = Int(snap.timeRemaining.rounded())
        let m = remaining / 60
        let s = remaining % 60
        let timePart = String(format: "%d:%02d", m, s)
        let reason = snap.resumeReasonLabel
        if let title = snap.workTaskTitle, !title.isEmpty, snap.timerMode == .work {
            return "\(reason) · 「\(title)」还剩 \(timePart)"
        }
        return "\(reason) · \(modeName) 还剩 \(timePart)"
    }
    
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .offset(y: -4))
        )
    }

    /// Soft ease — less bouncy than a snappy spring so the menu doesn’t feel stiff.
    private var accountMenuAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)
    }
    
    /// Rise from the user bar with a light fade (anchor bottom-leading).
    private var accountMenuTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.94, anchor: .bottomLeading))
                .combined(with: .offset(y: 10)),
            removal: .opacity
                .combined(with: .scale(scale: 0.97, anchor: .bottomLeading))
                .combined(with: .offset(y: 6))
        )
    }
    
    private func presentAccountMenu() {
        withAnimation(accountMenuAnimation) {
            isAccountMenuPresented = true
        }
    }
    
    private func dismissAccountMenu() {
        withAnimation(accountMenuAnimation) {
            isAccountMenuPresented = false
        }
    }
}
