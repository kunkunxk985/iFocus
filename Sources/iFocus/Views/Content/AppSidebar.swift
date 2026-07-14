import SwiftUI

/// Left navigation rail + account chip.
struct AppSidebar: View {
    @Binding var sidebarCollapsed: Bool
    @Binding var isAccountMenuPresented: Bool
    var onPresentAccountMenu: () -> Void
    var onDismissAccountMenu: () -> Void

    @EnvironmentObject var viewState: ContentViewState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    private var titlebarContentInset: CGFloat {
        sidebarCollapsed ? AppTheme.collapsedSidebarTopInset : AppTheme.detailTopInset
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

    var body: some View {
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

    private var bottomUserBar: some View {
        Button {
            if isAccountMenuPresented {
                onDismissAccountMenu()
            } else {
                onPresentAccountMenu()
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
                onDismissAccountMenu()
            }

            accountMenuButton("设置", icon: "gearshape") {
                openWindow(id: "settings")
                onDismissAccountMenu()
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
