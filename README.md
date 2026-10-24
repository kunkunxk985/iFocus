# iFocus

macOS 专注 / 番茄钟应用（SwiftUI + AppKit，Swift Package Manager）。

| 项 | 值 |
|----|-----|
| 版本 | 见根目录 `VERSION`（单一来源） |
| 平台 | macOS 13+ |
| 工具链 | Swift tools 5.8+（见 `Package.swift`） |
| Bundle ID | `com.kun.ifocus` |

## 学习计划与清单

在任务页标题右侧选择「学习计划」，可预览并导入加速版四周路线；开始日期会自动对齐到周一。重复导入会按稳定计划键跳过已存在的项目，不覆盖任务标题、完成进度或备注。导入任务保存在本机，并按开始日期进入「今天」清单；尚未开始的项目仍可在计划列表中查看。

任务双击后可编辑学习清单、进度单位、开始日期和备注。清单逐项勾选会持久化进度，全部完成后自动完成所属任务；旗标可标记「没懂」，展开任务行即可回顾、取消标记或编辑笔记。任务搜索也会匹配清单标题和单项笔记。

## 构建

```bash
# Debug 编译
swift build --disable-sandbox

# 单元测试（iFocusCore + TaskStore）
swift test --disable-sandbox
```

若本机模块缓存异常，可指定 scratch 目录：

```bash
CLANG_MODULE_CACHE_PATH="$(pwd)/.build/clang-module-cache" \
  swift build --disable-sandbox --scratch-path .build
```

## 打包与运行

```bash
# 生成 Build/iFocus.app（版本号取自根目录 VERSION），并同步到 ~/Desktop 和 /Applications
bash Scripts/package_app.sh

# 生成 Build/iFocus.dmg（默认会先重新打包 .app）
bash Scripts/package_dmg.sh

# 打开打包后的应用（请勿只运行旧的 .app 而不重新打包）
open Build/iFocus.app
```

开发态也可：

```bash
swift run --disable-sandbox
```

## 冒烟测试

```bash
bash Scripts/smoke_test.sh
```

会执行打包 → LaunchServices 启动 → 确认进程存活 → 检查无新 crash report。
若检测到 iFocus 已在运行，脚本会安全退出，不会打断专注。确认可以关闭现有实例时，显式运行：

```bash
bash Scripts/smoke_test.sh --replace-running
```

完整 QA 同样默认保护运行中的应用；仅在明确允许替换时使用
`bash Scripts/run_deep_qa.sh --replace-running`。

## 数据存储

用户数据在本机 Application Support，**请勿随意删除**：

```
~/Library/Application Support/iFocus/
  tasks.json           # 任务列表
  focus_sessions.json  # 专注会话记录
  app_state.json       # 当前任务等本地状态
  timer_session.json   # 可恢复的未完成计时
  avatar-*.png         # 可选头像
```

损坏的 JSON 加载失败时会备份为 `*.corrupt-<timestamp>.json`，并阻止对应数据通道继续覆盖，等待用户恢复或确认从空白开始。

设置项（时长、主题、昵称等）使用 `UserDefaults`。

### 学习记录（~/StudyLog）

现在的应用不再往 `~/StudyLog` 写文件。以前生成过的 `sessions.csv` 和每周报告会留在原地，不会被删，也不会再自动更新。专注记录以 `focus_sessions.json` 为准。

正计时：设置 → 专注与计时 →「专注用正计时」。专注从 00:00 往上数，点「完成」（⌘→）记录并进入休息，满 2 小时自动结束。

提前结束专注时，重置确认框里可选「结束并记录 N 分钟」，已专注的时间会照常计入记录；选「重置（不记录）」则和以前一样丢弃。

升级时先退出旧版，再将新版 `iFocus.app` 拖入“应用程序”并选择替换。应用数据不在 `.app` 包内，正常覆盖安装不会删除上述数据；不要使用清理软件删除 `Application Support/iFocus`。

## 专注体验

- 菜单栏左键打开快捷面板，右键打开完整菜单。
- 迷你计时窗用 ⌥⌘M、菜单栏面板，或专注钟右上角「进入专注」旁边的菜单；可拖动圆环移动，位置会记住。
- 全屏专注模式用 ⌥⌘F 或右上角「进入专注」；隐藏侧栏和窗口 chrome，按 Esc 或「退出专注」返回。沉浸模式在同一个菜单里。
- 任务悬停后出现「…」快速移动、改优先级或删除；也可拖动手柄到侧栏的今天 / 明天 / 收集箱 / 已完成。已完成任务拖回活动列表会重新打开。
- 首次启动是五步引导，可选添加一条示例任务；之后可在「设置 › 通用 › 引导与帮助」重新播放。
- 分类可以自定义名称、颜色和图标，任务、筛选、统计与资料共用同一套定义。内置分类保持固定；在任务属性菜单、筛选栏或「设置 › 通用 › 任务与分类」里管理。

## 设置入口

正式设置界面是独立窗口 **`SettingsWindowView`**（菜单「设置…」或 ⌘,）。  
主窗口侧栏不再嵌入旧的内页设置，避免双份维护。

## 工程结构

```
VERSION                 # 营销版本 + build（唯一来源）
Sources/
  iFocus/               # App 本体（SwiftUI + AppKit），同一模块
    App/                # 进程入口与 macOS 集成
      iFocusApp.swift   # 入口、窗口外观、命令
      AppLog.swift
      Navigation/       # 页面名称、深链与路由
      MenuBar/          # 状态栏宿主
      Windows/          # 窗口状态、迷你计时窗、全屏专注
    Services/           # 本地备份、学习记录、升级前保护、登录项、系统设置
    ViewModels/         # 可观察状态，按领域分目录
      Timer/            # TimerStore、可恢复快照
      Tasks/            # 任务字段 FocusTask、存取 TaskStore、分类
      Settings/
      Analytics/
    Views/
      Content/          # 主窗口骨架：ContentView、侧栏、全局浮层、窗口尺寸
      MenuBar/          # 状态栏面板（SwiftUI；宿主在 App/MenuBar）
      Timer/            # 专注钟页、迷你计时视图
      Tasks/            # 清单页、任务行、编辑任务、分类管理
      Analytics/        # 我的记录：范围、趋势图，以及资料里的热力图
      Profile/          # 头像、热力图、分类等记录组件
      Settings/         # 设置窗口
      DesignSystem/     # 颜色、字号、间距、材质与共用小组件
    AppIcon.icns
  iFocusCore/           # 纯逻辑（过滤、统计、时间范围、备份包、学习记录导出）
Tests/iFocusTests/      # 与上面的层对齐：Core、Stores、Services、App、Views、Product
  Fixtures/             # 仍在 Tests/Fixtures，不随测试文件下移
Scripts/
  package_app.sh        # 读 VERSION 写入 Info.plist，并同步安装
  package_dmg.sh
  smoke_test.sh
  run_deep_qa.sh
```

## 架构文档

当前状态的 C4 结构、数据流与模块分层见：

- `Docs/Architecture/ifocus.architecture-understanding.md`（阅读入口）
- `Docs/Architecture/ifocus.structurizr.dsl`（C4 源）
- `Docs/Architecture/ifocus-data-flow.dot`（数据流）
- `Docs/Architecture/ifocus-modules.dot`（模块依赖）
- `Docs/Architecture/ifocus.evidence.md`（证据与未知项）

## 版本一致性

**只改根目录 `VERSION` 两行**（第 1 行营销版本、第 2 行 build）。  
`package_app.sh` 写入 Info.plist；`AppVersion` 优先读 Bundle，开发态可回退读 `VERSION`。
