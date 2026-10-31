# Project: iFocus Apple Health & Fitness Style Statistics Redesign

## Architecture
- **Framework & Deployment Target**: macOS 13.0+, Swift 5.9+, SwiftUI, Swift Charts.
- **Data Layer**:
  - `TaskStore` (`Sources/iFocus/ViewModels/Tasks/TaskStore.swift`): In-memory published state for `FocusSession` and `FocusTask`. Disk storage strictly in `tasks.json`, `focus_sessions.json`, `app_state.json`. Zero disk schema modifications.
  - `FocusStats` (`Sources/iFocusCore/FocusStats.swift`): Pure algorithms computing total duration, pomodoros, streaks, peak hours, daily averages, and heatmap grids.
  - `AnalyticsDashboardModel` (`Sources/iFocus/ViewModels/Tasks/AnalyticsDashboardModel.swift`): Aggregates live session data and calculates range totals.
- **View Layer**:
  - `AnalyticsView` (`Sources/iFocus/Views/Analytics/AnalyticsView.swift`): Main container page for "我的记录".
  - `AnalyticsCards.swift` (`Sources/iFocus/Views/Analytics/AnalyticsCards.swift`): Top Apple Fitness master dashboard (`achievementHero`) with concentric dual rings and 3 monospaced metrics.
  - `AnalyticsCharts.swift` (`Sources/iFocus/Views/Analytics/AnalyticsCharts.swift`): Trend bar chart (`WeeklyFocusChart`) with Swift Charts, rounded bars, soft gridlines, and hover capsule tooltip overlay.
  - `ProfileHeatmapCard.swift` (`Sources/iFocus/Views/Profile/ProfileHeatmapCard.swift`): Annual activity heatmap with Squircle continuous smooth curves, 5-step Accent color breathing ladder, and date/duration tooltip.
  - `ProfileInsightsCard.swift` (`Sources/iFocus/Views/Profile/ProfileInsightsCard.swift`): 2x2 symmetric pure-flat micro metric tiles with unified Accent icons and monospaced digits.
- **Design Tokens**:
  - `AppTheme.swift` (`Sources/iFocus/Theme/AppTheme.swift`): `AppTheme.accent`, `AppTheme.squircle(radius:)`, `AppTheme.separatorLow`, `AppTheme.springInteractive`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 一体化大看板布局 | 消除多重卡片嵌套与割裂感，Avatar、用户名与看板统一无缝集成 | M1 | R1 |
| 2 | 高阶同心双圆环 | 极细番茄环+时长环，当前主题 Accent 色层级渐变并具备优雅呼吸动画 | M1 | R1 |
| 3 | 3大等宽指标看板 | 专注时长、达成番茄、连续天数采用大号等宽数字并列排布 | M1 | R1 |
| 4 | 纯色圆角趋势柱状图 | 全平纯色圆角柱体（当前主题 Accent 色），柔和清淡背景水平刻度线 | M2 | R2 |
| 5 | 平滑悬停微胶囊 Tooltip | 鼠标悬停柱体展示微型胶囊浮层（格式如 `10月28日 · 2小时15分 · 5个番茄`） | M2 | R2 |
| 6 | 时间跨度胶囊切换 | 支持今天、7天、30天、本月无缝切换，数据联动平滑响应 | M2 | R2 |
| 7 | Squircle 连续平滑圆角热力图 | 热力图单元格采用苹果经典 Squircle 平滑圆角 | M3 | R3 |
| 8 | 4 档纯净 Accent 呼吸色阶 | 统一由当前 Accent 色构建 0 / 25% / 50% / 75% / 100% 梯级 | M3 | R3 |
| 9 | 热力图日期与打卡浮层 | 悬停日期方块精准浮动展示对应日期与打卡专注时长 | M3 | R3 |
| 10 | 2x2 对称微磁贴布局 | 纯平 2x2 对称布局展示单次最长、日均专注、黄金时段与任务完成率 | M4 | R4 |
| 11 | 统一主题色微图标与等宽大字 | 剔除彩虹色图标与生硬分割线，使用统一主题微图标与清晰等宽大字号 | M4 | R4 |
| 12 | TaskStore 零破坏持久化 | 保持 `FocusTask` 与 `FocusSession` 现有磁盘存储模型 100% 向前兼容 | M5 | R5 |
| 13 | 零外部依赖引入 | 不在 `Package.swift` 中引入任何外部第三方依赖 | M5 | R5 |
| 14 | 统计与格式化单元测试集 | 新增针对双圆环、趋势微胶囊数据聚合、热力图色阶与磁贴计算的自动化测试 | M5 | R5 |
| 15 | 现有 367 项全量测试 100% 绿灯 | `swift test` 保证全部现有与新增测试通过（0 failures, 0 errors） | M5 | R5 |
| 16 | 自动化编译打包与安装验证 | 执行 `./Scripts/package_app.sh` 编译打包并安装至 `/Applications/iFocus.app` | M5 | R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | 顶部 Apple Fitness 核心指标大看板 | 重构 `AnalyticsCards.swift` 中的 `achievementHero`，实现极细高阶同心双圆环呼吸动画及 3 大等宽数字看板 | none | DONE |
| M2 | Apple Health 交互级趋势柱状图 | 重构 `AnalyticsCharts.swift` 中的 `WeeklyFocusChart`，实现纯色圆角柱、柔和水平刻度、悬停胶囊微气泡 Tooltip 及时间跨度无缝联动 | M1 | DONE |
| M3 | Squircle 平滑圆角与呼吸色阶年度热力图 | 重构 `ProfileHeatmapCard.swift`，实现 Squircle 连续平滑圆角、Accent 0/25/50/75/100% 呼吸色阶及精准悬停气泡 | none | DONE |
| M4 | 2x2 对称纯平微磁贴统计洞察 | 重构 `ProfileInsightsCard.swift`，实现 2x2 对称微磁贴、统一主题微图标、黄金时段文案与等宽大字号 | none | DONE |
| M5 | 自动化测试套件验收、全量回归与打包发布 | 编写新增单元测试（涵盖格式化、趋势聚合与色阶），运行 `swift test`（367+ 项 100% 绿灯），执行 `./Scripts/package_app.sh` 安装至 `/Applications/iFocus.app` | M1, M2, M3, M4 | DONE |

