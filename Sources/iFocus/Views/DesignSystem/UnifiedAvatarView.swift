import SwiftUI
import AppKit

struct UnifiedAvatarView: View {
    let path: String?
    let colorIndex: Int
    let username: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            if let path = path, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Default tomato avatar using the macOS high-res App Icon!
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.05) // Subtle padding to ensure it fits beautifully in the circle
                } else {
                    // Fallback circle if app icon is somehow unavailable
                    Circle()
                        .fill(Color.red)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.25), lineWidth: 1.2)
        )
    }
}
