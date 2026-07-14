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

enum UIDensity: String, CaseIterable, Identifiable {
    case comfortable
    case compact
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .comfortable: return "舒适"
        case .compact: return "紧凑"
        }
    }
    
    /// Multiplier for paddings / fonts that opt in.
    var scale: CGFloat {
        switch self {
        case .comfortable: return 1.0
        case .compact: return 0.88
        }
    }
    
    var sectionSpacing: CGFloat {
        switch self {
        case .comfortable: return 16
        case .compact: return 10
        }
    }
    
    var cardPadding: CGFloat {
        switch self {
        case .comfortable: return 16
        case .compact: return 12
        }
    }
    
    var rowVerticalPadding: CGFloat {
        switch self {
        case .comfortable: return 12
        case .compact: return 8
        }
    }
    
    var titleFontSize: CGFloat {
        switch self {
        case .comfortable: return 28
        case .compact: return 24
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
    
    // Quiet-tool spacing / radius tokens (prefer these over one-off values).
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    
    /// Shared card radius — analytics / settings / profile / list stats all use this.
    static let cornerRadiusCard: CGFloat = 15
    static let cornerRadiusControl: CGFloat = 10
    static let cornerRadiusRow: CGFloat = 12
    
    // Backgrounds — cooler, flatter canvas (less “toy”, more tool)
    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F0F0F2") : Color(hex: "#111113")
    }
    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#E8E8EC") : Color(hex: "#141416")
    }
    static func sidebarTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.10) : Color.black.opacity(0.12)
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
        colorScheme == .light ? Color(hex: "#F0F0F2") : Color(hex: "#0F0F11")
    }
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        // Dark cards slightly lifted from canvas for quiet depth
        colorScheme == .light ? Color.white : Color(hex: "#1A1A1E")
    }
    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F5F5F7") : Color(hex: "#25252A")
    }
    
    // Text — calm contrast; dark mode secondary slightly brighter for readability
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "1A1A1E") : Color.white.opacity(0.93)
    }
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "6B6B73") : Color(hex: "A0A0A8")
    }
    
    // Separators / overlays
    static func separator(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.07) : Color.white.opacity(0.09)
    }
    static func separatorLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.045) : Color.white.opacity(0.055)
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
        // Barely-there elevation — polish without “floating dashboard”
        colorScheme == .light ? Color.black.opacity(0.03) : Color.black.opacity(0.22)
    }
    
    static var windowBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? NSColor(white: 0.94, alpha: 1.0) : NSColor(white: 0.067, alpha: 1.0)
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
    
    /// Narrow rail still needs room under the three window buttons (~14×3 + gaps).
    static let collapsedSidebarTopInset: CGFloat = 52
    
    /// Must fit close + miniaturize + zoom with padding (was 64 → green sat past divider).
    static let collapsedSidebarWidth: CGFloat = 80
    
    /// Traffic-light inset matching Gemini / Electron `titleBarStyle: hiddenInset`
    /// (comfortably clear of the rounded window corner) when the sidebar is expanded.
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
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
            .shadow(
                color: elevated ? AppTheme.softShadow(for: colorScheme) : .clear,
                radius: elevated ? 10 : 0,
                y: elevated ? 3 : 0
            )
    }
}

// MARK: - Shared interaction + empty states

/// Soft hover / press for list rows and sidebar-like buttons.
/// Hover wash only — no scale-on-hover (quiet tool).
struct SoftHoverButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        SoftHoverButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            colorScheme: colorScheme
        )
    }
}

struct SoftHoverButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme
    @State private var hovering = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }

    private var fillColor: Color {
        if configuration.isPressed {
            return AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
        }
        if hovering {
            return AppTheme.overlayLow(for: colorScheme)
        }
        return .clear
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

/// Live status dot — soft radial pulse only when active **and** decorative motion is on.
struct PulseDot: View {
    let color: Color
    var isActive: Bool = true
    var size: CGFloat = 7
    /// When false, shows a calm solid/glowing dot (default for quiet tool).
    var allowsPulse: Bool = false

    @State private var pulse = false

    private var shouldPulse: Bool { isActive && allowsPulse }

    var body: some View {
        ZStack {
            if shouldPulse {
                Circle()
                    .fill(color.opacity(0.38))
                    .frame(width: size * 2.6, height: size * 2.6)
                    .scaleEffect(pulse ? 1.2 : 0.7)
                    .opacity(pulse ? 0.12 : 0.5)
            }
            Circle()
                .fill(isActive ? color : color.opacity(0.32))
                .frame(width: size, height: size)
                .shadow(color: isActive ? color.opacity(0.45) : .clear, radius: shouldPulse ? 3.5 : 2.5)
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .onAppear { syncPulse() }
        .onChange(of: isActive) { _ in syncPulse() }
        .onChange(of: allowsPulse) { _ in syncPulse() }
    }

    private func syncPulse() {
        if shouldPulse {
            pulse = false
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                pulse = false
            }
        }
    }
}

/// Compact keyboard-key chrome for hints (Space / ⌘R).
struct KeyCap: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(AppTheme.elevatedBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            )
    }
}

/// Soft card hover lift for interactive surfaces.
struct SoftHoverLift: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppTheme.cornerRadiusRow
    @State private var hovering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hovering
                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.04 : 0.07)
                          : Color.clear)
                    .allowsHitTesting(false)
            )
            // Minimal hover — quiet tools don't scale rows on mouse-over.
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func softHoverLift(cornerRadius: CGFloat = AppTheme.cornerRadiusRow) -> some View {
        modifier(SoftHoverLift(cornerRadius: cornerRadius))
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
    /// Compact for in-card voids; full for page-level empty shells.
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                if compact {
                    Circle()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                        .frame(width: 40, height: 40)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.14),
                                    AppTheme.accent.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    Image(systemName: systemImage)
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(AppTheme.accent)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            VStack(spacing: compact ? 4 : 6) {
                Text(title)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(compact ? .caption : .subheadline)
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
        .padding(.vertical, compact ? 16 : 28)
    }
}

struct PageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.windowLayout) private var windowLayout
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = AppTheme.accent
    
    var body: some View {
        let density = settings.uiDensity
        // Continuous: density preference × window fluid (never stuck “compact forever”).
        let titleSize = max(20, min(30, windowLayout.pageTitleSize))
        let iconBox = 30 * density.scale + windowLayout.eased * 6
        HStack(alignment: .center, spacing: 10 * density.scale + windowLayout.eased * 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: iconBox * 0.48, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: iconBox, height: iconBox)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.elevatedBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(windowLayout.height < 740 ? .caption : .subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.16), value: windowLayout.scale)
    }
}
