import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditProfileSheet: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var tempUsername: String
    @Binding var isPresented: Bool
    @State private var isPickingAvatar = false
    @State private var isShowingAvatarError = false
    @State private var avatarErrorMessage = "请选择 JPG、PNG、HEIC 或其他可读取的图片。"
    @State private var originalAvatarPath: String?
    @State private var originalAvatarColorIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 22) {
            Text("编辑个人资料")
                .font(.headline)
                .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("昵称")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("输入昵称", text: $tempUsername)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            
            VStack(spacing: 12) {
                Text("头像")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                UnifiedAvatarView(
                    path: settings.avatarPath,
                    colorIndex: settings.avatarColorIndex,
                    username: tempUsername.isEmpty ? "小番茄" : tempUsername,
                    size: 68
                )

                if settings.avatarPath == nil {
                    HStack(spacing: 8) {
                        ForEach(0..<UnifiedAvatarView.palette.count, id: \.self) { index in
                            let selected = settings.avatarColorIndex == index
                            let swatchColor = UnifiedAvatarView.palette[index]
                            Button {
                                settings.avatarColorIndex = index
                                AppHaptics.selectionChanged()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(swatchColor)
                                        .frame(width: 18, height: 18)
                                    if index == 0 {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    } else if selected {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(2)
                                .overlay(
                                    Circle()
                                        .stroke(selected ? swatchColor : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(index == 0 ? "默认应用图标" : "配色 \(index)")
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button {
                        presentAvatarPicker()
                    } label: {
                        Label("上传头像", systemImage: "photo")
                    }
                    
                    if settings.avatarPath != nil {
                        Button(role: .destructive) {
                            AppHaptics.buttonClick()
                            settings.removeAvatar()
                        } label: {
                            Label("恢复默认", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(width: 240)
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                Button("取消") {
                    // Roll back avatar path/color if user uploaded then cancelled.
                    settings.avatarPath = originalAvatarPath
                    settings.avatarColorIndex = originalAvatarColorIndex
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
                    AppHaptics.buttonClick()
                    settings.username = tempUsername
                    settings.sanitizeUsername()
                    // Avatar already on disk from picker — keep current path.
                    originalAvatarPath = settings.avatarPath
                    originalAvatarColorIndex = settings.avatarColorIndex
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 28)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.16 : 0.40), radius: 24, x: 0, y: 10)
        .onAppear {
            originalAvatarPath = settings.avatarPath
            originalAvatarColorIndex = settings.avatarColorIndex
        }
        .alert("无法更换头像", isPresented: $isShowingAvatarError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(avatarErrorMessage)
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
            if !settings.uploadAvatar(from: url) {
                avatarErrorMessage = "图片读取失败，请换一张 JPG、PNG 或 HEIC 图片后重试。"
                isShowingAvatarError = true
            }
        }

        // Keep the picker independent from the transparent SwiftUI titlebar.
        // Attached sheets can render their column backgrounds black on newer macOS.
        panel.begin(completionHandler: completion)
    }
}
