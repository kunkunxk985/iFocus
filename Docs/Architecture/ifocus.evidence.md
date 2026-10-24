# iFocus Architecture Evidence

- **Source ref policy**: repo-relative paths with line ranges; links resolve in the working tree.
- **State**: current state, 2026-10-22.
- **Confidence**: `high` = direct code/config evidence; `medium` = multiple signals or logical grouping; `low` = inferred; `unknown` = runtime/user-specific.

## Node evidence

| ID | Type | State | Confidence | Sources | Notes |
| --- | --- | --- | --- | --- | --- |
| `user` | actor | current | high | `README.md:1-3`, `ContentView.swift:3-80` | The person using the app. |
| `automation` | external system | current (integration) | medium | `DeepLinkRouter.swift:1-120`, `Scripts/package_app.sh:96-106` | URL scheme `ifocus://` is registered; actual Shortcuts/Alfred clients are user-defined. |
| `macos` | external system | current | high | `TimerStore.swift:1218-1340`, `LaunchAtLogin.swift:1-70`, `SettingsStore.swift:386-400`, `MenuBarController.swift:73-100` | Notifications, Login Items, Finder/System Settings URLs, menu-bar hosting and Dock. |
| `ifocus` | software system | current | high | `Package.swift:8-43`, `README.md:1-3` | Single executable + pure core library. |
| `ifocus.app` | container | current | high | `iFocusApp.swift:219-379` | Single process; SwiftUI scenes plus AppKit bridges. |
| `ifocus.app.appShell` | component | current | high | `App/iFocusApp.swift`, `App/Navigation/DeepLinkRouter.swift`, `App/Navigation/AppNavigation.swift`, `App/Windows/WindowStateModel.swift` | Lifecycle, chrome, commands, deep links, auxiliary windows. |
| `ifocus.app.mainWindow` | component | current | high | `Views/Content/ContentView.swift`, `AppSidebar.swift`, `SidebarToolbar.swift`; `Views/Timer|Tasks|Analytics|Profile` | Main navigation and detail pages. |
| `ifocus.app.settingsWindow` | component | current | high | `Views/Settings/SettingsWindowView.swift:63-...`, `SettingsWindowToolbar.swift` | Preferences, search, backup/notification controls. |
| `ifocus.app.menuBar` | component | current | high | `App/MenuBar/MenuBarController.swift`, `Views/MenuBar/MenuBarPanelView.swift` | NSStatusItem host plus the SwiftUI panel. |
| `ifocus.app.stores` | component | current | high | `ViewModels/Timer/TimerStore.swift`, `ViewModels/Tasks/TaskStore.swift`, `TaskCategory.swift`, `ViewModels/Settings/SettingsStore.swift`, `ViewModels/Analytics/AnalyticsDashboardModel.swift` | Observable state, custom categories and orchestration. |
| `ifocus.app.services` | component | current | high | `Services/DataBackupService.swift`, `StudyLogWriter.swift`, `PreUpgradeGuard.swift`, `LaunchAtLogin.swift` | Local side effects and OS registration. |
| `ifocus.app.core` | component | current | high | `Sources/iFocusCore/*.swift` | All files import only Foundation. |
| `ifocus.dataFiles` | data store | current | high | `TaskStore.swift:602-628`, `TimerSessionSnapshot.swift:52-80`, `README.md:70-86` | `tasks.json`, `focus_sessions.json`, `app_state.json`, `timer_session.json`. |
| `ifocus.preferences` | data store | current | high | `SettingsStore.swift:62-105`, `WindowLayoutStore.swift:1-50` | UserDefaults keys + `mainWindowFrame`/`sidebarCollapsed`. |
| `ifocus.studyLog` | data store | legacy | high | `StudyLogWriter.swift`, `iFocusApp.swift` (`TaskStore()` with no directory) | Writer remains. The shipped app does not pass a directory, so `~/StudyLog` is not regenerated. |
| `ifocus.backups` | data store | current | high | `Services/DataBackupService.swift`, `LocalBackup.swift:1-80` | User-selected folder, manifest + JSON payloads. |

## Edge evidence

