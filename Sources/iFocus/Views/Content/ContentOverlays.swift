import SwiftUI
import AppKit

// MARK: - Clock leaves (isolated from ContentView root)

/// Sidebar subtitle under avatar — only this leaf re-renders each second while running.
struct SidebarAccountStatusLine: View {
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    
    var body: some View {
        if let statusText {
            Text(statusText)
                .font(.caption2)
                .foregroundColor(timerStore.isRunning ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .onReceive(timerStore.clockTick) { _ in
                    guard timerStore.isRunning else { return }
                    clockVersion &+= 1
                }
        }
    }
    
    /// Idle shows the name only. A live timer is status, not a caption.
    private var statusText: String? {
        _ = clockVersion
        if timerStore.isRunning {
            return "专注中 · \(timerStore.timeString)"
        }
        if timerStore.isSessionInProgress {
            return "已暂停 · \(timerStore.timeString)"
        }
        return nil
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
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme

    let isReplay: Bool
    let onFinish: () -> Void

    @State private var stepIndex = 0
    @State private var addSampleTask = true
    @State private var didAddSampleTask = false
    @State private var didPrepareDefaults = false
    @State private var hasAppeared = false

    init(isReplay: Bool = false, onFinish: @escaping () -> Void) {
        self.isReplay = isReplay
        self.onFinish = onFinish
    }

    private enum OnboardingStep: Int, CaseIterable, Identifiable {
        case welcome, focus, tasks, permissions, ready

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .welcome: return "欢迎"
            case .focus: return "专注节奏"
            case .tasks: return "今天清单"
            case .permissions: return "提醒与启动"
            case .ready: return "开始使用"
            }
        }

        var title: String {
            switch self {
            case .welcome: return "欢迎使用 iFocus"
            case .focus: return "一次只做一件事"
            case .tasks: return "把今天写下来"
            case .permissions: return "不错过休息时刻"
            case .ready: return "准备好了"
            }
        }

        var subtitle: String {
            switch self {
            case .welcome: return "安静、本机、不打扰的专注工具。"
            case .focus: return "选好任务，按下开始，其余交给计时。"
            case .tasks: return "轻量的每日清单，拖一下就能改期。"
            case .permissions: return "按你的意愿开启提醒与登录启动。"
            case .ready: return "三步开始你的第一次专注。"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .light ? 0.30 : 0.52)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                rail

                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    stepPane
                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.cardBackground(for: colorScheme))
            }
            .frame(width: 640, height: 444)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.separator(for: colorScheme).opacity(0.85), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0.20 : 0.48),
                radius: 40,
                y: 18
            )
            .scaleEffect(hasAppeared ? 1 : 0.97)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear(perform: handleAppear)
            .onChange(of: stepIndex) { newValue in
                if OnboardingStep(rawValue: newValue) == .permissions {
                    timerStore.updateNotificationStatus()
                    settings.refreshLaunchAtLoginFromSystem()
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: Rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                appMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("iFocus")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundColor(primary)
                    Text("专注，只在这台 Mac")
                        .font(.system(size: 10))
                        .foregroundColor(secondary)
                }
            }

            Text("新手引导")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(secondary.opacity(0.85))
                .padding(.top, 30)
                .padding(.bottom, 8)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                ForEach(OnboardingStep.allCases) { step in
                    railRow(step)
                }
            }

            Spacer(minLength: 14)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(AppTheme.accent.opacity(0.8))
                    .padding(.top, 1)
                Text("数据只在本机\n无账号 · 无云同步")
                    .font(.system(size: 10))
                    .foregroundColor(secondary)
                    .lineSpacing(2)
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(width: 192)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                AppTheme.cardBackground(for: colorScheme)
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(colorScheme == .light ? 0.15 : 0.12),
                        AppTheme.accent.opacity(colorScheme == .light ? 0.04 : 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.separatorLow(for: colorScheme))
                .frame(width: 0.5)
        }
    }

    private func railRow(_ step: OnboardingStep) -> some View {
        let isCurrent = step.rawValue == stepIndex
        let isDone = step.rawValue < stepIndex

        return Button {
            go(to: step.rawValue)
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(isCurrent || isDone
                              ? AppTheme.accent
                              : AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.18))
                        .frame(width: 20, height: 20)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(step.rawValue + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(isCurrent ? .white : AppTheme.accent)
                    }
                }

                Text(step.label)
                    .font(.system(size: 12.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? primary : secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isCurrent ? AppTheme.cardBackground(for: colorScheme).opacity(0.72) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("第 \(step.rawValue + 1) 步：\(step.label)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: Right pane

    private var topBar: some View {
        HStack {
            Text("第 \(stepIndex + 1) 步，共 \(OnboardingStep.allCases.count) 步")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(AppTheme.accent)

            Spacer()

            Button("跳过") {
                finish()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(secondary)
            .help(isReplay ? "关闭引导" : "跳过引导，直接开始使用")
            .accessibilityHint("直接完成引导，可在设置中重新播放")
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private var stepPane: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(currentStep.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(primary)

                Text(currentStep.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)

                stepContent
                    .padding(.top, 20)
            }
            .id(stepIndex)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 14)),
                removal: .opacity.combined(with: .offset(x: -8))
            ))
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome: welcomeStep
        case .focus: focusStep
        case .tasks: tasksStep
        case .permissions: permissionsStep
        case .ready: readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                appMark(size: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text("你的专注，只留在这台 Mac。")
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundColor(primary)
                    Text("没有账号，也没有需要维护的云同步。")
                        .font(.system(size: 11.5))
                        .foregroundColor(secondary)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                onboardingFeature(icon: "timer", title: "专注钟", detail: "正计时或番茄倒计时，按自己的节奏来")
                onboardingDivider
                onboardingFeature(icon: "checklist", title: "今天清单", detail: "写下 1–3 件要紧事，拖一下就能改期")
                onboardingDivider
                onboardingFeature(icon: "chart.bar.fill", title: "专注统计", detail: "每一次专注都记录在本地，随时可查")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .background(onboardingCardBackground)
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                shortcutRow(keys: [settings.toggleShortcut.label], title: "开始 / 暂停", detail: "专注页")
                onboardingDivider
                shortcutRow(keys: ["⌥", "⌘", "M"], title: "迷你计时窗", detail: "置顶小窗")
                onboardingDivider
                shortcutRow(keys: ["⌥", "⌘", "F"], title: "全屏专注", detail: "收起干扰")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .background(onboardingCardBackground)

            onboardingHint(
                icon: "menubar.rectangle",
                text: "菜单栏常驻倒计时。左键打开专注面板，右键是完整菜单。"
            )

            onboardingHint(
                icon: "clock",
                text: "切到别的 App 后计时也会继续，结束时仍会提醒你。"
            )
        }
    }

    private var tasksStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Toggle("", isOn: $addSampleTask)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(didAddSampleTask)
                        .accessibilityLabel("添加示例任务")

                    Text("添加一条示例任务")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(primary)

                    Spacer()

                    Text(didAddSampleTask ? "已加入今天" : (addSampleTask ? "可随时删除" : "不会添加"))
                        .font(.system(size: 10))
                        .foregroundColor(didAddSampleTask ? AppTheme.success : secondary.opacity(0.8))
                }

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(TaskCategory.study.color.opacity(0.14))
                            .frame(width: 30, height: 30)
                        Image(systemName: TaskCategory.study.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(TaskCategory.study.color)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("读完一节书")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primary)
                        Text("学习 · 1 个番茄")
                            .font(.system(size: 10.5))
                            .foregroundColor(secondary)
                    }

                    Spacer()

                    Text("今天")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(AppTheme.elevatedBackground(for: colorScheme)))
                }
                .opacity(addSampleTask || didAddSampleTask ? 1 : 0.45)
            }
            .padding(12)
            .background(onboardingCardBackground)

            onboardingHint(
                icon: "line.3.horizontal",
                text: "拖动任务左侧手柄，可以直接放进侧栏的「明天」或「收集箱」。"
            )
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    permissionIcon("bell.badge.fill", color: AppTheme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("专注结束提醒")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primary)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(notificationStatusColor)
                                .frame(width: 5, height: 5)
                            Text(notificationStatusCopy)
                                .font(.system(size: 10.5))
                                .foregroundColor(secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    if let action = notificationActionLabel {
                        Button(action: handleNotificationAction) {
                            Text(action)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                onboardingDivider

                HStack(spacing: 11) {
                    permissionIcon("power", color: AppTheme.violet)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("登录时自动打开")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primary)
                        Text("让 iFocus 在后台提前就绪")
                            .font(.system(size: 10.5))
                            .foregroundColor(secondary)
                    }

                    Spacer(minLength: 8)

                    Toggle("", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            settings.launchAtLogin = newValue
                            settings.applyLaunchAtLoginPreference()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("登录时自动打开 iFocus")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(onboardingCardBackground)

            if let loginFeedbackText {
                onboardingHint(icon: "exclamationmark.triangle.fill", text: loginFeedbackText, tint: AppTheme.warning)
            } else {
                onboardingHint(icon: "info.circle", text: "两项都可以稍后在「设置 › 状态中心」更改。")
            }
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                readyRow(
                    number: 1,
                    title: "写下今天",
                    detail: didAddSampleTask ? "示例任务已加入「今天」清单" : "在「今天」列下 1–3 件要紧事"
                )
                onboardingDivider
                readyRow(number: 2, title: "开始专注", detail: startHint)
                onboardingDivider
                readyRow(number: 3, title: "看看节奏", detail: "结束后在「我的记录」查看专注历史")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .background(onboardingCardBackground)

            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text("随时可以在「设置 › 通用 › 新手引导」重新播放。")
                    .font(.system(size: 10.5))
            }
            .foregroundColor(secondary)
            .padding(.leading, 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if stepIndex > 0 {
                Button("上一步") {
                    go(to: stepIndex - 1)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()

            Button(isLastStep ? (isReplay ? "完成" : "开始使用") : "继续") {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
    }

    // MARK: Content pieces

    private func onboardingFeature(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primary)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private func shortcutRow(keys: [String], title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(primary)
                        .frame(minWidth: key.count > 1 ? 36 : 20, minHeight: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppTheme.elevatedBackground(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                        )
                }
            }
            .frame(width: 92, alignment: .leading)

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(primary)

            Spacer(minLength: 8)

            Text(detail)
                .font(.system(size: 10.5))
                .foregroundColor(secondary)
        }
        .padding(.vertical, 7)
    }

    private func readyRow(number: Int, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(primary)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private func onboardingHint(icon: String, text: String, tint: Color = AppTheme.accent) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(colorScheme == .light ? 0.07 : 0.12))
        )
    }

    private func permissionIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(colorScheme == .light ? 0.12 : 0.18))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(color)
        }
    }

    @ViewBuilder
    private func appMark(size: CGFloat) -> some View {
        Group {
            if let icon = appIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(AppTheme.accent)
                    Image(systemName: "timer")
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 6, y: 3)
    }

    private var appIconImage: NSImage? {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // Development builds without the packaged app icon still get a mark.
        return NSApplication.shared.applicationIconImage
    }

    private var onboardingCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.elevatedBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
    }

    private var onboardingDivider: some View {
        Rectangle()
            .fill(AppTheme.separatorLow(for: colorScheme))
            .frame(height: 0.5)
    }

    // MARK: State

    private var primary: Color {
        AppTheme.primaryText(for: colorScheme)
    }

    private var secondary: Color {
        AppTheme.secondaryText(for: colorScheme)
    }

    private var currentStep: OnboardingStep {
        OnboardingStep(rawValue: stepIndex) ?? .welcome
    }

    private var isLastStep: Bool {
        stepIndex >= OnboardingStep.allCases.count - 1
    }

    private var startHint: String {
        let keyLabel = settings.toggleShortcut.label
        return settings.countUpWork
            ? "回到专注钟，按\(keyLabel)开始正计时"
            : "回到专注钟，按\(keyLabel)开始 \(settings.workMinutes) 分钟"
    }

    private var notificationStatusCopy: String {
        switch timerStore.notificationStatus {
        case "已授权": return "已开启 · 专注结束时提醒"
        case "已拒绝": return "系统里已关闭"
        case "未请求": return "尚未开启"
        case "仅应用版可用": return "打包版可开启"
        default: return timerStore.notificationStatus
        }
    }

    private var notificationStatusColor: Color {
        switch timerStore.notificationStatus {
        case "已授权": return AppTheme.success
        case "已拒绝": return AppTheme.danger
        case "未请求": return AppTheme.warning
        default: return secondary
        }
    }

    private var notificationActionLabel: String? {
        switch timerStore.notificationStatus {
        case "已授权": return "系统设置…"
        case "已拒绝": return "去开启…"
        case "未请求": return "允许"
        case "仅应用版可用": return nil
        default: return "刷新"
        }
    }

    private var loginFeedbackText: String? {
        guard let feedback = settings.launchAtLoginFeedback else { return nil }
        if feedback.hasPrefix("已开启") || feedback.hasPrefix("已关闭") { return nil }
        return feedback
    }

    private func handleNotificationAction() {
        switch timerStore.notificationStatus {
        case "已授权", "已拒绝":
            SystemSettingsLinks.openNotifications()
        case "未请求":
            timerStore.requestNotificationPermission()
        default:
            timerStore.updateNotificationStatus()
        }
    }

    private func handleAppear() {
        if !didPrepareDefaults {
            didPrepareDefaults = true
            addSampleTask = taskStore.tasks.isEmpty
        }
        timerStore.updateNotificationStatus()
        settings.refreshLaunchAtLoginFromSystem()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            hasAppeared = true
        }
    }

    private func go(to newIndex: Int) {
        let clamped = min(max(newIndex, 0), OnboardingStep.allCases.count - 1)
        guard clamped != stepIndex else { return }
        // Leaving the task step forward commits the opt-in sample exactly once.
        if currentStep == .tasks, clamped > stepIndex {
            commitSampleTaskIfNeeded()
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            stepIndex = clamped
        }
    }

    private func advance() {
        if isLastStep {
            finish()
        } else {
            go(to: stepIndex + 1)
        }
    }

    private func finish() {
        if currentStep == .tasks {
            commitSampleTaskIfNeeded()
        }
        onFinish()
    }

    private func commitSampleTaskIfNeeded() {
        guard addSampleTask, !didAddSampleTask else { return }
        didAddSampleTask = true
        taskStore.addOnboardingSampleTask()
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
    @ObservedObject private var updates = AppUpdateCenter.shared
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
                Text(settings.username.isEmpty ? "小番茄" : settings.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            Divider().opacity(0.7)

            Button {
                updates.checkAndInstall()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(updateTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        if let updateCaption {
                            Text(updateCaption)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(AccountMenuRowButtonStyle())
            .disabled(updates.isBusy)

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

    private var updateTitle: String {
        switch updates.phase {
        case .checking: return "正在检查…"
        case .downloading: return "正在下载…"
        case .installing: return "正在安装…"
        case .idle, .upToDate, .noRelease, .failed: return "检查新版本"
        }
    }

    private var updateCaption: String? {
        switch updates.phase {
        case .upToDate: return "已是最新版本"
        case .noRelease: return "还没有发布的新版本"
        case .downloading: return "正在下载新版本"
        case .installing: return "安装后会重新打开"
        case .failed(let message): return message
        case .idle, .checking: return nil
        }
    }
}
