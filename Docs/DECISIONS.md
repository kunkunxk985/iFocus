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

