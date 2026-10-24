# iFocus 架构总览

- **状态**：当前状态（current-state）
- **日期**：2026-10-24
- **范围**：`Sources/iFocus`（可执行 App）、`Sources/iFocusCore`（纯逻辑库）、本地持久化与应用运行时的 macOS 集成；不包含发布流水线和 UI 视觉规范细节。
- **受众**：后续维护者、评审者、需要安全改动这个仓库的 AI 代理。
- **证据强度**：模块依赖和持久化路径直接来自代码（高）；窗口/组件分组是从目录和视图组合推导出的逻辑边界（中）；自动化客户端（Shortcuts/Alfred/脚本）是已设计的集成方式，具体客户端由用户决定（中）。

## 系统边界

iFocus 是一个单进程、本地优先的 macOS 专注/番茄钟应用：

- SwiftUI 负责界面，AppKit 负责窗口 chrome、工具栏、菜单栏、窗口状态和系统集成。
- 数据只落在本机：`~/Library/Application Support/iFocus/*.json`、`UserDefaults` 和用户选择的备份文件夹。`~/StudyLog` 的写出代码还在，但现在的应用启动时不传目录，所以不会再生成或更新那个文件夹。
- 没有网络客户端、账号、云端同步或第三方运行时依赖；任务里的 `http(s)` 链接只是文本，不会被抓取。
- `iFocusCore` 是只依赖 Foundation 的纯逻辑层，可脱离 AppKit/SwiftUI 测试。

## 阅读顺序

1. [C4 系统上下文/容器/组件 DSL](ifocus.structurizr.dsl) — 结构主模型。
2. [数据流 DOT](ifocus-data-flow.dot) — 从用户操作到文件、通知和系统设置的运行时流向。
3. [模块分层 DOT](ifocus-modules.dot) — 代码目录级依赖与跨层引用。
4. [证据索引](ifocus.evidence.md) — 节点/关系对应的源码位置、假设和未知项。

## C4 模型摘要

### L1 · 系统上下文

- **用户**：计划任务、开始专注、修改偏好。
- **iFocus**：专注计时、任务清单、统计、个人资料、数据备份。
- **macOS 集成服务**：通知中心、登录项、Finder、系统设置、菜单栏宿主与 Dock。
- **自动化客户端**：通过 `ifocus://` 触发开始/暂停/跳过/打开页面等动作；`Shortcuts/Alfred/脚本` 是设计入口，不证明用户实际安装了某个客户端。
- 用户还需要在系统设置里批准通知和登录项；iFocus 只发请求/打开设置，不代替系统开关。

### L2 · 容器

| 容器 | 职责 | 技术 |
| --- | --- | --- |
| iFocus App | 单进程应用：主窗口、设置窗口、菜单栏、状态层和本地服务 | Swift, SwiftUI, AppKit |
| Local Data Files | 任务、专注记录、当前任务、可恢复计时快照 | JSON |
| Preferences | 设置偏好与窗口布局 | UserDefaults |
| Study Log Export | 旧的可读镜像。写出器仍在，正式应用不再调用，已有的 `~/StudyLog` 文件会留在原地 | CSV, Markdown |
| Backup Packages | 用户选择的备份文件夹：数据 JSON + 设置 + 头像 + manifest | JSON |

> C4 的“容器”通常指可独立部署的单元。这里是单进程桌面应用，因此 App 是唯一的运行容器；数据文件/偏好/镜像按数据容器建模，主窗口、设置窗口和菜单栏在组件视图中展开。

### L3 · App 内部组件

| 组件 | 职责 | 关键证据 |
| --- | --- | --- |
| App Shell & Navigation | App 生命周期、窗口 chrome、工具栏安装、菜单命令、深链路由、页面枚举 | `App/iFocusApp.swift`, `App/Navigation/AppScreen.swift`, `DeepLinkRouter.swift`, `AppNavigation.swift` |
| Auxiliary Windows | 窗口状态、迷你计时窗、全屏专注 | `App/Windows/WindowStateModel.swift`, `WindowLayoutStore.swift`, `FloatingTimerWindowController.swift`, `FocusModeController.swift` |
| Main Window UI | 侧栏 + 专注钟 / 任务 / 数据统计 / 个人资料；原生侧栏切换工具栏 | `Views/Content/ContentView.swift`, `AppSidebar.swift`, `SidebarToolbar.swift`, `Views/Timer|Tasks|Analytics|Profile` |
| Settings Window UI | 四个偏好面板（通用、专注与计时、外观与声音、数据与备份）、原生搜索工具栏、分类管理、备份与通知 | `Views/Settings/SettingsWindowView.swift`, `SettingsWindowToolbar.swift`, `Views/Tasks/CategoryManagementView.swift` |
| Menu Bar Extra | 状态栏宿主与面板；面板是 SwiftUI，宿主是 AppKit | `App/MenuBar/MenuBarController.swift`, `Views/MenuBar/MenuBarPanelView.swift` |
| Domain Stores | TimerStore、TaskStore、SettingsStore、AnalyticsDashboardModel。任务和专注记录的字段在 `FocusTask.swift`，存取在 `TaskStore.swift`。TaskCategory 承载内置与自定义分类 | `ViewModels/Timer`, `ViewModels/Tasks`, `ViewModels/Settings`, `ViewModels/Analytics` |
| Local Services | 备份、升级前复制、登录项注册、系统设置链接。学习记录写出器还在，正式启动不再使用 | `Services/*` |
| iFocusCore | 过滤、搜索、统计、格式化、备份格式。学习计划模板和旧学习记录格式仍在，供已有数据和测试读取，界面不再调用。文件仍平铺 | `iFocusCore/*` |

