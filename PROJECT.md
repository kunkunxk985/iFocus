# Project: iFocus Things 3 Style Floating Modal & Task Interaction Redesign

## Architecture
- **Framework & Deployment Target**: macOS 13.0+, Swift 5.9+, SwiftUI.
- **Design System & Visual Tokens Layer**:
  - `FloatingCardSurface.swift` / `AppTheme.swift`: Reusable `.floatingCardSurface(cornerRadius: 18)` container modifier with `.ultraThinMaterial`, `0.75pt` specular inner highlight stroke (`AppTheme.cardInnerHighlight`), `.multiLayerShadow(elevation: .popover)`, and `AppTheme.separatorLow` boundary.
- **View Layer**:
  - `EditProfileSheet.swift`: Upgraded floating card profile editing modal (width 350pt, cornerRadius 18 squircle, top-right `xmark` dismiss, capsule nickname input with person icon, 24pt swatches in recessed pill tray, shortcut hints `⌘↵ 保存 · Esc 取消`, safe uncommitted rollback).
  - `TaskListView.swift`: Replaces system attached `.sheet` with centered in-window `.overlay`, dimming backdrop (`Color.black.opacity(...)`), backdrop tap-to-dismiss, and top-level `onExitCommand` Esc key handling.
  - `EditTaskView.swift`: Restructured floating card task editing modal (width 460pt, cornerRadius 18 squircle, borderless 16pt rounded title input, Things 3 date capsule presets with popover DatePicker, embedded card fields for notes and URL with clickable valid links, top-right `xmark`, bottom shortcut hints).
  - `TaskRowView.swift`: 4-tier native `.contextMenu` separated by `Divider()`, flat reschedule actions, clipboard copy (`doc.on.doc`), destructive delete (`trash`), and inline note lightweight summary (first line, 12pt, 50% opacity, lineLimit(1), hover tooltip).
- **Data & Persistence Layer**:
  - `TaskStore.swift`: Zero breaking changes to `FocusTask`, `EditTaskSession`, or `tasks.json` schema.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 浮动卡片通用表面修饰器 | 提供 `.floatingCardSurface(cornerRadius: 18)`，集成 `.ultraThinMaterial`、0.75pt 镜面高光内描边、`.multiLayerShadow(elevation: .popover)` 与微边框 | M1 | R2 |
| 2 | 个人资料浮动模态卡片 | `EditProfileSheet` 升级为居中浮动 Squircle 卡片（宽 350pt，圆角 18），右上角 `xmark` 关闭，底部快捷键提示 | M1 | R2 |
| 3 | 高质感胶囊昵称输入框 | 废弃旧式 `.roundedBorder`，使用 `Capsule` 容器搭配 `person.fill` 图标、纯平文本输入、聚焦微发光与一键清空按钮 | M1 | R2 |
| 4 | 精致化头像与色盘交互 | 24pt 颜色色块嵌入内凹胶囊凹槽，弹簧选择动画，`AccentPreset` 专属悬停提示与触觉反馈 | M1 | R2 |
| 5 | 安全未提交状态回滚 | 修复遮罩/Esc/xmark 关闭时未提交头像与色盘状态泄露的问题，在取消与 `onDisappear` 中自动安全回滚 | M1 | R2 |
| 6 | 任务编辑居中浮动遮罩呈现 | `TaskListView` 废弃顶部下挂的系统 `.sheet`，采用全屏居中 `.overlay`、半透明遮罩暗色背景与遮罩点击关闭 | M2 | R1 |
| 7 | 任务编辑卡片容器与快捷键 | `EditTaskView` 采用 460pt 居中浮动 Squircle 容器、右上角 `xmark` 按钮、底部 `⌘↵ 保存 · Esc 取消` 与全局键盘响应 | M2 | R1 |
| 8 | Things 3 日期胶囊预设组 | 水平排列胶囊预设：`[ 无 ]`、`[ 今天 ]`、`[ 明天 ]`、`[ 稍后 ]`、`[ 自定义日期… ⌵ ]`，实时高亮选中项 | M2 | R1 |
| 9 | 自定义日期紧凑 Popover | 点击自定义日期胶囊展开紧凑型日历 Popover，选择日期后胶囊自动更新为对应格式化日期 | M2 | R1 |
| 10 | 无边框 16pt 粗圆体标题输入 | 左对齐纯平无边框标题输入框，采用 16pt 半粗圆体字形，自然融入卡片顶部 | M2 | R1 |
| 11 | 嵌入式卡片备注编辑区 | 多行 `TextEditor` 嵌入微卡片容器，支持占位符，支持回车换行而不触发模态框保存退出 | M2 | R1 |
| 12 | 嵌入式 URL 卡片与链接高亮 | 嵌入式 URL 卡片，合规链接以主题色高亮并提供原生可点击打开按钮（`NSWorkspace.shared.open`） | M2 | R1 |
| 13 | 4 层级原生右键上下文菜单 | `TaskRowView` 采用 `Divider()` 严格划分为 4 个层级，彻底扁平化移动操作，告别深层二级子菜单 | M3 | R3 |
| 14 | 完整上下文菜单操作联动 | Tier 1: 立即专注/编辑；Tier 2: 今天/明天/稍后/收集箱；Tier 3: 置顶/完成；Tier 4: 复制标题/删除任务 | M3 | R3 |
| 15 | 剪贴板复制与安全删除 | Tier 4 支持快速复制任务标题到 `NSPasteboard`，删除任务带 `.destructive` 警示红字与撤销提示 | M3 | R3 |
| 16 | 任务行内轻量备注摘要 | 提取备注第一有效行，在标题下方以 12pt、50% 弱透明度、`lineLimit(1)` 优雅呈现，配备悬停完整 Tooltip | M3 | R4 |
| 17 | 全量自动化测试与发布打包 | 保证现有 501 项全量测试 100% 绿灯，新增测试完备，执行 `./Scripts/package_app.sh` 顺利打包并成功安装至 `/Applications/iFocus.app` | M4 | R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | 浮动卡片表面修饰器与个人资料编辑模态框升级 (R2) | 实现 `FloatingCardSurface` 视觉修饰器，升级 `EditProfileSheet.swift` 为浮动卡片，实现胶囊输入框、精致色盘、快捷键提示与未提交状态回滚 | none | DONE |
| M2 | Things 3 风格任务编辑浮动卡片模态框 (R1) | 重构 `TaskListView.swift` 模态呈现逻辑，升级 `EditTaskView.swift` 为 460pt 浮动卡片、Things 3 日期胶囊预设组、日期 Popover、无边框标题与嵌入式备注/URL 卡片 | M1 | PLANNED |
| M3 | 任务行 4 层级原生上下文菜单与内联备注摘要 (R3 & R4) | 重构 `TaskRowView.swift`，实现 4 层级原生右键菜单（Focus/Edit、Reschedule、Status、Utility/Delete），实现标题下方 12pt 50% 不透明度内联备注首行摘要 | none | PLANNED |
| M4 | 全量测试套件验收、零回归保障与发布打包 (R5) | 运行全量单元与 E2E 自动化测试（501+ 项保持 100% 绿灯），验证无破坏性变更，执行 `./Scripts/package_app.sh && open /Applications/iFocus.app` 完成打包安装 | M1, M2, M3 | PLANNED |

