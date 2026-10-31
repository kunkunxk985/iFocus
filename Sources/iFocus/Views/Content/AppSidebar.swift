import SwiftUI
import iFocusCore

/// Left navigation rail with integrated traffic lights, sidebar toggle, and refined navigation rows.
struct AppSidebar: View {
    @Binding var sidebarCollapsed: Bool
    @Binding var isAccountMenuPresented: Bool
    var isFullScreen: Bool = false
    var onPresentAccountMenu: () -> Void
    var onDismissAccountMenu: () -> Void

    @EnvironmentObject var viewState: ContentViewState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var dropTargetScreen: AppScreen?

    /// Four lists that do not contain each other: today, tomorrow, the days
    /// after that through day 7, and tasks with no date.
    private func taskItems(_ counts: TaskFiltering.SidebarBadgeCounts) -> [SidebarItem] {
        [
            SidebarItem(
                title: "今天",
                screen: .todayTask,
                badge: badgeIfPositive(counts.today),
                icon: "sun.max.fill",
                accentColor: Color(red: 0.96, green: 0.60, blue: 0.06)
            ),
            SidebarItem(
                title: "明天",
                screen: .tomorrowTask,
                badge: badgeIfPositive(counts.tomorrow),
                icon: "sunrise.fill",
                accentColor: Color(red: 0.95, green: 0.39, blue: 0.36)
            ),
            SidebarItem(
                title: "稍后",
                screen: .weekTask,
                badge: badgeIfPositive(counts.week),
                icon: "clock.fill",
                accentColor: Color(red: 0.44, green: 0.40, blue: 0.94)
            ),
            SidebarItem(
                title: "收集箱",
                screen: .inboxTask,
                badge: badgeIfPositive(counts.inbox),
                icon: "tray.fill",
                accentColor: Color(red: 0.16, green: 0.58, blue: 0.96)
            )
        ]
    }

    private func reviewItems() -> [SidebarItem] {
        [
            SidebarItem(
                title: "已完成",
                screen: .completedTask,
                badge: nil,
                icon: "checkmark.circle.fill",
                accentColor: Color(red: 0.16, green: 0.72, blue: 0.45)
            ),
            SidebarItem(
                title: "我的记录",
                screen: .analytics,
                badge: nil,
                icon: "chart.bar.fill",
                accentColor: Color(red: 0.08, green: 0.66, blue: 0.74)
            )
        ]
    }

    private func badgeIfPositive(_ count: Int) -> String? {
        count > 0 ? "\(count)" : nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                sidebarHeader

                ScrollView {
                    let counts = taskStore.sidebarBadgeCounts()
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarRow(
                            title: "专注钟",
                            screen: .timer,
                            badge: timerStore.isRunning ? "进行中" : nil,
                            icon: "timer",
                            accentColor: AppTheme.accent,
                            emphasizeRunning: timerStore.isRunning
                        )

                        sidebarDivider

                        ForEach(taskItems(counts)) { item in
                            sidebarRow(
                                title: item.title,
                                screen: item.screen,
                                badge: item.badge,
                                icon: item.icon,
                                accentColor: item.accentColor ?? AppTheme.accent,
                                showsOverdue: item.screen == .todayTask && counts.overdue > 0
                            )
                        }

                        sidebarDivider

                        ForEach(reviewItems()) { item in
                            sidebarRow(
                                title: item.title,
                                screen: item.screen,
                                badge: item.badge,
                                icon: item.icon,
                                accentColor: item.accentColor ?? AppTheme.accent
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .softScroll()

                bottomUserBar
            }
        }
        // Full-bleed: the material runs to the window's top-left corner so the window
        // buttons sit on the sidebar's surface. The inset floating panel left them
        // perched on its rounded corner with ~5pt of clearance, which read as cramped
        // and gave them no material to sit on.
        .adaptiveGlass(cornerRadius: 0, fallbackMaterial: .sidebar)
        .padding(.trailing, 4)
    }

    /// Reserve the titlebar band; the toggle itself is a window-toolbar item.
    private var sidebarHeader: some View {
        Color.clear
            .frame(height: AppTheme.topHeaderHeight)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(AppTheme.separatorLow(for: colorScheme))
            .frame(height: 0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func sidebarRow(
        title: String,
        screen: AppScreen,
        badge: String?,
        icon: String,
        accentColor: Color,
        emphasizeRunning: Bool = false,
        showsOverdue: Bool = false
    ) -> some View {
        let isSelected = viewState.selectedScreen == screen
            || (screen == .analytics && viewState.selectedScreen == .profile)
        return Button {
            viewState.selectedScreen = screen
        } label: {
            SidebarRowLabel(
                title: title,
                icon: icon,
                badge: badge,
                accentColor: accentColor,
                isSelected: isSelected,
                emphasizeRunning: emphasizeRunning,
                showsOverdue: showsOverdue
            )
        }
        .buttonStyle(SidebarRowButtonStyle(isSelected: isSelected, accentColor: accentColor))
        .dropDestination(for: String.self) { items, _ in
            handleTaskDrop(items, to: screen)
        } isTargeted: { targeted in
            guard supportsTaskDrop(screen) else { return }
            if targeted {
                dropTargetScreen = screen
            } else if dropTargetScreen == screen {
                dropTargetScreen = nil
            }
        }
        .overlay {
            if dropTargetScreen == screen {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(0.8), lineWidth: 1.5)
            }
        }
    }

    private func supportsTaskDrop(_ screen: AppScreen) -> Bool {
        switch screen {
        case .todayTask, .tomorrowTask, .inboxTask, .completedTask:
            return true
        default:
            return false
        }
    }

    private func handleTaskDrop(_ items: [String], to screen: AppScreen) -> Bool {
        guard supportsTaskDrop(screen),
              let raw = items.first,
              let id = UUID(uuidString: raw),
              taskStore.tasks.contains(where: { $0.id == id })
        else { return false }

        let filter: TaskStore.TaskFilter
        switch screen {
        case .todayTask: filter = .todayTask
        case .tomorrowTask: filter = .tomorrowTask
        case .inboxTask: filter = .inboxTask
        case .completedTask: filter = .completedTask
        default: return false
        }

        taskStore.moveTask(id: id, to: filter)
        withAnimation(.easeOut(duration: 0.15)) {
            viewState.selectedScreen = screen
        }
        dropTargetScreen = nil
        return true
    }

    private var bottomUserBar: some View {
        Button {
            if isAccountMenuPresented {
                onDismissAccountMenu()
            } else {
                onPresentAccountMenu()
            }
        } label: {
            HStack(spacing: 10) {
                UnifiedAvatarView(
                    path: settings.avatarPath,
                    colorIndex: settings.avatarColorIndex,
                    username: settings.username.isEmpty ? "小番茄" : settings.username,
                    size: 34
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.08 : 0.15), lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(settings.username.isEmpty ? "小番茄" : settings.username)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    SidebarAccountStatusLine()
                }
                .layoutPriority(1)

                Spacer(minLength: 2)

                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isAccountMenuPresented
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.09 : 0.16)
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isAccountMenuPresented
                        ? AppTheme.accent.opacity(0.24)
                        : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(SoftHoverButtonStyle(cornerRadius: 10))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 0.5)
                .opacity(0.4)
        }
    }
}

