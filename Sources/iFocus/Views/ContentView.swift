import SwiftUI

enum AppScreen: Hashable {
    case todayTask, tomorrowTask, weekTask, plannedTask, completedTask, inboxTask
    case timer, analytics, profile
}

class ContentViewState: ObservableObject {
    @Published var selectedScreen: AppScreen? = .timer
}

struct SidebarItem: Identifiable {
    /// Stable identity so ForEach does not recreate rows every body pass.
    var id: AppScreen { screen }
    let title: String
    let screen: AppScreen
    let badge: String?
    let icon: String
    let tint: Color
}

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

    /// Space under the transparent titlebar so sidebar content clears traffic lights.
    private var titlebarContentInset: CGFloat {
        // Narrow rail: less dead air under the three window buttons.
        sidebarCollapsed ? AppTheme.collapsedSidebarTopInset : AppTheme.detailTopInset
    }

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        if sidebarCollapsed { return AppTheme.collapsedSidebarWidth }
        // Fluid sidebar: narrower on small stages, roomier when wide.
        let fluid = min(1, max(0, (availableWidth - WindowLayoutMetrics.minimum.width)
                               / max(1, WindowLayoutMetrics.reference.width - WindowLayoutMetrics.minimum.width)))
        return 208 + fluid * 44 // 208…252
    }

    private var smartItems: [SidebarItem] {
        // Single O(n) scan — previously six filter+sorts on every sidebar body pass.
        let counts = taskStore.sidebarBadgeCounts()
        // Show total today open tasks; overdue only affects badge color, not the number alone.
        let todayBadge: String? = counts.today > 0 ? "\(counts.today)" : nil
        return [
            SidebarItem(title: "今天", screen: .todayTask, badge: todayBadge, icon: "sun.max.fill", tint: Color(hex: "#F59E0B")),
            SidebarItem(title: "明天", screen: .tomorrowTask, badge: badgeIfPositive(counts.tomorrow), icon: "sunrise.fill", tint: Color(hex: "#EC4899")),
            SidebarItem(title: "本周", screen: .weekTask, badge: badgeIfPositive(counts.week), icon: "calendar", tint: Color(hex: "#EF4444")),
            SidebarItem(title: "已计划", screen: .plannedTask, badge: badgeIfPositive(counts.planned), icon: "calendar.badge.clock", tint: Color(hex: "#8B5CF6")),
            SidebarItem(title: "已完成", screen: .completedTask, badge: nil, icon: "checkmark.circle.fill", tint: Color(hex: "#10B981")),
            SidebarItem(title: "收集箱", screen: .inboxTask, badge: badgeIfPositive(counts.inbox), icon: "tray.fill", tint: Color(hex: "#3B82F6"))
        ]
    }
    
    private var todayOverdueCount: Int {
        taskStore.sidebarBadgeCounts().overdue
    }
    
    private func badgeIfPositive(_ count: Int) -> String? {
        count > 0 ? "\(count)" : nil
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
                    sidebarPane
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

                    accountPopover
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
            timerStore.skipToNext()
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
    
    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                }
                Text("iFocus")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
            }
            Text(timeOfDayGreeting)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
    
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "小番茄" : name
        switch hour {
        case 5..<12: return "早上好，\(who)"
        case 12..<14: return "中午好，\(who)"
        case 14..<18: return "下午好，\(who)"
        case 18..<23: return "晚上好，\(who)"
        default: return "夜深了，\(who)"
        }
    }

    private var sidebarPane: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            AppTheme.sidebarTint(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sidebarTopSpacer
                
                // Collapsed: no leaf under the traffic lights — they already own the top
                // corner; a second brand mark makes the rail feel cramped and odd.
                if !sidebarCollapsed {
                    brandHeader
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: sidebarCollapsed ? 8 : 20) {
                        // Primary focus entry first — main product loop
                        sidebarSection(sidebarCollapsed ? "" : "专注") {
                            sidebarRow(
                                title: "专注钟",
                                screen: .timer,
                                badge: timerStore.isRunning ? "进行中" : (timerStore.isSessionInProgress ? "暂停" : nil),
                                icon: "timer",
                                tint: AppTheme.accent,
                                emphasizeRunning: timerStore.isRunning
                            )
                            sidebarRow(
                                title: "数据统计",
                                screen: .analytics,
                                badge: timerStore.completedPomodoros > 0 ? "\(timerStore.completedPomodoros)" : nil,
                                icon: "chart.bar.fill",
                                tint: .orange
                            )
                        }
                        
                        sidebarSection(sidebarCollapsed ? "" : "清单") {
                            ForEach(smartItems) { item in
                                sidebarRow(
                                    title: item.title,
                                    screen: item.screen,
                                    badge: item.badge,
                                    icon: item.icon,
                                    tint: item.tint
                                )
                            }
                        }
                    }
                    .padding(.horizontal, sidebarCollapsed ? 8 : 12)
                    .padding(.bottom, 16)
                }
                .softScroll()

                sidebarCollapseButton
                bottomUserBar
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
                .opacity(colorScheme == .light ? 0.55 : 0.7)
        }
    }
    
    private func toggleSidebarCollapsed() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarCollapsed.toggle()
            WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
        }
        // Re-center traffic lights for the new rail width after the width animates.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WindowChrome.layoutMainWindowTrafficLights()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            WindowChrome.layoutMainWindowTrafficLights()
        }
    }
    
    /// Final chrome: chevron rail control (not dual-pane SF Symbol).
    /// Collapsed → › expand; expanded → ‹ 收起侧栏.
    private var sidebarCollapseButton: some View {
        Button(action: toggleSidebarCollapsed) {
            if sidebarCollapsed {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(AppTheme.elevatedBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("收起侧栏")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help(sidebarCollapsed ? "展开侧栏" : "收起侧栏")
    }

    private var sidebarTopSpacer: some View {
        Color.clear
            .frame(height: titlebarContentInset)
    }

    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
            }

            content()
        }
    }

    private func sidebarRow(
        title: String,
        screen: AppScreen,
        badge: String?,
        icon: String,
        tint: Color,
        emphasizeRunning: Bool = false
    ) -> some View {
        let isSelected = viewState.selectedScreen == screen
        return Button {
            viewState.selectedScreen = screen
        } label: {
            HStack(spacing: sidebarCollapsed ? 0 : 11) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: sidebarCollapsed ? 14 : 13, weight: .semibold))
                        .foregroundColor(
                            isSelected || emphasizeRunning
                            ? AppTheme.accent
                            // Whisper of smart-list color — not full chroma when idle.
                            : tint.opacity(colorScheme == .light ? 0.48 : 0.55)
                        )
                        .frame(width: sidebarCollapsed ? 22 : 20, height: sidebarCollapsed ? 22 : 20)
                    if sidebarCollapsed, let badge, !badge.isEmpty {
                        Circle()
                            .fill(
                                screen == .todayTask && todayOverdueCount > 0
                                ? Color.red.opacity(0.9)
                                : AppTheme.accent.opacity(0.9)
                            )
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -2)
                    }
                }

                if !sidebarCollapsed {
                    Text(title)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? AppTheme.primaryText(for: colorScheme) : AppTheme.primaryText(for: colorScheme).opacity(0.88))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if let badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(badgeForeground(isSelected: isSelected, emphasizeRunning: emphasizeRunning, badge: badge, screen: screen))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(badgeBackground(isSelected: isSelected, emphasizeRunning: emphasizeRunning, badge: badge, screen: screen))
                            )
                    }
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 0 : 10)
            .padding(.vertical, sidebarCollapsed ? 10 : 9)
            .frame(maxWidth: .infinity, alignment: sidebarCollapsed ? .center : .leading)
            .help(sidebarCollapsed ? (badge.map { "\(title) · \($0)" } ?? title) : "")
            .background(
                RoundedRectangle(cornerRadius: sidebarCollapsed ? 12 : 10, style: .continuous)
                    .fill(isSelected
                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.11 : 0.18)
                          : Color.clear)
            )
            .overlay(alignment: .leading) {
                // Leading accent bar only in expanded mode (cramped / odd when collapsed).
                if isSelected && !sidebarCollapsed {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: 3, height: 16)
                        .padding(.leading, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: sidebarCollapsed ? 12 : 10, style: .continuous))
        }
        .buttonStyle(SoftHoverButtonStyle(cornerRadius: sidebarCollapsed ? 12 : 10))
    }
    
    private func badgeForeground(isSelected: Bool, emphasizeRunning: Bool, badge: String, screen: AppScreen) -> Color {
        if isSelected || emphasizeRunning { return .white }
        // Only the 今天 row uses overdue styling — never match by badge digit alone.
        if screen == .todayTask, todayOverdueCount > 0 { return .white }
        return AppTheme.secondaryText(for: colorScheme)
    }
    
    private func badgeBackground(isSelected: Bool, emphasizeRunning: Bool, badge: String, screen: AppScreen) -> Color {
        if isSelected || emphasizeRunning { return AppTheme.accent }
        if screen == .todayTask, todayOverdueCount > 0 { return Color.red.opacity(0.85) }
        return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
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
    
    private var bottomUserBar: some View {
        Button {
            if isAccountMenuPresented {
                dismissAccountMenu()
            } else {
                presentAccountMenu()
            }
        } label: {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.separator(for: colorScheme))
                    .frame(height: 1)
                    .opacity(0.45)

                if sidebarCollapsed {
                    // Avatar only — keeps rail clean under the › expand chip.
                    UnifiedAvatarView(
                        path: settings.avatarPath,
                        colorIndex: settings.avatarColorIndex,
                        username: settings.username.isEmpty ? "小番茄" : settings.username,
                        size: 30
                    )
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        Circle()
                            .fill(isAccountMenuPresented
                                  ? AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
                                  : Color.clear)
                            .frame(width: 40, height: 40)
                    )
                } else {
                    HStack(spacing: 10) {
                        UnifiedAvatarView(
                            path: settings.avatarPath,
                            colorIndex: settings.avatarColorIndex,
                            username: settings.username.isEmpty ? "小番茄" : settings.username,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.username.isEmpty ? "小番茄" : settings.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                                .lineLimit(1)
                            // Leaf clock — must not live on ContentView root.
                            SidebarAccountStatusLine()
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isAccountMenuPresented
                                  ? AppTheme.accent.opacity(colorScheme == .light ? 0.07 : 0.12)
                                  : Color.clear)
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isAccountMenuPresented ? "关闭菜单" : "账号与设置")
    }

    private var accountPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                UnifiedAvatarView(
                    path: settings.avatarPath,
                    colorIndex: settings.avatarColorIndex,
                    username: settings.username.isEmpty ? "小番茄" : settings.username,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.username.isEmpty ? "小番茄" : settings.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text("本地账号")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            Divider().opacity(0.7)

            accountMenuButton("个人资料", icon: "person.crop.circle") {
                viewState.selectedScreen = .profile
                dismissAccountMenu()
            }

            accountMenuButton("设置", icon: "gearshape") {
                openWindow(id: "settings")
                dismissAccountMenu()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(12)
        .frame(width: 228, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.menuBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .light ? 0.10 : 0.35), radius: 20, y: 8)
        )
    }

    private func accountMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Spacer()
                if title == "设置" {
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(AccountMenuRowButtonStyle())
    }

}

