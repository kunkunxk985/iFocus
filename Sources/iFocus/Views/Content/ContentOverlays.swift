import SwiftUI

// MARK: - Clock leaves (isolated from ContentView root)

/// Sidebar subtitle under avatar — only this leaf re-renders each second while running.
struct SidebarAccountStatusLine: View {
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
struct FloatingFocusPill: View {
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
                        Text(timerStore.isRunning ? "进行中" : "已暂停")
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

struct PendingResumeBanner: View {
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

struct DailyGoalCelebrationOverlay: View {
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

struct OnboardingOverlay: View {
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
struct AccountMenuRowButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        SoftHoverButtonBody(
            configuration: configuration,
            cornerRadius: 10,
            colorScheme: colorScheme
        )
    }
}


// MARK: - Account menu popover (shared chrome)

struct AccountMenuPopover: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    var onProfile: () -> Void
    var onSettings: () -> Void

    var body: some View {
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

            menuButton("个人资料", icon: "person.crop.circle", action: onProfile)
            menuButton("设置", icon: "gearshape", action: onSettings)
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

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
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
        }
        .buttonStyle(AccountMenuRowButtonStyle())
    }
}
