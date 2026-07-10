import SwiftUI
import AppKit

// MARK: - Color hex convenience
extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6,
              let int = UInt64(trimmed, radix: 16) else {
            self = .clear
            return
        }
        let r = Double((int & 0xFF0000) >> 16) / 255.0
        let g = Double((int & 0x00FF00) >> 8) / 255.0
        let b = Double(int & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Accent + menu bar chrome preferences

enum AccentPreset: String, CaseIterable, Identifiable {
    case tomato
    case blue
    case green
    case purple
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .tomato: return "番茄红"
        case .blue: return "静谧蓝"
        case .green: return "专注绿"
        case .purple: return "灵感紫"
        }
    }
    
    var hex: String {
        switch self {
        case .tomato: return "#E85A3C"
        case .blue: return "#3B82F6"
        case .green: return "#10B981"
        case .purple: return "#8B5CF6"
        }
    }
    
    var color: Color { Color(hex: hex) }
    
    var nsColor: NSColor {
        Color.nsColor(hex: hex)
    }
}

enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case iconTime
    case iconProgress
    case iconOnly
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .iconOnly: return "仅图标"
        case .iconTime: return "图标 + 时间"
        case .iconProgress: return "图标 + 进度"
        }
    }
}

// MARK: - Theme
enum AppTheme {
    private static let accentDefaultsKey = "accentPreset"
    
    /// Live accent — reads preference so existing `AppTheme.accent` call sites pick it up.
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: accentDefaultsKey) ?? AccentPreset.tomato.rawValue
        return (AccentPreset(rawValue: raw) ?? .tomato).color
    }
    
    static var accentNSColor: NSColor {
        let raw = UserDefaults.standard.string(forKey: accentDefaultsKey) ?? AccentPreset.tomato.rawValue
        return (AccentPreset(rawValue: raw) ?? .tomato).nsColor
    }
    
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusControl: CGFloat = 12
    static let cornerRadiusRow: CGFloat = 14
    
    // Backgrounds — light mode uses cooler gray canvas so white cards lift off
    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#ECECEF") : Color(hex: "#121214")
    }
    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#E4E4EA") : Color(hex: "#1A1A1D")
    }
    static func sidebarTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.14) : Color.black.opacity(0.16)
    }
    static func sidebarRowBackground(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(0.001)
    }
    static func glassControlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.72) : Color.white.opacity(0.08)
    }
    static func menuBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.96) : Color(hex: "#252528").opacity(0.97)
    }
    static func contentBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#ECECEF") : Color(hex: "#121214")
    }
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white : Color(hex: "#1E1E22")
    }
    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F4F4F7") : Color(hex: "#2A2A2F")
    }
    
    // Text — slightly stronger contrast in light mode
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "141416") : Color.white.opacity(0.95)
    }
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "5C5C63") : Color(hex: "9A9A9F")
    }
    
    // Separators / overlays
    static func separator(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.09) : Color.white.opacity(0.11)
    }
    static func separatorLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.07)
    }
    static func overlayThin(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.06) : Color.black.opacity(0.15)
    }
    static func overlayLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.04) : Color.black.opacity(0.08)
    }
    
    // Shared card chrome
    static func cardFill(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusCard, style: .continuous)
            .fill(cardBackground(for: colorScheme))
    }
    
    static func cardStroke(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusCard, style: .continuous)
            .stroke(separatorLow(for: colorScheme), lineWidth: 1)
    }
    
    static func softShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.07) : Color.black.opacity(0.32)
    }
    
    static var windowBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? NSColor(white: 0.925, alpha: 1.0) : NSColor(white: 0.07, alpha: 1.0)
        }
    }
}

extension Color {
    static func nsColor(hex: String) -> NSColor {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let int = UInt64(trimmed, radix: 16) else {
            return .systemOrange
        }
        let r = CGFloat((int & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((int & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(int & 0x0000FF) / 255.0
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Layout chrome
extension AppTheme {
    /// Clears the transparent titlebar / traffic-light band so detail content
    /// doesn’t sit flush against the top of the window.
    /// Tuned to sit under a Gemini / Electron `hiddenInset` traffic-light row.
    static let detailTopInset: CGFloat = 68
    
    /// Traffic-light inset matching Gemini / Electron `titleBarStyle: hiddenInset`
    /// (comfortably clear of the rounded window corner).
    static let trafficLightLeading: CGFloat = 20
    static let trafficLightTop: CGFloat = 18
    static let trafficLightSpacing: CGFloat = 8
}

// MARK: - Reusable chrome
struct SoftCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppTheme.cornerRadiusCard
    var elevated: Bool = false
    
    var body: some View {
        let alwaysLift = colorScheme == .light
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme).opacity(colorScheme == .light ? 0.65 : 0.9), lineWidth: 1)
            )
            .shadow(
                color: (elevated || alwaysLift) ? AppTheme.softShadow(for: colorScheme) : .clear,
                radius: elevated ? 14 : (alwaysLift ? 8 : 0),
                y: elevated ? 5 : (alwaysLift ? 2 : 0)
            )
    }
}

// MARK: - Shared interaction + empty states

/// Soft hover / press for list rows and sidebar-like buttons.
struct SoftHoverButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 10
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        configuration.isPressed
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
                        : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Unified empty / zero-data surface.
struct AppEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.16),
                                AppTheme.accent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(SoftScaleButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct PageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = AppTheme.accent
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
