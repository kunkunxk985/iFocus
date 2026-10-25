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
    @AppStorage("sidebarGroupFocusExpanded") private var focusGroupExpanded = true
    @AppStorage("sidebarGroupListsExpanded") private var listsGroupExpanded = true
    @AppStorage("sidebarGroupRecordsExpanded") private var recordsGroupExpanded = true

    private enum SidebarNavGroup: String {
        case focus
        case lists
        case records
    }

    /// Four lists that do not contain each other: today, tomorrow, the days
    /// after that through day 7, and tasks with no date.
    private func taskItems(_ counts: TaskFiltering.SidebarBadgeCounts) -> [SidebarItem] {
        [
            SidebarItem(
                title: "今天",
                screen: .todayTask,
                badge: badgeIfPositive(counts.today),
                icon: "sun.max"
            ),
            SidebarItem(
                title: "明天",
                screen: .tomorrowTask,
                badge: badgeIfPositive(counts.tomorrow),
                icon: "sunrise"
            ),
            SidebarItem(
                title: "稍后",
                screen: .weekTask,
                badge: badgeIfPositive(counts.week),
                icon: "clock"
            ),
            SidebarItem(
                title: "收集箱",
                screen: .inboxTask,
                badge: badgeIfPositive(counts.inbox),
                icon: "tray"
            )
        ]
    }

    private func reviewItems() -> [SidebarItem] {
        [
            SidebarItem(
                title: "已完成",
                screen: .completedTask,
                badge: nil,
                icon: "checkmark.circle"
            ),
            SidebarItem(
                title: "我的记录",
                screen: .analytics,
                badge: nil,
                icon: "chart.bar"
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
                    VStack(alignment: .leading, spacing: 6) {
                        collapsibleGroup(
                            title: "专注",
                            group: .focus,
                            isExpanded: $focusGroupExpanded
                        ) {
                            sidebarRow(
                                title: "专注钟",
                                screen: .timer,
                                badge: nil,
                                icon: "timer",
                                accentColor: AppTheme.accent,
                                emphasizeRunning: timerStore.isRunning
                            )
                        }

                        collapsibleGroup(
                            title: "清单",
                            group: .lists,
                            isExpanded: $listsGroupExpanded
                        ) {
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
                        }

                        collapsibleGroup(
                            title: "记录",
                            group: .records,
                            isExpanded: $recordsGroupExpanded
                        ) {
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
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
                .softScroll()
                .onChange(of: viewState.selectedScreen) { screen in
                    guard let screen else { return }
                    expandGroupContaining(screen)
                }
                .onAppear {
                    if let screen = viewState.selectedScreen {
                        expandGroupContaining(screen)
                    }
                }

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

    private func expandGroupContaining(_ screen: AppScreen) {
        switch screen {
        case .timer:
            focusGroupExpanded = true
        case .todayTask, .tomorrowTask, .weekTask, .plannedTask, .inboxTask:
            listsGroupExpanded = true
        case .completedTask, .analytics, .profile:
            recordsGroupExpanded = true
        }
    }

    private func collapsibleGroup<Content: View>(
        title: String,
        group: SidebarNavGroup,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(AppTheme.springInteractive) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.50))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.3)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.70))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title)分组")
            .accessibilityValue(isExpanded.wrappedValue ? "已展开" : "已折叠")

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 1) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, group == .focus ? 2 : 12)
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
        .buttonStyle(SidebarRowButtonStyle(isSelected: isSelected))
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
        HStack(spacing: 10) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    // Grey until selected, so the rail does not compete with the stage.
                    .foregroundColor(
                        isSelected
                        ? accentColor
                        : AppTheme.secondaryText(for: colorScheme)
                    )

                if emphasizeRunning {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                        .offset(x: 9, y: -8)
                }
            }
            .frame(width: 22, height: 22)

            Text(title)
                .font(.system(size: 14.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundColor(
                    isSelected
                    ? AppTheme.primaryText(for: colorScheme)
                    : AppTheme.primaryText(for: colorScheme).opacity(0.88)
                )
                .lineLimit(1)

            Spacer(minLength: 4)

            if let badge, !badge.isEmpty {
                // Plain count, the way Mail prints "94 封邮件" — a pill reads as a badge,
                // not as part of a source list.
                Text(badge)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(badgeForeground)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var badgeForeground: Color {
        if showsOverdue { return Color.red.opacity(0.9) }
        return isSelected
            ? AppTheme.primaryText(for: colorScheme).opacity(0.75)
            : AppTheme.secondaryText(for: colorScheme).opacity(0.8)
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.16), value: isSelected)
            .onHover { isHovering = $0 }
    }

    /// A source list selects with a neutral fill — accent fills and hairline borders
    /// read as a custom control, which is exactly what a native sidebar never does.
    private func backgroundFill(isPressed: Bool) -> Color {
        if isSelected {
            if colorScheme == .light {
                return Color.black.opacity(isPressed ? 0.10 : 0.075)
            }
            return Color.white.opacity(isPressed ? 0.17 : 0.13)
        }
        if isPressed {
            return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
        }
        if isHovering {
            return colorScheme == .light ? Color.black.opacity(0.035) : Color.white.opacity(0.06)
        }
        return Color.clear
    }
}
