import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditProfileSheet: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var tempUsername: String
    @Binding var isPresented: Bool

    @FocusState private var isNameFocused: Bool

    @State private var isPickingAvatar = false
    @State private var isShowingAvatarError = false
    @State private var avatarErrorMessage = "请选择 JPG、PNG、HEIC 或其他可读取的图片。"
    @State private var originalAvatarPath: String?
    @State private var originalAvatarColorIndex: Int = 0
    @State private var hasSaved = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header title
            headerSection
            
            // Avatar preview, recessed palette tray, and upload/restore buttons
            avatarSection
            
            // High-polish capsule nickname input
            nicknameSection
            
            Divider()
                .padding(.vertical, 2)
            
            // Bottom action buttons and shortcut hints
            footerSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: 350)
        .floatingCardSurface(cornerRadius: 18)
        .overlay(alignment: .topTrailing) {
            FloatingModalCloseButton {
                handleCancel()
            }
            .padding([.top, .trailing], 14)
        }
        .onAppear {
            originalAvatarPath = settings.avatarPath
            originalAvatarColorIndex = settings.avatarColorIndex
            hasSaved = false
        }
        .onChange(of: isPresented) { presented in
            if !presented {
                rollbackAvatarState()
            }
        }
        .onDisappear {
            rollbackAvatarState()
        }
        .onExitCommand {
            handleCancel()
        }
        .alert("无法更换头像", isPresented: $isShowingAvatarError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(avatarErrorMessage)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        Text("编辑个人资料")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.primaryText(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    // MARK: - Avatar Section
    private var avatarSection: some View {
        VStack(spacing: 12) {
            Text("头像")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            // 72pt High-Res Avatar View
            UnifiedAvatarView(
                path: settings.avatarPath,
                colorIndex: settings.avatarColorIndex,
                username: tempUsername.isEmpty ? "小番茄" : tempUsername,
                size: 72
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.28), radius: 6, x: 0, y: 3)

            // Recessed Palette Tray (shown when no custom image is active)
            if settings.avatarPath == nil {
                paletteTray
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Action Buttons: Upload Photo & Restore Default
            avatarActionButtons
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Palette Tray (24pt Swatches in Recessed Capsule)
    private var paletteTray: some View {
        let presets = AccentPreset.allCases
        return HStack(spacing: 6) {
            ForEach(0..<presets.count, id: \.self) { index in
                let preset = presets[index]
                let swatchColor = preset.color
                let isSelected = (settings.avatarPath == nil && settings.avatarColorIndex == index)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        settings.avatarColorIndex = index
                    }
                    AppHaptics.selectionChanged()
                } label: {
                    ZStack {
                        // Active spring selection ring
                        Circle()
                            .strokeBorder(isSelected ? swatchColor : Color.clear, lineWidth: 2)
                            .frame(width: 30, height: 30)
                            .scaleEffect(isSelected ? 1.0 : 0.75)
                            .opacity(isSelected ? 1.0 : 0.0)

                        // 24pt Swatch Circle
                        Circle()
                            .fill(swatchColor)
                            .frame(width: 24, height: 24)
                            .shadow(
                                color: swatchColor.opacity(isSelected ? 0.35 : 0.15),
                                radius: isSelected ? 3 : 1,
                                x: 0,
                                y: 1
                            )

                        // Center indicator
                        if index == 0 {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        } else if isSelected {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(index == 0 ? "默认应用图标 (\(preset.label))" : preset.label)
                .accessibilityLabel(preset.label)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppTheme.elevatedBackground(for: colorScheme))
        )
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
        )
    }

    // MARK: - Avatar Action Buttons
    private var avatarActionButtons: some View {
        HStack(spacing: 10) {
            Button {
                presentAvatarPicker()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 11, weight: .medium))
                    Text(settings.avatarPath == nil ? "更换头像" : "更换图片")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
                )
            }
            .buttonStyle(.plain)
            .help("从本地文件选择一张图片作为自定义头像")

            if settings.avatarPath != nil {
                Button {
                    AppHaptics.buttonClick()
                    withAnimation(AppTheme.springInteractive) {
                        if let currentPath = settings.avatarPath, currentPath != originalAvatarPath {
                            try? FileManager.default.removeItem(atPath: currentPath)
                        }
                        settings.avatarPath = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("恢复默认")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.danger.opacity(0.90))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.danger.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.danger.opacity(0.22), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .help("清除上传的图片，恢复预设头像")
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Nickname Section
    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("昵称")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))

            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isNameFocused ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.70))
                    .frame(width: 16, height: 16)

                TextField("输入昵称", text: $tempUsername)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .focused($isNameFocused)
                    .onSubmit {
                        handleSave()
                    }

                if !tempUsername.isEmpty {
                    Button {
                        tempUsername = ""
                        isNameFocused = true
                        AppHaptics.selectionChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help("清空昵称")
                    .accessibilityLabel("清空昵称")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(colorScheme == .light ? 0.90 : 0.60))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isNameFocused ? AppTheme.accent.opacity(0.55) : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: isNameFocused ? 1.5 : 1
                    )
            )
            .shadow(
                color: isNameFocused ? AppTheme.accent.opacity(0.18) : .clear,
                radius: 4,
                x: 0,
                y: 0
            )
            .animation(AppTheme.springInteractive, value: isNameFocused)
            .animation(AppTheme.springInteractive, value: tempUsername.isEmpty)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("取消") {
                    handleCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
                )
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    handleSave()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(AppTheme.accent)
                )
                .shadow(color: AppTheme.accent.opacity(0.30), radius: 4, x: 0, y: 1.5)
                .keyboardShortcut(.return, modifiers: [.command])
            }

            FloatingModalShortcutHint(hint: "⌘↵ 保存 · Esc 取消")
        }
    }

    // MARK: - Actions & State Rollback
    private func handleCancel() {
        AppHaptics.buttonClick()
        rollbackAvatarState()
        isPresented = false
    }

    private func handleSave() {
        hasSaved = true
        AppHaptics.buttonClick()
        settings.username = tempUsername
        settings.sanitizeUsername()
        if let oldPath = originalAvatarPath, oldPath != settings.avatarPath {
            try? FileManager.default.removeItem(atPath: oldPath)
        }
        originalAvatarPath = settings.avatarPath
        originalAvatarColorIndex = settings.avatarColorIndex
        isPresented = false
    }

    private func rollbackAvatarState() {
        guard !hasSaved else { return }
        if settings.avatarPath != originalAvatarPath {
            if let uncommittedPath = settings.avatarPath, uncommittedPath != originalAvatarPath {
                try? FileManager.default.removeItem(atPath: uncommittedPath)
            }
            settings.avatarPath = originalAvatarPath
        }
        if settings.avatarColorIndex != originalAvatarColorIndex {
            settings.avatarColorIndex = originalAvatarColorIndex
        }
    }

    private func presentAvatarPicker() {
        guard !isPickingAvatar else { return }
        isPickingAvatar = true

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.prompt = "选择头像"
        panel.message = "选择一张图片作为头像"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            isPickingAvatar = false
            guard response == .OK, let url = panel.url else { return }
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let previousTempPath = settings.avatarPath
            if !settings.uploadAvatar(from: url, removePrevious: false) {
                avatarErrorMessage = "图片读取失败，请换一张 JPG、PNG 或 HEIC 图片后重试。"
                isShowingAvatarError = true
            } else if let previousTempPath,
                      previousTempPath != originalAvatarPath,
                      previousTempPath != settings.avatarPath {
                try? FileManager.default.removeItem(atPath: previousTempPath)
            }
        }

        panel.begin(completionHandler: completion)
    }
}