// MARK: - Clock leaves (isolated from ContentView root)

/// Sidebar subtitle under avatar — only this leaf re-renders each second while running.
private struct SidebarAccountStatusLine: View {
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .foregroundColor(timerStore.isRunning ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
            .lineLimit(1)
            .onReceive(timerStore.clockTick) { _ in
                guard timerStore.isRunning else { return }
                clockVersion &+= 1
            }
    }
    
    private var statusText: String {
        _ = clockVersion
        if timerStore.isRunning {
            return "专注中 · \(timerStore.timeString)"
        }
        if timerStore.isSessionInProgress {
            return "已暂停 · \(timerStore.timeString)"
        }
        return "本地账号"
    }
}

/// Floating timer pill — owns its own clock subscription so task list / sheets stay calm.
private struct FloatingFocusPill: View {
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
                        Text(timerStore.isRunning ? "进行中 · 点此返回" : "已暂停 · 点此返回")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Text(liveTimeString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(timerStore.mode.accent)
                .frame(minWidth: 56, alignment: .center)

            Button(action: { timerStore.toggle() }) {
                Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(timerStore.mode.accent))
                    .shadow(
                        color: settings.decorativeMotionEnabled && timerStore.isRunning
                            ? timerStore.mode.accent.opacity(0.28)
                            : .clear,
                        radius: 5,
                        y: 2
                    )
            }
            .buttonStyle(SoftScaleButtonStyle())
            .help(timerStore.isRunning ? "暂停" : "继续")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(0.97))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            timerStore.mode.accent.opacity(timerStore.isRunning ? 0.20 : 0.10),
                            lineWidth: 1
                        )
                )
                .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 12, y: 4)
        )
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

