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
- `sidebarHeader` reserves 48pt (`AppTheme.topHeaderHeight`) so nav content clears the 52pt titlebar band that holds the window buttons and the toggle.
- Verify the window corner still clips the material, since the content view sets `masksToBounds = false`. A square edge showing outside the rounded corner means the clip broke.

### The sidebar toggle is the native toolbar button

The toggle is a real `NSToolbarItem` in the window's AppKit toolbar, not a SwiftUI `ToolbarItem`. SwiftUI stretches toolbar content into AppKit's `NSToolbarPlatterView`, which measured 28×36 on this titlebar and turned the old hand-drawn circle into a portrait oval. A bordered AppKit item instead gets the platform's own 36×36 glass button, with native hover and press, using the system `sidebar.leading` glyph (18×14; `sidebar.left` is the macOS 13 fallback).

The standard `NSToolbarItem.Identifier.toggleSidebar` cannot be used: AppKit only enables it when the window has a split-view sidebar (`NSSplitViewController`). This app's sidebar is a SwiftUI column, so in a plain window the item validates as disabled. `SidebarToolbar` supplies a bordered item with the same system image and an explicit target/action that posts `AppNavigation.toggleSidebar`.

The toolbar also keeps the 52pt titlebar band alive. `SidebarToolbar.install(on:)` is idempotent and runs on appear and after fullscreen exit (the titlebar is rebuilt on the way out). `WindowChrome.apply` still drops item-less toolbars, which would take the titlebar back to 28pt.

Assigning the toolbar rebuilds the titlebar and can clear `titlebarAppearsTransparent` after the window has already become key. On first launch that left an opaque white band across the sidebar until the next key change. `SidebarToolbar.install` now reasserts only the transparent chrome flags immediately and once after the new titlebar settles; `applicationDidFinishLaunching` also runs a delayed pass for the first window. Keep that reassert when changing toolbar installation or window construction — `WindowChrome.apply` alone is not guaranteed to run after AppKit's rebuild.

The item sits immediately after the window buttons, where a toolbar's first item goes — the native position for a window without a split-view sidebar. The previous titlebar accessory put it at the sidebar's trailing edge, a position AppKit only grants windows with a real split-view sidebar. Verified on the debug build: 52pt titlebar, window buttons at (19, 19), 18×14 glyph in a 36×36 plate, item enabled, click toggles the sidebar, and the toolbar survives the SwiftUI state update.

`SidebarChrome` (same file) now owns only the fluid sidebar-width formula; the toolbar owns the control's size and position.

### Window buttons stay AppKit's own

Verified on the shipped build: 52pt titlebar, buttons at (19, 19) with 14pt sides and 23pt spacing — the system's toolbar-window geometry, which is what Mail uses on this OS. That is the native effect; do not resize or recolour them to chase the 12pt sidebar-window variant, which AppKit only grants windows it knows have a sidebar. Manual repositioning (`f3ec5d4`) was tried and reverted; the toolbar's native item position removes the need for it.

### The Settings window shares the main window's titlebar band

The Settings window also uses a 52pt native toolbar band. `SettingsWindowToolbar` installs an `NSToolbar` carrying only a flexible space — enough for AppKit to lay out the standard toolbar titlebar (52pt, window buttons at (19, 19)) without adding a visible control. The scene keeps `.hiddenTitleBar`, so the titlebar stays transparent; the sidebar material runs full-bleed under it and the window's shape clips the corner.

The previous layout inset the sidebar as an 8pt floating card. That left the traffic lights on the window canvas at (9, 9), outside the card, and the titlebar was only 32pt — the buttons looked detached from the sidebar. Full-bleed plus the toolbar band puts them on the material at the same native inset as the main window.

The Settings sidebar follows the main sidebar's source-list convention: neutral selection, no accent bar, hover fill, 7pt radius. Per-pane icon tiles keep their colours, as Settings panes do. Controls inherit `AppTheme.accent`, so prominent buttons use the user's chosen accent rather than the system blue.

### Settings search and remaining Settings gaps

Settings search is a native `NSSearchToolbarItem` in the 52pt band. It filters the four panes through a keyword set (`SettingsWindowPanel.matches`), not individual rows — enough for four panes without maintaining a second settings index. The empty state clears both the native field and the SwiftUI query.

The Settings UI also exposes 界面密度 (`uiDensity`, which the main window already used), surfaces login-item failures with a System Settings shortcut, and makes the system focus-mode hint a toggle (default on). Hidden-label controls carry accessibility labels; the sidebar supports arrow-key selection with a focus ring.

### App accent reaches stock controls

`ContentView` and the Settings window apply `tint(AppTheme.accent)` at their roots, so stock SwiftUI controls — prominent buttons, switches, segmented pickers, focus rings — follow the user's accent instead of system blue. Local `.tint` calls for destructive red or success green still win. The Find command (⌘F) routes to the Settings search field when the Settings window is key and to task search otherwise.

### Sidebar rows follow the source-list convention

Selection is a neutral fill (`black 7.5%` in light, `white 13%` in dark), with no accent tint and no border. Unselected icons use secondary text; the selected row's icon uses the accent. Counts are plain secondary text with monospaced digits, not pills. An accent fill plus a hairline accent border reads as a custom control, which is what made the sidebar look unlike Mail. Row radius is 7pt, rows are 30pt tall, section headers are 11pt semibold at 70% secondary.

### Task rows, timer states and shared tokens