## Interface Contracts
### M1: ConcentricDualRingView ↔ AnalyticsCards
- **Props**:
  - `pomodoroProgress: Double` (0.0 ... 1.0+)
  - `durationProgress: Double` (0.0 ... 1.0+)
  - `accentColor: Color`
  - `ringSize: CGFloat` (default ~100-110pt)
  - `lineWidth: CGFloat` (极细高阶 ~6-7pt)
- **Output**: Concentric dual circular rings with breathing animation.

### M2: Chart Day Data Model ↔ Hover Tooltip
- **Data**:
  - `DayFocus` in `AnalyticsCharts.swift`: `date: Date`, `label: String`, `minutes: Int`, `pomodoros: Int`
- **Tooltip string generator**:
  - Format: `M月d日 · H小时m分 · N个番茄` (or `m分 · N个番茄` when duration < 60 mins).
- **Interaction**:
  - macOS 13 compatible: `.chartOverlay` with `ChartProxy.value(atX:as: Date.self)` & `.onContinuousHover`.

### M3: Heatmap Cell Model ↔ Squircle Cell & Floating Tooltip
- **Props**:
  - `level: Int` (0, 1, 2, 3, 4)
  - `accentColor: Color`
  - `date: Date`, `minutes: Int`
- **Shape**:
  - `AppTheme.squircle(radius: 2.8)`
- **Color ladder**:
  - Level 0: `AppTheme.separatorLow.opacity(0.35)`
  - Level 1: `accentColor.opacity(0.25)`
  - Level 2: `accentColor.opacity(0.50)`
  - Level 3: `accentColor.opacity(0.75)`
  - Level 4: `accentColor` (1.0)

### M4: Metric Tile Model ↔ 2x2 Grid
- **Tiles**:
  - Tile 1: "单次最长" (`maxSingleFocusSession`) — SF Symbol `stopwatch` (or `flame.fill`)
  - Tile 2: "日均专注" (`averageDailyLabel`) — SF Symbol `clock.fill`
  - Tile 3: "黄金时段" (`peakFocusHoursString`) — SF Symbol `sun.max.fill`
  - Tile 4: "任务完成率" (`completionRate`) — SF Symbol `checkmark.circle.fill`
- **Color**:
  - Uniform `AppTheme.accent` with soft background `AppTheme.accent.opacity(0.08)`.

## Code Layout
- `Sources/iFocus/Views/Analytics/AnalyticsCards.swift` (M1: Hero dual rings & monospaced stats)
- `Sources/iFocus/Views/Analytics/AnalyticsCharts.swift` (M2: Trend chart, rounded bars, tooltip capsule)
- `Sources/iFocus/Views/Analytics/AnalyticsView.swift` (M1/M2: Integration and range chip sync if needed)
- `Sources/iFocus/Views/Profile/ProfileHeatmapCard.swift` (M3: Squircle heatmap cells, breathing palette, hover tooltip)
- `Sources/iFocus/Views/Profile/ProfileInsightsCard.swift` (M4: 2x2 symmetric metric tiles, accent icons)
- `Tests/iFocusTests/Analytics/StatisticsRedesignTests.swift` (M5 & E2E: Automated tests for metrics, formatting, hover data)