| From | To | Mechanism | Confidence | Sources |
| --- | --- | --- | --- | --- |
| `user` | `ifocus.app.mainWindow` / `settingsWindow` / `menuBar` | Direct UI interaction | high | `ContentView.swift`, `SettingsWindowView.swift`, `MenuBarController.swift` |
| `automation` | `ifocus.app.appShell` | `ifocus://` URL → AppDelegate → DeepLinkRouter | high | `iFocusApp.swift:71-76`, `DeepLinkRouter.swift:1-120`, `Scripts/package_app.sh:96-106` |
| `ifocus.app.appShell` | `mainWindow`, `settingsWindow`, `menuBar` | SwiftUI scenes/window opening/status item install | high | `iFocusApp.swift:219-379`, `MenuBarController.swift:73-100` |
| `mainWindow` | `stores` | `@EnvironmentObject` reads and actions | high | `TimerView.swift`, `TaskListView.swift`, `AnalyticsView.swift`, `ProfileView.swift` |
| `settingsWindow` | `stores` | Preferences, task counts, notification status | high | `SettingsWindowView.swift:63-...` |
| `settingsWindow` | `services` | Backup export/restore, login-item settings link | high | `SettingsWindowView.swift` data panel / login feedback; `DataBackupService.swift`; `LaunchAtLogin.swift:59-70` |
| `menuBar` | `stores` | `bindStores` observes timer/task/settings; menu actions | high | `MenuBarController.swift:247-272, 413-478` |
| `stores` | `core` | Imports and pure helper calls | high | `TimerStore.swift`, `TaskStore.swift`, `AnalyticsDashboardModel.swift`; `Sources/iFocusCore` |
| `services` | `core` | `LocalBackup`, `StudyLogExport`, `StudyPlan` | high | `DataBackupService.swift`, `StudyLogWriter.swift`; `LocalBackup.swift` |
| `stores` | `services` | `StudyLogWriter.export` only when a directory was injected; `SettingsStore.applyLaunchAtLoginPreference` → `LaunchAtLogin` | high | `TaskStore` init and `saveSessions`, `SettingsStore.applyLaunchAtLoginPreference` |
| `services` | `stores` | Backup service reads/writes stores | high | `DataBackupService.swift:15-170` |
| `stores` | `dataFiles` | `TaskStore.saveTasks/loadTasks`, `saveSessions/loadSessions`, `saveState/loadState`; `TimerSessionPersistence` | high | `TaskStore.swift:750-940, 602-628`, `TimerSessionSnapshot.swift:52-80` |
| `stores` | `preferences` | `SettingsStore` didSet → UserDefaults; `WindowLayoutStore` | high | `SettingsStore.swift:107-300`, `WindowLayoutStore.swift` |
| `services` | `dataFiles` | `PreUpgradeGuard` copies JSON; restore rewrites data files | high | `PreUpgradeGuard.swift:1-70`, `DataBackupService.swift`, `LocalBackup.swift:264-...` |
| `services` | `studyLog` | `StudyLogWriter.export` background write | high | `StudyLogWriter.swift:1-70` |
| `services` | `backups` | `DataBackupService.exportBackup` / `restoreBackup` | high | `DataBackupService.swift:1-170` |
| `stores` | `macos` | `TimerStore` schedules notifications and updates Dock badge; SettingsStore opens Finder | high | `TimerStore.swift:1218-1340`, `SettingsStore.swift:394-400` |
| `services` | `macos` | `SMAppService` registration; opens System Settings | high | `LaunchAtLogin.swift:39-70` |
| `user` | `macos` | Approves permissions / manages system Focus | medium | `TimerView.swift:205-224`, `TimerStore.swift:1320-1340` (opens Settings; user action is outside code) |

## Structural notes

- Source folders follow the component boundaries: `App/Navigation`, `App/MenuBar`, `App/Windows`, `ViewModels/Timer|Tasks|Settings|Analytics`, `Views/MenuBar`. Tests mirror those layers under `Tests/iFocusTests/{Core,Stores,Services,App,Views,Product}`. `iFocusCore` stays a flat Foundation module.


- The component boundaries are logical groupings of a single process, not independently deployable services. The UI windows/menu bar are components because they share one App container.
- `LaunchAtLogin` now lives in `Services`, so `SettingsStore` (ViewModels) and the Settings UI depend downward on the service layer instead of reaching into `App`.
- `TaskStore` (ViewModels) owns/uses `StudyLogWriter` (Services); the data flow is one-way for exports.
- The app has no network client. The only `http(s)` checks are URL validation for user-entered task links (`TaskStore.swift:93`, `EditTaskView.swift:109`), not requests.

## Unknowns / validation tasks

1. Actual notification and login-item authorization state is runtime/user-specific; the app exposes status and test actions but the repo has no telemetry.
2. No evidence of which automation clients (if any) the user has configured; the URL scheme is the supported contract.
3. System Focus/DND is user-managed; the app only prompts and opens System Settings.
4. Runtime behavior of the AppKit toolbar/search across macOS versions is verified by tests + manual probes, not by this static model.

## Validation commands

```sh
swift test --disable-sandbox
grep -R "import Foundation" Sources/iFocusCore
grep -R "URLSession\|Network\|WebSocket" Sources/iFocus
```

The architecture source files are [ifocus.structurizr.dsl](ifocus.structurizr.dsl), [ifocus-data-flow.dot](ifocus-data-flow.dot) and [ifocus-modules.dot](ifocus-modules.dot).
