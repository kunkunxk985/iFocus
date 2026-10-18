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

    private func agendaItems(_ counts: TaskFiltering.SidebarBadgeCounts) -> [SidebarItem] {
        [
            SidebarItem(
                title: "今天",
                screen: .todayTask,
                badge: badgeIfPositive(counts.today),
                icon: "sun.max.fill"
            ),
            SidebarItem(
                title: "明天",
                screen: .tomorrowTask,
                badge: badgeIfPositive(counts.tomorrow),
                icon: "sunrise.fill"
            ),
            SidebarItem(
                title: "本周",
                screen: .weekTask,
                badge: badgeIfPositive(counts.week),
                icon: "calendar"
            ),
            SidebarItem(
                title: "收集箱",
                screen: .inboxTask,
                badge: badgeIfPositive(counts.inbox),
                icon: "tray.fill"
            )
        ]
    }

    private func libraryItems(_ counts: TaskFiltering.SidebarBadgeCounts) -> [SidebarItem] {
        [
            SidebarItem(
                title: "已计划",
                screen: .plannedTask,
                badge: badgeIfPositive(counts.planned),
                icon: "calendar.badge.clock"
            ),
            SidebarItem(
                title: "已完成",
                screen: .completedTask,
                badge: nil,
                icon: "checkmark.circle.fill"
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
                    VStack(alignment: .leading, spacing: 2) {
                        sidebarRow(
                            title: "专注钟",
                            screen: .timer,
                            badge: nil,
                            icon: "timer",
                            accentColor: AppTheme.accent,
                            emphasizeRunning: timerStore.isRunning
                        )
                        sidebarRow(
                            title: "数据统计",
                            screen: .analytics,
                            badge: nil,
                            icon: "chart.bar.xaxis",
                            accentColor: AppTheme.accent
                        )

                        sidebarSection("待办") {
                            ForEach(agendaItems(counts)) { item in
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

                        sidebarSection("更多") {
                            ForEach(libraryItems(counts)) { item in
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
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .softScroll()

                bottomUserBar
            }
        }
        .adaptiveGlass(cornerRadius: AppTheme.radiusXL, fallbackMaterial: .sidebar)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }

    /// AppKit draws the native lights in the transparent titlebar; this row keeps the sidebar toggle aligned.
    private var sidebarHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 0)

            SidebarToggleButton(sidebarCollapsed: $sidebarCollapsed)
                .padding(.trailing, 12)
                .offset(y: -AppTheme.titlebarControlOffset)
        }
        .frame(height: AppTheme.topHeaderHeight)
    }

    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 4)

            content()
        }
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
                    size: 32
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.08 : 0.15), lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(settings.username.isEmpty ? "小番茄" : settings.username)
                        .font(.system(size: 13, weight: .semibold))
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
        HStack(spacing: 9) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isSelected
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme)
                    )

                if emphasizeRunning {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                        .offset(x: 8, y: -7)
                }
            }
            .frame(width: 20, height: 20)

            Text(title)
                .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(
                    isSelected
                    ? AppTheme.primaryText(for: colorScheme)
                    : AppTheme.primaryText(for: colorScheme).opacity(0.88)
                )
                .lineLimit(1)

            Spacer(minLength: 4)

            if let badge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(badgeForeground)
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(badgeBackground)
                    )
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 8.5, style: .continuous))
    }

    private var badgeForeground: Color {
        if showsOverdue || isSelected { return .white }
        return AppTheme.secondaryText(for: colorScheme)
    }

    private var badgeBackground: Color {
        if showsOverdue { return Color.red.opacity(0.88) }
        if isSelected { return AppTheme.accent }
        return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .strokeBorder(borderStroke, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.74), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.16), value: isSelected)
            .onHover { isHovering = $0 }
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        if isSelected {
            let alpha: Double = colorScheme == .light ? 0.11 : 0.20
            return isPressed ? AppTheme.accent.opacity(alpha + 0.05) : AppTheme.accent.opacity(alpha)
        }
        if isPressed {
            return colorScheme == .light ? Color.black.opacity(0.07) : Color.white.opacity(0.12)
        }
        if isHovering {
            return colorScheme == .light ? Color.black.opacity(0.045) : Color.white.opacity(0.07)
        }
        return Color.clear
    }

    private var borderStroke: Color {
        if isSelected {
            return AppTheme.accent.opacity(colorScheme == .light ? 0.20 : 0.32)
        }
        return Color.clear
    }
}
