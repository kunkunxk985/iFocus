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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = false
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    /// Space under the transparent titlebar so sidebar content clears traffic lights.
    private let titlebarContentInset: CGFloat = AppTheme.detailTopInset
    private let collapsedSidebarWidth: CGFloat = 64

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        if sidebarCollapsed { return collapsedSidebarWidth }
        return min(252, max(216, availableWidth * 0.10))
    }

    private var smartItems: [SidebarItem] {
        // Single O(n) scan — previously six filter+sorts on every sidebar body pass.
        let counts = taskStore.sidebarBadgeCounts()
        let todayBadge: String? = {
            if counts.overdue > 0 { return "\(counts.overdue)" }
            if counts.today > 0 { return "\(counts.today)" }
            return nil
        }()
        return [
            SidebarItem(title: "今天", screen: .todayTask, badge: todayBadge, icon: "sun.max.fill", tint: Color(hex: "#F59E0B")),
            SidebarItem(title: "明天", screen: .tomorrowTask, badge: badgeIfPositive(counts.tomorrow), icon: "sunrise.fill", tint: Color(hex: "#EC4899")),
            SidebarItem(title: "本周", screen: .weekTask, badge: badgeIfPositive(counts.week), icon: "calendar", tint: Color(hex: "#EF4444")),
            SidebarItem(title: "已计划", screen: .plannedTask, badge: badgeIfPositive(counts.planned), icon: "calendar.badge.clock", tint: Color(hex: "#8B5CF6")),
            SidebarItem(title: "已完成", screen: .completedTask, badge: nil, icon: "checkmark.circle.fill", tint: Color(hex: "#10B981")),
            SidebarItem(title: "收集箱", screen: .inboxTask, badge: badgeIfPositive(counts.inbox), icon: "tray.fill", tint: Color(hex: "#3B82F6"))
        ]
    }
    
    private func badgeIfPositive(_ count: Int) -> String? {
        count > 0 ? "\(count)" : nil
    }
    
    private var shouldShowFloatingPill: Bool {
        viewState.selectedScreen != .timer && timerStore.isSessionInProgress
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                AppTheme.contentBackground(for: colorScheme)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    sidebarPane
                        .frame(width: sidebarWidth(for: geometry.size.width))
                        .animation(.easeInOut(duration: 0.2), value: sidebarCollapsed)

                    detailPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                        }
                    }
                    .transition(.opacity)
                    .zIndex(40)
                }
            }
        }
        // Draw under the transparent titlebar so no system white strip shows through.
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .environmentObject(viewState)
        .animation(accountMenuAnimation, value: isAccountMenuPresented)
        .animation(.easeOut(duration: 0.25), value: hasCompletedOnboarding)
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
        // IMPORTANT: never subscribe to `clockTick` on this root view.
        // Per-second invalidation re-renders the whole tree (task list + edit sheet)
        // and freezes macOS DatePicker / controls. Clock UI lives in leaf views only.
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
                
                if sidebarCollapsed {
                    collapsedSidebarHeader
                } else {
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
    
    private var collapsedSidebarHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.14))
                )
                .help("iFocus")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }
    
    private var sidebarCollapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                sidebarCollapsed.toggle()
                WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
            }
        } label: {
            HStack {
                Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 13, weight: .semibold))
                if !sidebarCollapsed {
                    Text("收起侧栏")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
            }
            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            .padding(.horizontal, sidebarCollapsed ? 0 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? AppTheme.accent : (emphasizeRunning ? AppTheme.accent : tint))
                    .frame(width: 20)

                if !sidebarCollapsed {
                    Text(title)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? AppTheme.primaryText(for: colorScheme) : AppTheme.primaryText(for: colorScheme).opacity(0.88))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if let badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(badgeForeground(isSelected: isSelected, emphasizeRunning: emphasizeRunning, badge: badge))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(badgeBackground(isSelected: isSelected, emphasizeRunning: emphasizeRunning, badge: badge))
                            )
                    }
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 12 : 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: sidebarCollapsed ? .center : .leading)
            .help(sidebarCollapsed ? title : "")
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.11 : 0.18)
                          : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: 3, height: 16)
                        .padding(.leading, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func badgeForeground(isSelected: Bool, emphasizeRunning: Bool, badge: String) -> Color {
        if isSelected || emphasizeRunning { return .white }
        let overdue = taskStore.tasks(for: .todayTask).filter(\.isOverdue).count
        if overdue > 0 && badge == "\(overdue)" { return .white }
        return AppTheme.secondaryText(for: colorScheme)
    }
    
    private func badgeBackground(isSelected: Bool, emphasizeRunning: Bool, badge: String) -> Color {
        if isSelected || emphasizeRunning { return AppTheme.accent }
        let overdue = taskStore.tasks(for: .todayTask).filter(\.isOverdue).count
        if overdue > 0 && badge == "\(overdue)" { return Color.red.opacity(0.85) }
        return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
    }

    private var detailPane: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch viewState.selectedScreen {
                case .timer:
                    TimerView()
                case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .completedTask, .inboxTask:
                    TaskListView()
                case .analytics:
                    AnalyticsView()
                case .profile:
                    ProfileView()
                case nil:
                    Text("选择一个功能开始")
                        .font(.title2)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
            .animation(.easeInOut(duration: 0.18), value: viewState.selectedScreen)

            if shouldShowFloatingPill {
                FloatingFocusPill()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: shouldShowFloatingPill)
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
                    // Subtle press-in highlight when menu is open (replaces the lone chevron)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isAccountMenuPresented
                              ? AppTheme.accent.opacity(colorScheme == .light ? 0.07 : 0.12)
                              : Color.clear)
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
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
        return "本地账号"
    }
}

/// Floating timer pill — owns its own clock subscription so task list / sheets stay calm.
private struct FloatingFocusPill: View {
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    
    var body: some View {
        HStack(spacing: 14) {
            Button {
                viewState.selectedScreen = .timer
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(timerStore.mode.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: timerStore.isRunning ? timerStore.mode.accent.opacity(0.55) : .clear, radius: 4)
                    
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
            }
            .buttonStyle(.plain)
            .help(timerStore.isRunning ? "暂停" : "继续")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(timerStore.mode.accent.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 20, y: 8)
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

// MARK: - First-run onboarding

private struct OnboardingOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let onFinish: () -> Void
    
    private let steps: [(icon: String, title: String, body: String)] = [
        ("timer", "开始一个番茄", "在专注钟选任务（或自由专注），空格开始。菜单栏会显示倒计时。"),
        ("checklist", "用清单排期", "今天 / 明天 / 收集箱整理任务；完成目标会记入统计。"),
        ("chart.bar.fill", "看数据与习惯", "数据统计看今日与本周；个人资料有热力图与连续天数。")
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
                
                Text("三分钟上手本地番茄钟 · 数据只存在这台 Mac。")
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
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        configuration.isPressed
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
                        : Color.clear
                    )
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
