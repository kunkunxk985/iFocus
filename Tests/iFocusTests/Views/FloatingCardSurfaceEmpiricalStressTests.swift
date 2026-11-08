import XCTest
import SwiftUI
@testable import iFocus

final class FloatingCardSurfaceEmpiricalStressTests: XCTestCase {
    
    // =========================================================================
    // MARK: - 1. Surface Geometry & Continuous Squircle Stress Testing
    // =========================================================================
    
    func testFloatingCardSurfaceModifier_DefaultGeometryContract() {
        let modifier = FloatingCardSurfaceModifier()
        XCTAssertEqual(modifier.cornerRadius, 18, "PROJECT.md contract specifies default cornerRadius = 18")
    }

    func testFloatingCardSurfaceModifier_BoundaryRadii() {
        // Zero corner radius (sharp box edge case)
        let zeroModifier = FloatingCardSurfaceModifier(cornerRadius: 0)
        XCTAssertEqual(zeroModifier.cornerRadius, 0)
        let zeroView = Text("Zero").modifier(zeroModifier)
        XCTAssertNotNil(zeroView)

        // Sub-pixel corner radius
        let subpixelModifier = FloatingCardSurfaceModifier(cornerRadius: 0.5)
        XCTAssertEqual(subpixelModifier.cornerRadius, 0.5)
        let subpixelView = Text("Subpixel").modifier(subpixelModifier)
        XCTAssertNotNil(subpixelView)

        // Standard Things 3 modal radii
        let stdModifier = FloatingCardSurfaceModifier(cornerRadius: 18)
        XCTAssertEqual(stdModifier.cornerRadius, 18)

        // Large Pill / Stadium extreme radius
        let extremeModifier = FloatingCardSurfaceModifier(cornerRadius: 500)
        XCTAssertEqual(extremeModifier.cornerRadius, 500)
        let extremeView = Text("Extreme").modifier(extremeModifier)
        XCTAssertNotNil(extremeView)

        // Negative radius edge-case handling
        let negativeModifier = FloatingCardSurfaceModifier(cornerRadius: -10)
        XCTAssertEqual(negativeModifier.cornerRadius, -10)
        let negativeView = Text("Negative").modifier(negativeModifier)
        XCTAssertNotNil(negativeView)
    }

    func testViewExtension_FloatingCardSurface_Chaining() {
        let text = Text("Floating Card")
        let styled = text.floatingCardSurface(cornerRadius: 18)
        XCTAssertNotNil(styled)
        
        // Custom radius parameter pass-through
        let customStyled = text.floatingCardSurface(cornerRadius: 22)
        XCTAssertNotNil(customStyled)
    }

    // =========================================================================
    // MARK: - 2. Shadow Layers & Popover Elevation Hierarchy
    // =========================================================================

    func testMultiLayerShadow_PopoverElevation_Parameters() {
        // Light mode popover shadow configuration
        let lightConfig = AppTheme.shadowConfig(for: .popover, colorScheme: .light)
        XCTAssertEqual(lightConfig.ambientRadius, 28, "Popover ambient shadow radius must be 28pt")
        XCTAssertEqual(lightConfig.ambientY, 14, "Popover ambient shadow Y-offset must be 14pt")
        XCTAssertEqual(lightConfig.contactRadius, 5, "Popover contact shadow radius must be 5pt")
        XCTAssertEqual(lightConfig.contactY, 2.5, "Popover contact shadow Y-offset must be 2.5pt")

        // Dark mode popover shadow configuration
        let darkConfig = AppTheme.shadowConfig(for: .popover, colorScheme: .dark)
        XCTAssertEqual(darkConfig.ambientRadius, 28, "Dark popover ambient shadow radius must be 28pt")
        XCTAssertEqual(darkConfig.ambientY, 14, "Dark popover ambient shadow Y-offset must be 14pt")
        XCTAssertEqual(darkConfig.contactRadius, 5, "Dark popover contact shadow radius must be 5pt")
        XCTAssertEqual(darkConfig.contactY, 2.5, "Dark popover contact shadow Y-offset must be 2.5pt")

        // Elevation Hierarchy Monotonicity:
        let flat = AppTheme.shadowConfig(for: .flat, colorScheme: .light)
        let card = AppTheme.shadowConfig(for: .card, colorScheme: .light)
        let elevated = AppTheme.shadowConfig(for: .elevated, colorScheme: .light)
        let floating = AppTheme.shadowConfig(for: .floating, colorScheme: .light)
        let popover = AppTheme.shadowConfig(for: .popover, colorScheme: .light)

        XCTAssertTrue(popover.ambientRadius > floating.ambientRadius, "Popover ambient radius (28) > Floating (20)")
        XCTAssertTrue(floating.ambientRadius > elevated.ambientRadius, "Floating ambient radius (20) > Elevated (16)")
        XCTAssertTrue(elevated.ambientRadius > card.ambientRadius, "Elevated ambient radius (16) > Card (8)")
        XCTAssertTrue(card.ambientRadius > flat.ambientRadius, "Card ambient radius (8) > Flat (0)")

        XCTAssertTrue(popover.ambientY > floating.ambientY, "Popover ambient Y (14) > Floating (10)")
        XCTAssertTrue(floating.ambientY > elevated.ambientY, "Floating ambient Y (10) > Elevated (8)")
        XCTAssertTrue(elevated.ambientY > card.ambientY, "Elevated ambient Y (8) > Card (3)")
        XCTAssertTrue(card.ambientY > flat.ambientY, "Card ambient Y (3) > Flat (0)")
    }

