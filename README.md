# iFocus

macOS 专注 / 番茄钟应用（SwiftUI + AppKit，Swift Package Manager）。

| 项 | 值 |
|----|-----|
| 版本 | 见根目录 `VERSION`（单一来源） |
| 平台 | macOS 13+ |
| 工具链 | Swift tools 5.8+（见 `Package.swift`） |
| Bundle ID | `com.kun.ifocus` |

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

### 学习记录导出（~/StudyLog）

每次记录专注后，应用会把全部专注记录同步成可直接阅读的文件（设置 → 数据 →「打开学习记录」）：

```
~/StudyLog/
  sessions.csv         # 全部专注：日期,开始,结束,分钟,分类,任务（开始时间为估算）
  weeks/2026-10-19.md  # 每周（周一至周日）一份周报：每日总计、学习分类时长、按任务汇总、明细
```

这个文件夹由 `focus_sessions.json` 生成，删掉也会在下次启动或记录时重建。

正计时：设置 → 专注与计时 →「专注用正计时」。专注从 00:00 往上数，点「完成」（⌘→）记录并进入休息，满 2 小时自动结束。

提前结束专注时，重置确认框里可选「结束并记录 N 分钟」，已专注的时间会照常计入记录；选「重置（不记录）」则和以前一样丢弃。

升级时先退出旧版，再将新版 `iFocus.app` 拖入“应用程序”并选择替换。应用数据不在 `.app` 包内，正常覆盖安装不会删除上述数据；不要使用清理软件删除 `Application Support/iFocus`。

## 设置入口

正式设置界面是独立窗口 **`SettingsWindowView`**（菜单「设置…」或 ⌘,）。  
主窗口侧栏不再嵌入旧的内页设置，避免双份维护。

## 工程结构

```
VERSION                 # 营销版本 + build（唯一来源）
Sources/
  iFocus/               # App 本体（SwiftUI + AppKit）
    App/                # 入口 iFocusApp、窗口外观、菜单栏、深链接、开机启动、日志
    Services/           # 本地备份、学习记录（~/StudyLog）写出
    ViewModels/         # TimerStore、TaskStore、SettingsStore 等状态
    Views/
      Content/          # 主窗口骨架：ContentView、侧栏、全局浮层、窗口尺寸
      Timer/            # 专注钟页
      Tasks/            # 清单页、任务行、编辑任务
      Analytics/        # 数据统计页（Chrome / Charts / Cards）
      Profile/          # 个人资料页
      Settings/         # 设置窗口
      Theme/            # 颜色、字号、间距、触感反馈
      Components/       # 多个页面共用的小组件
    AppIcon.icns
  iFocusCore/           # 纯逻辑（过滤、统计、时间范围、备份包、学习记录导出）
Tests/iFocusTests/
Scripts/
  package_app.sh        # 读 VERSION 写入 Info.plist，并同步安装
  package_dmg.sh
  smoke_test.sh
  run_deep_qa.sh
```

## 版本一致性

**只改根目录 `VERSION` 两行**（第 1 行营销版本、第 2 行 build）。  
`package_app.sh` 写入 Info.plist；`AppVersion` 优先读 Bundle，开发态可回退读 `VERSION`。
