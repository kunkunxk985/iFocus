import SwiftUI

/// Profile screen — name, avatar and color. Numbers live on the stats page.
struct ProfileView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
    
    @State private var isEditing = false
    @State private var tempUsername = ""
    
    private var displayName: String {
        let name = settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "小番茄" : name
    }

    var body: some View {
        PageContainer(maxWidth: 900, horizontalPadding: 40) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProfileHeaderBar(
                        onEdit: {
                            tempUsername = displayName
                            isEditing = true
                        }
                    )
                    
                    ProfileIdentityBlock(
                        avatarPath: settings.avatarPath,
                        avatarColorIndex: settings.avatarColorIndex,
                        username: displayName
                    )
                }
                .padding(.bottom, timerStore.isSessionInProgress ? 96 : 32)
            }
            .softScroll()
        }
        .overlay {
            if isEditing {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { isEditing = false }

                    EditProfileSheet(
                        tempUsername: $tempUsername,
                        isPresented: $isEditing
                    )
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isEditing)
    }
}