Task rows now share `AppTheme.success / warning / danger / paused / violet`, `TypeScale.meta` (10pt), `TypeScale.tag` (9.5pt bold), and `AppTheme.iconBadge / iconMeta / iconAction`. Resting rows use a barely-there card surface without a shadow; hover, active and batch-selected rows add tint and elevation. Priority is a thin rail only — the old 「3 级」chip repeated it. Overdue is the word 逾期 beside the title, not a second capsule. Category colour is a 6pt dot; the name and the other metadata are secondary text. The list's filter chips wrap through `ChipFlowLayout` instead of clipping their tail behind a horizontal scroller, and empty states offer a primary plus a secondary action.

On the timer stage, today's progress is one line under the ring (`今天 2/4 · 已专注 50 分`), not a card above it. The corner control is 「进入专注」; mini timer and immersive mode live in its menu. Mode chips are a flat fill with no glow or stacked strokes, and the side controls are flat circles. The play button stays a flat accent circle, which is the one loud control. A paused session changes the ring badge to an amber「mode · 已暂停」with a pause glyph; the play control's help and accessibility label say「继续」. The current-task picker uses a stronger surface and a larger category tile so it reads as a control without competing with the ring.

### Session summary and the Settings status center

A completed work session publishes `SessionSummary` and the main window presents it as a compact sheet. A top overlay was tried first and rejected: it covered the timer goal card and let fragments peek around the card at every window size. The sheet keeps the summary readable, lets the break continue behind it, and is dismissed by starting the next segment or closing; it does not auto-dismiss.

Settings gains a fifth「状态中心」pane. It aggregates notification permission, Login Items, System Focus, local data health, backup feedback and StudyLog access, with recovery actions that stay visible after transient alerts. The pane icon carries a warning dot for a corrupt data file, denied notifications, a login item needing approval or a missing app, and a failed backup. Copy uses native Chinese terms (访达, 程序坞), and due dates read 今天 / 明天 / 昨天 or `M月d日` instead of numeric short dates.

### Menu bar panel, mini timer and full-screen focus

The status item's left click now opens a SwiftUI popover instead of toggling the timer; right-click and Control/Option-click still open the full NSMenu. The panel carries time/task, play/pause/skip, task selection, and shortcuts to the main timer, settings, mini timer and focus mode. A transient popover is used, with a short reopen guard so the click that dismisses it does not immediately reopen it.

The mini timer is a borderless, non-activating `NSPanel` at `.floating` level that joins all Spaces and full-screen spaces. Its frame is remembered in UserDefaults; the progress ring doubles as the drag handle because a borderless card has no titlebar. It is toggled by ⌥⌘M, the timer stage's 「进入专注」 menu, or the menu-bar panel.

Full-screen focus uses native full screen, hides the sidebar, forces the timer's immersive stage, dims the background, and hides the cursor until the mouse moves. It is entered with ⌥⌘F or the timer's focus button and exited with the visible「退出专注」pill, Esc, or leaving native full screen. The controller remembers whether it entered full screen itself and restores the previous immersive/sidebar state without forcing a window that was already full screen to exit.

### Task quick actions, cross-list drag and Onboarding 2.0

Task rows now expose the drag handle through `.draggable(task.id.uuidString)` and a hover-only「…」menu with 移到今天/明天/收集箱, 优先级 and 删除. The sidebar's 今天 / 明天 / 收集箱 / 已完成 rows are the drop targets; dropping a task updates its due date, clears the plan start date, and navigates to the destination list. A completed task dropped into an active list is reopened (completedAt cleared); this matches unchecking a row. The action cluster's hit testing follows hover/active, not the invisible buttons, so there is no dead clickable area at rest.

Onboarding is a five-step card (欢迎 / 专注节奏 / 今天清单 / 提醒与启动 / 开始使用) with a step rail, skip on every step, an optional sample task, notification and login-item actions, and a final three-step recap. It stays an in-window overlay rather than a sheet so the app remains visible behind it. The sample task commits once when the task step is left forward and is due today; the toggle disables after committing. Settings › 通用 › 引导与帮助 posts `AppNavigation.showOnboarding` and brings the main window forward; a pending UserDefaults flag survives closing and reopening the main window. Replay never resets `hasCompletedOnboarding` and the final button reads 完成. The app mark loads `AppIcon.icns` from `Bundle.module`, so development builds show the real icon rather than the generic process icon.

### Custom categories stay local and backward-compatible

`TaskCategory` is now a value type with a stable id, display name, colour and SF Symbol. Built-ins remain fixed (`工作 / 学习 / 生活 / 重要 / 家 / 其他`) and keep encoding as their legacy Chinese string, so tasks, sessions and snapshots written by earlier builds still decode unchanged. Custom categories encode as objects inside tasks and history; their definitions live in `app_state.json` rather than a new file, so existing backup packages and daily safety snapshots carry them without changing the backup format.

Custom names must be unique (case/diacritic-insensitive, trimmed and whitespace-collapsed), at most 12 characters, with up to 12 custom categories. Editing name/colour/icon updates every task and historical session using that id; deleting moves them to 其他 and resets the quick-add composer if needed. If `app_state.json` is missing or unreadable, custom definitions are recovered from the objects embedded in tasks/history, then written back to state. Timer snapshots store the category id, while legacy snapshots with Chinese names still resolve by name.

All pickers, chips and list menus read `TaskStore.allCategories`; category filters compare by id so a rename cannot strand the active chip, and analytics/profile group sessions by id so renamed history stays together. Built-ins deliberately cannot be edited, which keeps historical grouping stable. The category manager is one sheet shared by the task options menu, the filter-row shortcut and Settings › 通用 › 任务与分类.

### Window translucency

The window's `backgroundColor` is an opaque colour: the glass blurs what is behind it inside the window, so the sidebar reads as a solid surface rather than picking up the desktop. Making the window clear would give the native translucency, but that previously caused an unpainted strip along the inset panel's bottom edge and has not been re-evaluated since the sidebar went full-bleed.
