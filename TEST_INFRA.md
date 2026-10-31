# E2E Test Infrastructure: iFocus Apple Health & Fitness Style Statistics Redesign

## 1. Test Philosophy & Principles

### 1.1 Opaque-Box & Requirement-Driven
The Statistics and Records Redesign test suite is strictly opaque-box and requirement-driven, derived directly from `PROJECT.md § Feature Inventory` (Features 1–16) and `ORIGINAL_REQUEST.md` (Requirements R1–R5).
- **Zero Coupling to Private Internals**: Tests interact solely through published contracts and domain models (`AnalyticsDashboardModel`, `AnalyticsPageSnapshot`, `FocusStats`, `AnalyticsTimeRange`, `TaskStore`, `FocusSession`, `FocusTask`, `AppTheme`). Private view hierarchy `@State` variables and animation timelines are decoupled from logic validation.
- **Specification-Derived Assertions**: Every expected value is mathematically derived from product requirements, design system tokens, or explicit user agreements from the project specification:
  - Dual ring progress math: `min(1.0, completed / target)`.
  - Hover tooltip format: `M月d日 · H小时m分 · N个番茄` (or `m分 · N个番茄` when duration < 60 mins).
  - Heatmap 4-step color ladder opacities: `0 / 0.25 / 0.50 / 0.75 / 1.00`.
  - 2x2 metric tiles: `maxSingleFocusSession`, `averageDailyFocusMinutes`, `peakFocusHoursString`, `completionRate`.
- **Deterministic & Isolated**: Each test runs with a deterministic Gregorian calendar set to UTC (`TimeZone(secondsFromGMT: 0)`), provisions an isolated temporary filesystem directory (`FileManager.default.temporaryDirectory`), sets up fresh store instances, cleans up on `tearDownWithError`, and runs without order dependency or side effects.

### 1.2 Four-Tier Testing Pyramid
The test suite implements an exhaustive four-tier structure adhering to Dual Track E2E Standards:
1. **Tier 1 — Feature Coverage**: Comprehensive requirement verification for Features 1–16 in isolation (dual rings, trend aggregation, hover tooltips, date bounds, squircle heatmap, color ladder, 2x2 metric tiles, persistence, zero dependencies, performance).
2. **Tier 2 — Boundary & Corner Cases**: Stress-testing edge cases (0 minutes, negative/corrupt minutes defensive clamping, future timestamps, sessions > 24 hours, 0 tasks vs 100% completion, leap years, year boundaries, empty histories).
3. **Tier 3 — Cross-Feature Combinations**: Pairwise multi-component interactions (today range with 0 sessions vs annual heatmap with active streaks; dual ring progress with live ticking session; time range switching consistency; task completion toggle; new session appended with simultaneous updates across header, chart, heatmap, and metric tiles).
4. **Tier 4 — Real-World Application Scenarios**: Full multi-day and multi-week end-to-end user journeys (30-day productivity consistency workflow & 1-year 53-week heatmap and long-term volume stability).

---

## 2. Feature Inventory Mapping