// MARK: - Sidebar Row Components

private struct SidebarRowLabel: View {
    let title: String
    let icon: String
    let badge: String?
    let accentColor: Color
    let isSelected: Bool
    let emphasizeRunning: Bool
    let showsOverdue: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? accentColor
                            : accentColor.opacity(colorScheme == .light ? 0.14 : 0.20)
                    )
                    .frame(width: 26, height: 26)
                    .shadow(
                        color: isSelected ? accentColor.opacity(0.32) : Color.clear,
                        radius: 4,
                        y: 1.5
                    )

                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(isSelected ? .white : accentColor)

                if emphasizeRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 1.2)
                        )
                        .offset(x: 9, y: -9)
                }
            }
            .frame(width: 26, height: 26)

            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(
                    isSelected
                        ? AppTheme.primaryText(for: colorScheme)
                        : AppTheme.primaryText(for: colorScheme).opacity(0.90)
                )
                .lineLimit(1)

            Spacer(minLength: 4)

            if let badge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: emphasizeRunning ? 10.5 : 11.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(badgeForeground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(badgeBackground)
                    )
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 9)
        .padding(.vertical, 7.5)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var badgeForeground: Color {
        if showsOverdue { return Color.red }
        if emphasizeRunning { return accentColor }
        return isSelected
            ? accentColor
            : AppTheme.secondaryText(for: colorScheme)
    }

    private var badgeBackground: Color {
        if showsOverdue {
            return Color.red.opacity(colorScheme == .light ? 0.14 : 0.22)
        }
        if emphasizeRunning {
            return accentColor.opacity(colorScheme == .light ? 0.15 : 0.24)
        }
        if isSelected {
            return accentColor.opacity(colorScheme == .light ? 0.16 : 0.25)
        }
        return colorScheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.09)
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? accentColor.opacity(colorScheme == .light ? 0.28 : 0.38)
                            : Color.clear,
                        lineWidth: 0.75
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: 3.5, height: 16)
                        .padding(.leading, 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovering && !isSelected ? 1.008 : 1.0))
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.spring(response: 0.26, dampingFraction: 0.80), value: isSelected)
            .onHover { isHovering = $0 }
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        if isSelected {
            if colorScheme == .light {
                return accentColor.opacity(isPressed ? 0.16 : 0.11)
            }
            return accentColor.opacity(isPressed ? 0.24 : 0.18)
        }
        if isPressed {
            return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
        }
        if isHovering {
            return colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.07)
        }
        return Color.clear
    }
}