## Interface Contracts
### M1: FloatingCardSurfaceModifier
- **Signature**: `View.floatingCardSurface(cornerRadius: CGFloat = 18) -> some View`
- **Behavior**:
  - Background: `.ultraThinMaterial` continuous squircle + `AppTheme.cardBackground` adaptive tint.
  - Border: 0.75pt specular inner highlight stroke (`AppTheme.cardInnerHighlight`) + 0.5pt subtle separator.
  - Shadow: `.multiLayerShadow(elevation: .popover)`.

### M2: EditTaskView & TaskListView Overlay Contract
- **State Binding**: `activeSheet: TaskListSheet?` (using `EditTaskSession`).
- **Overlay Container**: Centered `ZStack` with `Color.black.opacity(...)` backdrop and `.contentShape(Rectangle())`.
- **Keyboard Shortcuts**:
  - `⌘↵`: Save and dismiss (calls `onSave`).
  - `Esc`: Cancel and dismiss without saving.
- **Date Presets**:
  - `[ 无 ]`: `dueDate = nil`
  - `[ 今天 ]`: `dueDate = calendar.startOfDay(for: Date())`
  - `[ 明天 ]`: `dueDate = calendar.date(byAdding: .day, value: 1, to: today)`
  - `[ 稍后 ]`: `dueDate = calendar.date(byAdding: .day, value: 2, to: today)`
  - `[ 自定义日期… ⌵ ]`: Compact popover with `DatePicker("", selection: $dueDate, displayedComponents: .date)`.

### M3: TaskRowView Context Menu & Note Summary Contract
- **Context Menu Structure**:
  - Tier 1: `立即开启专注` (`bolt.fill`), `编辑任务…` (`pencil`).
  - Divider()
  - Tier 2: `今天` (`sun.max`), `明天` (`sunrise`), `稍后` (`clock`), `移入收集箱` (`tray.and.arrow.down`).
  - Divider()
  - Tier 3: `置顶 / 取消置顶` (`pin` / `pin.slash`), `标记为已完成 / 标记为未完成` (`checkmark.circle` / `circle`).
  - Divider()
  - Tier 4: `复制任务标题` (`doc.on.doc`), `删除任务` (`trash`, `role: .destructive`).
- **Inline Note Summary**:
  - Extract: First non-empty trimmed line from `task.notes`.
  - Style: `.font(.system(size: 12, weight: .regular))`, `foregroundColor(AppTheme.secondaryText.opacity(0.50))`, `lineLimit(1)`, `truncationMode(.tail)`, `.help(task.notes)`.

## Code Layout
- `Sources/iFocus/Views/DesignSystem/FloatingCardSurface.swift`: Shared floating card surface modifier and close button helper.
- `Sources/iFocus/Views/Profile/EditProfileSheet.swift`: Upgraded profile editing floating card.
- `Sources/iFocus/Views/Tasks/TaskListView.swift`: In-window overlay presentation for floating modals.
- `Sources/iFocus/Views/Tasks/EditTaskView.swift`: Things 3 floating task editor with date capsules and card fields.
- `Sources/iFocus/Views/Tasks/TaskRowView.swift`: 4-tier context menu and inline note summary.
- `Tests/iFocusTests/`: Automated unit and E2E regression tests.