| Feature # | Milestone | Feature Name | Requirement Contract | Test Suite Target | Tier 1 Tests |
|---|---|---|---|---|---|
| **F1** | M1 | 一体化大看板布局 | 无缝集成 Avatar、用户名、大号双圆环与三大核心指标 | `testF01_MasterDashboard_*` | 1 |
| **F2** | M1 | 高阶同心双圆环 | 极细番茄环+时长环，当前主题 Accent 色层级渐变并具备优雅呼吸动画 | `testF02_ConcentricRings_*` | 4 |
| **F3** | M1 | 3大等宽指标看板 | 专注时长、达成番茄、连续天数采用大号等宽数字对齐排布 | `testF03_MonospacedStats_*` | 1 |
| **F4** | M2 | 纯色圆角趋势柱状图 | 全平纯色圆角柱体（当前主题 Accent 色），柔和清淡背景水平刻度线 | `testF04_TrendChart_*` | 1 |
| **F5** | M2 | 平滑悬停微胶囊 Tooltip | 鼠标悬停柱体展示微型胶囊浮层（`M月d日 · H小时m分 · N个番茄`） | `testF05_HoverTooltip_*` | 4 |
| **F6** | M2 | 时间跨度胶囊切换 | 支持今天、7天、30天、本月无缝切换，数据联动平滑响应 | `testF06_DateBounds_*` | 1 |
| **F7** | M3 | Squircle 连续平滑圆角热力图 | 热力图单元格采用苹果经典 Squircle 平滑圆角（`AppTheme.squircle(radius: 2.8)`） | `testF07_SquircleHeatmap_*` | 1 |
| **F8** | M3 | 4 档纯净 Accent 呼吸色阶 | 统一由当前 Accent 色构建 0 / 25% / 50% / 75% / 100% 梯级 | `testF08_SquircleHeatmap_*` | 2 |
| **F9** | M3 | 热力图日期与打卡浮层 | 悬停日期方块精准浮动展示对应日期与打卡专注时长（`yyyy年M月d日 · N 分钟`） | `testF09_SquircleHeatmap_*` | 2 |
| **F10** | M4 | 2x2 对称微磁贴布局 | 纯平 2x2 对称布局展示单次最长、日均专注、黄金时段与任务完成率 | `testF10_MetricTiles_*` | 4 |
| **F11** | M4 | 统一主题色微图标与等宽大字 | 剔除彩虹色，使用统一主题微图标（`stopwatch`, `clock.fill`, `sun.max.fill`, `checkmark.circle.fill`） | `testF11_MetricTiles_*` | 1 |
| **F12** | M5 | TaskStore 零破坏持久化 | 保持 `FocusTask` 与 `FocusSession` 现有磁盘存储模型 100% 向前兼容 | `testF12_TaskStore_*` | 1 |
| **F13** | M5 | 零外部依赖引入 | 不在 `Package.swift` 中引入任何外部第三方依赖 | `testF13_ZeroExternalDependenciesRule` | 1 |
| **F14** | M5 | 统计与格式化单元测试集 | 新增针对双圆环、趋势微胶囊数据聚合、热力图色阶与磁贴计算的自动化测试 | `StatisticsRedesignTests.swift` | 43 |
| **F15** | M5 | 现有全量测试 100% 绿灯 | `swift test` 保证全部现有（367 项）与新增测试通过（0 failures, 0 errors） | All Suites | 410 |
| **F16** | M5 | 性能约束验证 | `AnalyticsPageSnapshot.build` @5k sessions < 220ms, heatmap < 150ms | `testF16_Performance_*` | 2 |

---

## 3. Test Architecture & Harness Design

### 3.1 Architecture Overview

```
Tests/iFocusTests/Analytics/StatisticsRedesignTests.swift
├── Design Metrics & Specification Oracle (StatisticsRedesignDesignSpec)
│   ├── Ring Dimensions & Breathing Constants (default 104pt, min 84pt, line 6.5pt, scale 1.0..1.06)
│   ├── Trend Chart & Tooltip Constants (bar corner 4pt, tooltip capsule 12pt, supported ranges)
│   ├── Squircle Heatmap & Color Ladder (squircle 2.8pt, 53 weeks x 7 days, opacities 0.045..1.00)
│   ├── 2x2 Metric Tile SF Symbols & Styling (stopwatch, clock.fill, sun.max.fill, checkmark.circle.fill)
│   └── Performance Latency Thresholds (Snapshot < 220ms, Heatmap < 150ms, MinutesByDay < 120ms)
├── Query & Mathematical Calculation Oracle (StatisticsRedesignTestHarness)
│   ├── Deterministic UTC Gregorian Calendar
│   ├── Model Factory Helpers (makeSession, makeTask, deterministic date)
│   ├── Authoritative Trend Tooltip Formatter (M月d日 · H小时m分 · N个番茄 / m分 · N个番茄)
│   ├── Authoritative Heatmap Tooltip Formatter (yyyy年M月d日 · N 分钟)
│   ├── Concentric Dual Ring Math Oracle (Today & Multi-Day Target Calculations)
│   └── Performance Latency Measurement Helper
├── Test Suites
│   ├── Tier 1: Feature Coverage (Features 1–16, 26 tests)
│   ├── Tier 2: Boundary & Corner Cases (10 tests)
│   ├── Tier 3: Cross-Feature Combinations (5 tests)
│   └── Tier 4: Real-World Application Scenarios (2 comprehensive journeys)
```