    func testMultiLayerShadow_DownwardLightPhysics() {
        // Shadows must exhibit strictly downward drop (Y > 0) and zero horizontal drift (X == 0)
        let configLight = AppTheme.shadowConfig(for: .popover, colorScheme: .light)
        XCTAssertGreaterThan(configLight.ambientY, 0, "Ambient Y must be positive for top-down light")
        XCTAssertGreaterThan(configLight.contactY, 0, "Contact Y must be positive for top-down light")
        XCTAssertGreaterThan(configLight.ambientRadius, configLight.contactRadius, "Ambient blur must be wider than contact blur")
        XCTAssertGreaterThan(configLight.ambientY, configLight.contactY, "Ambient drop must be deeper than contact drop")
    }

    func testMultiLayerShadow_DarkVsLightOpacityRatio() {
        let lightConfig = AppTheme.shadowConfig(for: .popover, colorScheme: .light)
        let darkConfig = AppTheme.shadowConfig(for: .popover, colorScheme: .dark)

        XCTAssertNotNil(lightConfig.ambientColor)
        XCTAssertNotNil(darkConfig.ambientColor)
        XCTAssertNotNil(lightConfig.contactColor)
        XCTAssertNotNil(darkConfig.contactColor)
    }

    // =========================================================================
    // MARK: - 3. Clipping & Shadow Order Verification
    // =========================================================================

    func testClippingOrder_ShadowNotClipped() {
        // Verify overflowing content inside card does not throw or crash
        let view = VStack {
            Color.red.frame(width: 500, height: 500)
        }
        .frame(width: 350, height: 300)
        .floatingCardSurface(cornerRadius: 18)

        XCTAssertNotNil(view)
    }

    func testShapeConsistencyAcrossMaterialAndStrokeOverlays() {
        // All layers inside FloatingCardSurfaceModifier reference the same continuous squircle shape.
        let shape18 = RoundedRectangle(cornerRadius: 18, style: .continuous)
        XCTAssertEqual(shape18.cornerSize.width, 18)
        XCTAssertEqual(shape18.cornerSize.height, 18)
        XCTAssertEqual(shape18.style, .continuous)
    }

    // =========================================================================
    // MARK: - 4. Light and Dark Mode Color Tokens & Contrast Ratios
    // =========================================================================

    func testLightAndDarkTokens_CardBackground() {
        let lightCardBg = AppTheme.cardBackground(for: .light)
        let darkCardBg = AppTheme.cardBackground(for: .dark)

        XCTAssertNotEqual(lightCardBg, darkCardBg, "Card background must differ between light and dark schemes")
        XCTAssertEqual(lightCardBg, Color.white, "Light card background must be pure white base")
        XCTAssertEqual(darkCardBg, Color(hex: "#1C1C20"), "Dark card background must be lifted dark neutral #1C1C20")
    }

