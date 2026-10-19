import SwiftUI

struct ContentView: View {
    @StateObject private var viewState = ContentViewState()
    @State private var isAccountMenuPresented = false
    @State private var showResetConfirm = false
    @State private var showResumeSessionAlert = false
    @State private var didApplySmartLanding = false

    @State private var isFullScreen = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = false
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    private func expandedSidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        let fluid = min(1, max(0, (availableWidth - WindowLayoutMetrics.minimum.width)
                               / max(1, WindowLayoutMetrics.reference.width - WindowLayoutMetrics.minimum.width)))
        return 208 + fluid * 44
    }

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        if sidebarCollapsed { return 0 }
        return expandedSidebarWidth(for: availableWidth)
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
            let targetSidebarWidth = expandedSidebarWidth(for: geometry.size.width)
            let currentSidebarWidth = sidebarWidth(for: geometry.size.width)

            ZStack(alignment: .topLeading) {
                AppTheme.contentBackground(for: colorScheme)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    AppSidebar(
                        sidebarCollapsed: $sidebarCollapsed,
                        isAccountMenuPresented: $isAccountMenuPresented,
                        isFullScreen: isFullScreen,
                        onPresentAccountMenu: presentAccountMenu,
                        onDismissAccountMenu: dismissAccountMenu
                    )
                    .frame(width: targetSidebarWidth, alignment: .leading)
                    .frame(width: currentSidebarWidth, alignment: .leading)
                    .clipped()
                    .allowsHitTesting(!sidebarCollapsed)
                    .accessibilityHidden(sidebarCollapsed)

                    detailPane
                        .environment(\.windowLayout, layout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(AppTheme.springGentle, value: sidebarCollapsed)
                .animation(.easeInOut(duration: 0.16), value: layout.scale)

                // Mirrors the native layout: with the sidebar open the toggle sits at the
                // sidebar's trailing edge, just short of the divider — the position Mail
                // and Finder use. Collapsed, there is no sidebar to sit in, so it falls
                // back to just after the window buttons.
                HStack(alignment: .center, spacing: 0) {
                    Color.clear
                        .frame(
                            width: sidebarCollapsed
                                ? AppTheme.trafficLightLeading + 58
                                : max(0, currentSidebarWidth - 48),
                            height: 1
                        )
                        .accessibilityHidden(true)
                    SidebarToggleButton(sidebarCollapsed: $sidebarCollapsed)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: AppTheme.topHeaderHeight)
                .offset(y: -AppTheme.titlebarControlOffset)
                .zIndex(25)

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
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .environmentObject(viewState)
        .animation(accountMenuAnimation, value: isAccountMenuPresented)
        .animation(.easeOut(duration: 0.25), value: hasCompletedOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: timerStore.showDailyGoalCelebration)
        .onAppear {
            let fs = NSApplication.shared.windows.first(where: { $0.title == "iFocus" })?.styleMask.contains(.fullScreen) ?? false
            isFullScreen = fs
            WindowStateModel.shared.isFullScreen = fs
            WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
            WindowStateModel.shared.isSidebarCollapsed = sidebarCollapsed
            WindowChrome.layoutMainWindowTrafficLights()
            ViewMenuSanitizer.attachToViewMenu()
            applySmartLaunchLandingIfNeeded()
            if hasCompletedOnboarding, timerStore.pendingResumeSnapshot != nil {
                showResumeSessionAlert = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            if (note.object as? NSWindow)?.title != "设置" {
                isFullScreen = true
                WindowStateModel.shared.isFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { note in
            if (note.object as? NSWindow)?.title != "设置" {
                isFullScreen = true
                WindowStateModel.shared.isFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { note in
            if (note.object as? NSWindow)?.title != "设置" {
                isFullScreen = false
                WindowStateModel.shared.isFullScreen = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { note in
            if (note.object as? NSWindow)?.title != "设置" {
                isFullScreen = false
                WindowStateModel.shared.isFullScreen = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.toggleSidebar)) { _ in
            withAnimation(AppTheme.springGentle) {
                sidebarCollapsed.toggle()
                WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
                WindowStateModel.shared.isSidebarCollapsed = sidebarCollapsed
            }
        }
        .onChange(of: sidebarCollapsed) { collapsed in
            WindowLayoutStore.isSidebarCollapsed = collapsed
            WindowStateModel.shared.isSidebarCollapsed = collapsed
            if collapsed {
                dismissAccountMenu()
            }
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
            AppHaptics.buttonClick()
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
                AppHaptics.buttonClick()
                timerStore.skipToNext()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.newTask)) { _ in
            let isTaskInputScreen: Bool
            switch viewState.selectedScreen {
            case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .inboxTask:
                isTaskInputScreen = true
            default:
                isTaskInputScreen = false
            }
            if !isTaskInputScreen {
                viewState.selectedScreen = .todayTask
            }
            viewState.shouldFocusQuickAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.searchTasks)) { _ in
            let isTaskScreen: Bool
            switch viewState.selectedScreen {
            case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .completedTask, .inboxTask:
                isTaskScreen = true
            default:
                isTaskScreen = false
            }
            if !isTaskScreen {
                viewState.selectedScreen = .todayTask
            }
            viewState.shouldFocusSearch = true
        }
        .timerResetConfirmation(isPresented: $showResetConfirm, timerStore: timerStore)
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
        .alert(
            "部分记录没能读出来",
            isPresented: Binding(
                get: { taskStore.upgradeNotice != nil && taskStore.dataLoadErrorMessage == nil },
                set: { if !$0 { taskStore.upgradeNotice = nil } }
            )
        ) {
            Button("打开数据文件夹") {
                settings.openDataFolderInFinder()
                taskStore.upgradeNotice = nil
            }
            Button("知道了", role: .cancel) {
                taskStore.upgradeNotice = nil
            }
        } message: {
            Text(taskStore.upgradeNotice ?? "")
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
        let timePart = snap.resumeTimeLabel
        let prefix = snap.resumeReasonLabel
        if let title = snap.workTaskTitle, !title.isEmpty, snap.timerMode == .work {
            return "\(prefix)「\(title)」· \(modeName) \(timePart)。恢复后处于暂停，可点继续。选「稍后」可在顶部横幅再处理。"
        }
        return "\(prefix)\(modeName) \(timePart)。恢复后处于暂停。选「稍后」可在顶部横幅再处理。"
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
                        title: "选择一个功能"
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: shouldShowFloatingPill)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timerStore.pendingResumeSnapshot != nil)
    }
    
    private var resumeBannerShortMessage: String {
        guard let snap = timerStore.pendingResumeSnapshot else { return "有未完成的专注会话" }
        let modeName = snap.timerMode?.rawValue ?? "计时"
        let timePart = snap.resumeTimeLabel
        let reason = snap.resumeReasonLabel
        if let title = snap.workTaskTitle, !title.isEmpty, snap.timerMode == .work {
            return "\(reason) · 「\(title)」\(timePart)"
        }
        return "\(reason) · \(modeName) \(timePart)"
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
