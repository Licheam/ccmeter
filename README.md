# ccmeter

Mac 菜单栏小工具，把 [ccusage](https://github.com/ryoppippi/ccusage) 的核心数字常驻显示在状态栏。点开有 today / 当前 5 小时 block / top sessions 的分解。

## 特性

- 状态栏常驻显示今日累计成本或 token（可切换）
- 左键弹 popover：Today、Active 5h Block（含 burn rate / 剩余时间）、Top Sessions
- 右键弹原生菜单：Refresh / Open / Quit
- 默认 30 秒刷新一次（可调），系统睡眠时自动暂停
- ccusage 二进制自动定位：检查 Homebrew、bun、npm-global、volta、nvm、MacPorts 常见位置；找不到回退到 `/bin/zsh -lc 'command -v ccusage'`；都失败时弹 Locate 面板让用户手选

## 要求

- macOS 14 Sonoma 或更高
- [`ccusage`](https://github.com/ryoppippi/ccusage) 已安装（`npm install -g ccusage` 或 `bun add -g ccusage`）
- 构建需要 Xcode 15+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

## 安装

### 从 Releases 下载（推荐）

到 [Releases 页面](../../releases) 下载最新 `ccmeter-x.y.z.dmg`，挂载后把 `ccmeter.app` 拖进 Applications。

> **首次启动**：发布版本未经 Apple Developer ID 签名，macOS Gatekeeper 会拦下。
> 解决方法：在 Finder 里**右键** `ccmeter.app` → **打开** → 弹窗里再点 **打开**。
> 或：第一次双击被拦后，**系统设置 → 隐私与安全性 → 仍要打开**。
> 之后双击就能直接启动。

### 自己构建

要求：macOS 14+、Xcode 15+、[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)。

```bash
git clone <this-repo> ccmeter
cd ccmeter
xcodegen generate
xcodebuild -project ccmeter.xcodeproj -scheme ccmeter -configuration Release \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
open build/Build/Products/Release/ccmeter.app
```

## 配置

通过 popover 底部的 **Settings…** 打开：

| 设置 | 默认 | 说明 |
| --- | --- | --- |
| Status bar shows | Cost | Cost / Tokens / Cost+Tokens 三选一 |
| Refresh interval | 30s | 5–600 秒 |
| ccusage path | 自动 | 留空走自动发现，或手动指定二进制路径 |

设置存在 `UserDefaults`（domain `wang.leachim.ccmeter`），重启保留。

## 排错

**状态栏显示 `—`，popover 提示 "ccusage not found"**
GUI app 从 Finder 启动时不继承 shell 的 PATH。优先尝试以下任一：

1. 在 Settings 里点 **Locate ccusage…**，手动选 `which ccusage` 给出的路径
2. 把 ccusage 软链到 `/usr/local/bin/ccusage` 或 `/opt/homebrew/bin/ccusage`

**数字不刷新**
点 popover 顶部刷新按钮立即触发；或减小 Settings 里的 refresh interval。后台 ccusage 调用失败会显示在 popover 底部。

**Mac 睡眠唤醒后没数据**
是预期 —— 唤醒后会自动重启 timer 并立即刷新一次，等几秒。

## 项目结构

```text
.
├── project.yml              # XcodeGen 配置，唯一的项目结构来源
├── ccmeter/                 # Swift 源码
│   ├── App.swift            # @main + Settings scene
│   ├── AppDelegate.swift    # 持有 store / status bar
│   ├── StatusBarController.swift  # NSStatusItem + NSPopover + 右键菜单
│   ├── PopoverContent.swift # SwiftUI popover 根视图
│   ├── SettingsView.swift   # SwiftUI 设置表单
│   ├── UsageStore.swift     # @Observable + timer + 睡眠/唤醒监听
│   ├── CCUsageRunner.swift  # 二进制定位 + Process 调用
│   ├── UsageModels.swift    # Codable: Daily / Session / Blocks
│   └── Formatting.swift     # 数字紧凑格式化 + monospaced-digit
└── Tests/Fixtures/          # ccusage --json 实测样本，用于 schema 校验
```

修改源码后跑 `xcodegen generate` 重新生成 `.xcodeproj`（已在 `.gitignore` 里，不入库）。

## v1 范围之外

明确 punt 的功能，欢迎 PR：

- Sparkle 自动更新
- 图表 / sparkline / per-day 柱状图
- 多账号、多 organization 切换
- 接近 5h block 上限时的本地通知
- FSEvents 监听 `~/.claude/projects` 实时刷新
- Linux / Windows
- Mac App Store 上架（与 subprocess 不兼容，需要 sandbox 让步）
- ccusage `statusline` 子命令复用（目前直接组合 daily/blocks 更灵活）

## 致谢

数据完全来自 [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage)。本项目只是一个原生 macOS 包装。

## License

[MIT](LICENSE)