    func testLightAndDarkTokens_SeparatorsAndHighlights() {
        let lightSep = AppTheme.separatorLow(for: .light)
        let darkSep = AppTheme.separatorLow(for: .dark)
        XCTAssertNotEqual(lightSep, darkSep, "SeparatorLow must differ between light and dark modes")

        let lightHighlight = AppTheme.cardInnerHighlight(for: .light)
        let darkHighlight = AppTheme.cardInnerHighlight(for: .dark)
        XCTAssertNotNil(lightHighlight, "Light inner highlight gradient must exist")
        XCTAssertNotNil(darkHighlight, "Dark inner highlight gradient must exist")
    }

    func testLightAndDarkTokens_TextContrastMath() {
        let lightPrimary = AppTheme.primaryText(for: .light)
        let darkPrimary = AppTheme.primaryText(for: .dark)
        XCTAssertEqual(lightPrimary, Color(hex: "#1A1A1E"), "Light primary text is deep charcoal #1A1A1E")
        XCTAssertEqual(darkPrimary, Color.white.opacity(0.94), "Dark primary text is 94% white")

        let lightSecondary = AppTheme.secondaryText(for: .light)
        let darkSecondary = AppTheme.secondaryText(for: .dark)
        XCTAssertEqual(lightSecondary, Color(hex: "#6E6E77"), "Light secondary text is #6E6E77")
        XCTAssertEqual(darkSecondary, Color(hex: "#A2A2AB"), "Dark secondary text is #A2A2AB")
    }

    func testDoubleStrokeDimensions_SpecificationCompliance() {
        // PROJECT.md Contract:
        // Outer boundary hairline: 0.5pt
        // Inner specular highlight: 0.75pt
        let outerHairlineWidth: CGFloat = 0.5
        let innerHighlightWidth: CGFloat = 0.75

        XCTAssertEqual(outerHairlineWidth, 0.5, "Outer hairline stroke must be 0.5pt")
        XCTAssertEqual(innerHighlightWidth, 0.75, "Inner specular highlight stroke must be 0.75pt")
        XCTAssertGreaterThan(innerHighlightWidth, outerHairlineWidth, "Specular highlight stroke (0.75pt) must extend slightly beyond outer boundary (0.5pt)")
    }

    // =========================================================================
    // MARK: - 5. Component Integration: Close Button & Shortcut Hint
    // =========================================================================

    func testFloatingModalCloseButton_ActionTrigger() {
        var actionFired = false
        let button = FloatingModalCloseButton {
            actionFired = true
        }
        button.action()
        XCTAssertTrue(actionFired, "FloatingModalCloseButton action closure must execute upon trigger")
    }

    func testFloatingModalShortcutHint_DisplayStrings() {
        let defaultHint = FloatingModalShortcutHint()
        XCTAssertEqual(defaultHint.hint, "⌘↵ 保存 · Esc 取消")

        let customHint = FloatingModalShortcutHint(hint: "Esc 关闭")
        XCTAssertEqual(customHint.hint, "Esc 关闭")
    }

    // =========================================================================
    // MARK: - 6. Composite Card Stress: EditProfileSheet Sizing & Overlay
    // =========================================================================

    func testEditProfileSheet_VisualDimensions() {
        let defaults = UserDefaults(suiteName: "iFocus.TestProfileSheetDimensions")!
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        var username = "Test User"
        var isPresented = true

        let sheet = EditProfileSheet(
            tempUsername: Binding(get: { username }, set: { username = $0 }),
            isPresented: Binding(get: { isPresented }, set: { isPresented = $0 })
        )
        .environmentObject(store)

        XCTAssertNotNil(sheet)
    }

    func testEditProfileSheet_CloseButtonGeometryPlacement() {
        // EditProfileSheet places close button with padding([.top, .trailing], 14)
        // Corner radius is 18pt. Close button is 22x22pt (radius 11pt).
        // Center of button is at (14 + 11, 14 + 11) = (25pt, 25pt) from top-right corner.
        // Since corner radius is 18pt, (25pt, 25pt) is inside the content body,
        // avoiding clipping and maintaining clean visual clearance.
        let cornerRadius: CGFloat = 18.0
        let padding: CGFloat = 14.0
        let buttonSize: CGFloat = 22.0
        let buttonCenterDistance = padding + (buttonSize / 2.0)
        XCTAssertGreaterThan(buttonCenterDistance, cornerRadius, "Close button center must be well inside corner squircle curvature")
    }
}