// MARK: - Pending session resume banner

private struct PendingResumeBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onResume: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.accent)
            
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("恢复", action: onResume)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.small)
            
            Button("丢弃", role: .destructive, action: onDiscard)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 16, y: 6)
        )
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Daily goal celebration

private struct DailyGoalCelebrationOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let completed: Int
    let goal: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .light ? 0.32 : 0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.28),
                                    AppTheme.accent.opacity(0.06)
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 56
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
                
                Text("今日目标达成")
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                
                Text("已完成 \(completed) / \(goal) 个番茄")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
                
                Text("可以收工，或继续做轻松的事。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                
                Button(action: onDismiss) {
                    Text("好的")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard + 4, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
                    .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard + 4, style: .continuous)
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
        }
    }
}

// MARK: - First-run onboarding

private struct OnboardingOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let onFinish: () -> Void
    
    private let steps: [(icon: String, title: String, body: String)] = [
        ("timer", "开始专注", "选任务或自由专注，空格开始。菜单栏会显示倒计时。"),
        ("checklist", "整理今天", "在「今天」写下要做的事；完成会记入本地统计。"),
        ("internaldrive", "数据只在本机", "无账号、无云同步。可随时在设置里打开数据文件夹。")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .light ? 0.28 : 0.45)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(AppTheme.accent)
                    Text("欢迎使用 iFocus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                }
                
                Text("安静的本机专注工具 · 数据只留在这台 Mac。")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: step.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1). \(step.title)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                                Text(step.body)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Button(action: onFinish) {
                        Text("开始使用")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppTheme.accent))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
            .frame(maxWidth: 440)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
                    .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 28, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            )
        }
    }
}

/// Soft hover / press for account menu rows (no hard system flash).
private struct AccountMenuRowButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        SoftHoverButtonBody(
            configuration: configuration,
            cornerRadius: 10,
            colorScheme: colorScheme
        )
    }
}
