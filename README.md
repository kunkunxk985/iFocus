# iFocus

macOS 专注 / 番茄钟应用（SwiftUI + AppKit，Swift Package Manager）。

| 项 | 值 |
|----|-----|
| 版本 | **1.9.3**（build **85**） |
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
# 生成 Build/iFocus.app（含 Info.plist 版本 1.9.3 / 85）
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

升级时先退出旧版，再将新版 `iFocus.app` 拖入“应用程序”并选择替换。应用数据不在 `.app` 包内，正常覆盖安装不会删除上述数据；不要使用清理软件删除 `Application Support/iFocus`。

## 设置入口

正式设置界面是独立窗口 **`SettingsWindowView`**（菜单「设置…」或 ⌘,）。  
主窗口侧栏不再嵌入旧的内页设置，避免双份维护。

## 工程结构

```
Sources/
  iFocus/          # App 目标：SwiftUI 界面、Store、菜单栏
  iFocusCore/      # 纯逻辑（过滤、统计、计时格式），便于单测
Tests/iFocusTests/
Scripts/
  package_app.sh   # 打包 .app
  smoke_test.sh    # 冒烟
  run_deep_qa.sh   # 全量测试、性能基准与冒烟
```

## 版本一致性

打包版本以 `Scripts/package_app.sh` 中的 `CFBundleShortVersionString` / `CFBundleVersion` 为准。  
`AppVersion` 的 fallback 应与之保持一致（当前 1.9.3 / 85）。