## 关键数据流

### 专注计时与记录

1. 主窗口/菜单栏/深链 → `TimerStore` 的起停、跳过、重置。
2. 结束时 `TimerStore.commitSession` 调 `TaskStore.addFocusTime` 与 `logFocusSession`。
3. `TaskStore` 立即写 `focus_sessions.json`。只有传入了学习记录目录时才会再导出 CSV；正式应用不传，所以这一步现在停在 JSON。
4. 运行中/退出时 `TimerStore` 把可恢复快照写到 `timer_session.json`；下次启动 offer resume。
5. `TimerStore` 向 `UNUserNotificationCenter` 预约结束提醒，并更新 Dock 徽标。

### 任务

`TaskListView` → `TaskStore.tasks(for:)`（`iFocusCore.TaskFiltering` 过滤、`TaskSearch` 搜索）→ `tasks.json`；当前选中任务写入 `app_state.json`。

### 偏好与系统集成

`SettingsWindowView` → `SettingsStore` → `UserDefaults`；开关登录项时 `SettingsStore` → `LaunchAtLogin`（`SMAppService`）；通知状态/测试通过 `TimerStore` → 通知中心；备份通过 `DataBackupService` 读写数据文件和备份文件夹。

### 深链与导航

`ifocus://` → `AppDelegate.application(_:open:)` → `DeepLinkRouter` → `TimerStore`/`AppNavigation`；`AppNavigation` 用 NotificationCenter 驱动 `ContentView` 的页面切换和菜单命令。

## 证据、假设与未知项

**高置信**

- 包结构只有 `iFocus` 可执行目标、`iFocusCore` 纯逻辑库和测试目标：`Package.swift:8-43`。
- 本地 JSON 路径与文件名：`TaskStore.swift:602-628`、`TimerSessionSnapshot.swift:52-80`。
- `iFocusCore` 所有文件只 `import Foundation`。
- 没有网络客户端：`grep URLSession|Network|WebSocket Sources/iFocus` 无运行时代码；README 明确“本地优先”。
- 备份、登录项、通知都有明确调用点。学习记录写出器只有在传入目录时才会跑，正式启动不传。

**中置信 / 假设**

- 组件边界是按目录和 SwiftUI 组合推导的逻辑分组，不是独立部署单元。
- `Automation Clients` 只证明 URL scheme 和路由设计；不证明用户实际配置了某个 Shortcut。
- “Time Machine/其他工具读取备份文件夹”是使用场景，不是代码集成，因此在模型中没有当成已确认系统。

**未知 / 验证项**

- 通知、登录项的系统授权状态只能在用户机器上观察；仓库没有运行时遥测。
- 系统专注模式（Focus/DND）不受 iFocus 控制；应用只提示并打开系统设置。
- `LaunchAtLogin` 已归入 `Services`，`SettingsStore` 与设置 UI 都向下依赖服务层，不再从 ViewModels 反向引用 `App`。

## 如何查看

- 在 Qoder 中用 Structurizr DSL viewer 打开 `ifocus.structurizr.dsl`，可查看 SystemContext、Containers、Components 三个视图。
- 用 Graphviz DOT viewer 打开 `ifocus-data-flow.dot` 和 `ifocus-modules.dot`；两个文件都是 `rankdir=TB`，适合纵向浏览。
- 如果本机安装了 Graphviz，可自行导出 SVG/PNG：

```sh
dot -Tsvg Docs/Architecture/ifocus-data-flow.dot -o /tmp/ifocus-data-flow.svg
dot -Tsvg Docs/Architecture/ifocus-modules.dot -o /tmp/ifocus-modules.svg
```

## 维护

- `ifocus.structurizr.dsl` 是 C4 结构的 source of truth；DOT 是面向数据流和模块依赖的派生根图。
- 改动模块边界、持久化文件或系统集成时，先更新证据索引，再更新 DSL/DOT。
- 不要在聊天里内联完整图源；以这些文件为准。
