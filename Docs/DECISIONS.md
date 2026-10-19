# Engineering Decisions

## macOS SDK metadata and Liquid Glass

SwiftPM can compile against a recent macOS SDK while its final link omits `-platform_version`. In that case, Mach-O `LC_BUILD_VERSION.sdk` may incorrectly match the deployment target, and macOS can select the older app appearance compatibility behavior.

The iFocus executable explicitly links with `minos 13.0` and `sdk 27.0` in `Package.swift`. Keep the minimum deployment target at macOS 13; do not raise it just to record the newer SDK. The SDK value must match the selected Xcode macOS SDK major version.

When upgrading Xcode/macOS SDK, update the SDK version in the executable target's linker settings and verify the packaged binary with:

```sh
xcrun vtool -show-build Build/iFocus.app/Contents/MacOS/iFocus
```

Expected values for the current build are `minos 13.0` and `sdk 27.0`. Do not manually recolor or resize AppKit's standard window buttons to imitate the system appearance.

## Sidebar geometry owns the window-button backdrop

The window buttons are positioned by AppKit at the standard titlebar inset and cannot be restyled. What decides how they look is the surface behind them, so the sidebar's geometry is the only real lever.

The sidebar is full-bleed: the material runs to the window's top-left corner with no leading or vertical inset and no corner radius, and the window's own rounded shape clips it. The buttons then sit on the sidebar material, the way native sidebars do.

This replaced an inset floating panel. With 8pt insets the buttons ended up perched on the panel's rounded top-left corner with roughly 5pt of clearance — visually cramped, and with the app canvas behind them instead of material. Five earlier commits oscillated between custom button sizing and restoring AppKit defaults; neither addressed the actual cause, which was where the panel started.

Constraints to keep:

- The sidebar must stay edge-to-edge at the top-left. Re-introducing an inset puts the buttons back on the corner.
- `sidebarHeader` reserves 48pt (`AppTheme.topHeaderHeight`) for the button row. Nav content starts below it.
- Verify the window corner still clips the material, since the content view sets `masksToBounds = false`. A square edge showing outside the rounded corner means the clip broke.

### The sidebar toggle sits at the sidebar's trailing edge

With the sidebar open the toggle is placed `currentSidebarWidth - 48` from the left, i.e. just short of the divider — the position Mail and Finder use. Collapsed, there is no sidebar to sit in, so it falls back to just after the window buttons.

Two earlier approaches were tried and rejected:

- **A hand-tuned spacer** (`18pt` leading + a fixed `58pt` spacer). It never lined up, because the sidebar width is fluid (208–252pt).
- **A real `ToolbarItem(placement: .navigation)`.** System-positioned, but it landed hard against the window buttons rather than at the sidebar's edge, which is not the layout being matched.

The toggle uses `glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Circle())` on macOS 26 and a hand-mixed circular plate before that. The white tint is load-bearing: untinted glass reads *darker* than a dark sidebar, while a toolbar plate in system apps reads lighter. The glyph is `sidebar.left` with `.hierarchical` rendering, which fills the leading panel the way Mail's does.

### Window buttons sit where the compact titlebar puts them

`.windowStyle(.hiddenTitleBar)` compacts the titlebar, so the window buttons land closer to the top-left corner than in a standard titlebar window. Measured from the rendered window: the first button starts 9pt from the left edge with a standard titlebar and about 7pt with `.hiddenTitleBar`. A native window is nearer 14–17pt. That difference is not adjustable from SwiftUI.

**The two requirements conflict, and this is the crux.** With a standard titlebar the buttons sit better, but AppKit draws the titlebar *above* the content, so SwiftUI content cannot render inside it — the sidebar toggle gets clipped at the content's safe-area boundary, or disappears entirely if the row tries to ignore that boundary. With `.hiddenTitleBar` the content does reach into the titlebar, which is what lets the toggle sit level with the buttons, but the titlebar is then the compact variant.

Measured both ways:

| | first button inset | toggle beside buttons |
| --- | --- | --- |
| `.hiddenTitleBar` (current) | ~7pt | works |
| standard titlebar | 9pt | clipped or hidden |

So the current state is the deliberate choice: a working toggle beside the buttons, at the cost of a slightly tighter inset. Removing `.hiddenTitleBar` also does not reintroduce the opaque top band an earlier note claimed — that band was from an older layout, not from the titlebar itself.

If both are wanted, the remaining option is a real `NSToolbar` item, which places the control inside the titlebar at the system's own position (just after the buttons) rather than at the sidebar's trailing edge. That was tried and rejected on position, not on feasibility.

Manual repositioning of the AppKit buttons was tried in an earlier round (`f3ec5d4`) and reverted; do not retry it without a new reason.

The window's `backgroundColor` is an opaque colour: the glass blurs what is behind it inside the window, so the sidebar reads as a solid surface rather than picking up the desktop. Making the window clear would give the native translucency, but that previously caused an unpainted strip along the inset panel's bottom edge and has not been re-evaluated since the sidebar went full-bleed.