### 3.2 Design Tokens Verification
Visual and design-token contracts are tested through `StatisticsRedesignDesignSpec`, which asserts mathematical properties against `AppTheme`, `FocusStats`, and layout constants:
- Confirms concentric ring sizes (`default 104pt`, `min 84pt`, `lineWidth 6.5pt`).
- Confirms squircle curvature helper (`AppTheme.squircle(radius: 2.8)`).
- Confirms color ladder opacities (`0 / 0.25 / 0.50 / 0.75 / 1.00`).
- Confirms 2x2 metric tile SF Symbols and background opacity (`0.08`).

### 3.3 State & Store Lifecycle Verification
Session lifecycle, time ranges, and data models are tested through isolated `TaskStore` sandboxes:
- Verifies `FocusSession` and `FocusTask` JSON serialization and deserialization across store instances.
- Verifies range bounds calculation across `.today`, `.days7`, `.days30`, and `.month`.
- Verifies live session ticking accumulation on top of historical records.
- Verifies task completion rate calculation without side effects.

---

## 4. Tier 4 Real-World Application Scenarios

The suite includes two comprehensive end-to-end integration scenarios representing realistic user histories:

1. **Scenario 1 — 30-Day Full User Journey (`testTier4_ThirtyDayUserJourney_ProductivityConsistencyAcrossAllWidgets`)**:
   - Synthesizes 30 days of user activity with realistic workday patterns (4 pomodoros / 100 mins), weekend patterns (1 pomodoro / 25 mins), and vacation gaps (0 pomodoros).
   - Validates data consistency across all 4 widgets simultaneously:
     - Header ring progress against 30-day target (`dailyGoal * 30`).
     - Trend bar chart aggregation matching range total minutes and pomodoros.
     - Heatmap active day count matching exactly the active days in the 30-day period.
     - 2x2 metric tiles correctly calculating `maxSingleFocusSession` (90 mins), task completion rate (75%), and average daily focus.

2. **Scenario 2 — 1-Year Full Annual Journey (`testTier4_OneYearFullJourney_HeatmapAndLongTermStats`)**:
   - Simulates 53 weeks (365 days) with 1,200+ sessions across different months.
   - Verifies 53 columns × 7 rows grid structure (371 cells) with correct weekday alignment.
   - Verifies month labels generation at column transitions.
   - Verifies golden time "黄金时段" modal hour detection under high volume.
   - Verifies TaskStore disk persistence and reload fidelity with 1,200+ sessions without data loss.

---

## 5. Coverage & Verification Thresholds

| Metric | Threshold | Method of Verification |
|---|---|---|
| **Tier 1 Feature Coverage** | 100% of Features 1–16 | `StatisticsRedesignTests.swift` (26 tests) |
| **Tier 2 Boundary Cases** | >= 10 edge case scenarios | `StatisticsRedesignTests.swift` (10 tests) |
| **Tier 3 Combinations** | >= 5 pairwise cross-feature tests | `StatisticsRedesignTests.swift` (5 tests) |
| **Tier 4 Workflows** | 2 comprehensive real-world scenarios | `StatisticsRedesignTests.swift` (2 tests) |
| **Total Redesign Tests** | 43 new test cases | `swift test --filter StatisticsRedesignTests` |
| **Baseline Regression** | 367 / 367 existing tests pass (0 failures) | `swift test` execution output |
| **Total Passing Tests** | 410 / 410 tests passed (100% green) | `swift test` execution output |
| **Performance Benchmark** | `AnalyticsPageSnapshot.build @5k < 220ms` | Executed at ~29ms in benchmark test |
| **Dependency Rule** | 0 external third-party packages | Asserted via `Package.swift` parsing test |
