# HDMISwitch

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.3.0-orange)](VERSION)

[English](README.md) | **简体中文**

从菜单栏 / 系统托盘一键切换显示器输入源。
两台（或多台）电脑共用一台显示器时，不用再伸手到显示器背后按按钮。

基于标准 **DDC/CI** 协议，无需厂商驱动。

## 功能特性

- **一键循环切换** — 按配置的输入源列表顺序循环
- **输入源列表菜单** — 点任意一路直达，当前输入带 ✓ 标记
- **跨平台** — macOS / Windows / Linux 三端行为完全一致（UI 和命令行）
- **macOS universal 双架构** — Apple Silicon + Intel 通吃，内置应用图标
- **零第三方依赖** — Windows 用系统原生 DDC/CI API；macOS 用 `m1ddc`（备选 `ddcctl`）；Linux 用 `ddcutil`
- **健壮性** — DDC 读取失败自动重试、5 秒超时保护、状态文件兜底
- **开机自启** — 菜单内直接勾选（macOS: SMAppService，Windows: 注册表 Run 键）
- **界面双语** — 简体中文 / English（默认跟随系统语言，菜单里可切换）

## 工作原理

切换永远由**当前正在被显示的那台电脑**发起：

```
[ 显示 Mac A ]  -- 在 A 上点切换 -->  显示器切到 B
[ 显示 PC B ]   -- 在 B 上点切换 -->  显示器切回 A
```

显示器通常会忽略来自非活动输入的 DDC 命令，所以**每台共用显示器的电脑都要装**。
每台机器负责"切走自己"，下一台机器把你切回来。

## 安装

### 下载预编译包

到 [Releases](https://github.com/huiyuzhe/switchhdmi-tools/releases) 下载对应平台的包
（zip / tar.gz，附 SHA256 校验和）：

| 包 | 内容 |
|---|---|
| `HDMISwitch-x.y.z-macOS-AppleSilicon.zip` | Apple Silicon（M1–M4）版 `HDMISwitch.app` |
| `HDMISwitch-x.y.z-macOS-Intel.zip` | Intel 芯片 Mac 版 `HDMISwitch.app` |
| `HDMISwitch-x.y.z-Windows.zip` | PowerShell 脚本 + 托盘应用 + 启动器 |
| `HDMISwitch-x.y.z-Linux.tar.gz` | `switch_hdmi.sh` |

### macOS

```bash
brew install m1ddc            # Intel Mac 装不上就改用: brew install ddcctl
unzip HDMISwitch-*-macOS-AppleSilicon.zip   # Intel 芯片的 Mac 用 -macOS-Intel.zip
mv HDMISwitch-macOS-AppleSilicon/HDMISwitch.app /Applications
chmod +x /Applications/HDMISwitch.app/Contents/MacOS/HDMISwitch
open /Applications/HDMISwitch.app
```

菜单栏出现 `⇄` 图标。首次打开若被 Gatekeeper 拦截：右键 → 打开，
或执行 `xattr -cr HDMISwitch.app`。

### Windows

1. 把 `HDMISwitch-*-Windows.zip` 解压到一个固定目录（如 `D:\tools\HDMISwitch`）
2. 双击 `HDMISwitch.bat` — 托盘区出现图标，右键出菜单
3. 勾选菜单里的「开机自启」

无需安装任何第三方软件（直接调用 Windows 自带 DDC/CI API）。

### Linux

```bash
sudo apt install ddcutil     # 或对应发行版的包管理器
tar xzf HDMISwitch-*-Linux.tar.gz
./HDMISwitch-Linux/switch_hdmi.sh toggle
```

## 从源码编译

### 环境要求

| 平台 | 需要 |
|---|---|
| macOS | Xcode Command Line Tools（`xcode-select --install`）、`brew install m1ddc` |
| Windows | 无需编译，脚本直接运行 |
| Linux | 无需编译 |

### 编译 macOS 应用

```bash
git clone https://github.com/huiyuzhe/switchhdmi-tools.git
cd changehdmi-tools
./MenuBarSwitch/build.sh
```

构建脚本会自动完成全部步骤：

1. 将 Swift 菜单栏应用编译为 **universal 双架构**
   （`-target arm64` + `-target x86_64`，再用 `lipo` 合并）
2. 程序化生成应用图标（`make_icon.swift`）→ `AppIcon.icns`
3. 把核心切换脚本拷进 bundle 的 Resources
4. 用 `VERSION` 文件里的版本号生成 `Info.plist`
5. 若 `/Applications/HDMISwitch.app` 已存在，自动同步新版并重启

产物：仓库根目录下的 `HDMISwitch.app`（已被 `.gitignore` 排除，不入库）。

### 打包全部平台

```bash
./release.sh
```

生成 `release/` 目录，内含三平台带版本号的发布包 + `SHA256SUMS.txt`。
向 GitHub 推送 `v*` 标签也会触发同样的打包流程
（[GitHub Actions](.github/workflows/release.yml)），并自动发布 Release。

## 使用

### 菜单 / 托盘

- **一键切换** — 按列表循环到下一路
- **当前输入** — 显示显示器当前在哪一路
- **输入源列表** — 点任意一路直达；✓ 标记当前
- **开机自启** — 开关
- **退出**

### 命令行（三平台接口完全一致）

```
switch_hdmi.sh [toggle|list|current|status|<代码>]     # macOS / Linux
switch_hdmi.ps1 [toggle|list|current|status|<代码>]    # Windows
```

- `toggle` — 循环切换（默认动作）
- `list` — 列出所有输入源（`代码<TAB>名称`）
- `current` — 输出当前输入源代码（失败退出码 1）
- `status` — 人类可读状态
- `<代码>` — 直接切换，如 `15`

## 配置

三个平台的核心脚本顶部都有同一段"可配置区"——按顺序排列的 `代码:名称` 列表：

```bash
INPUTS=(
  "15:HDMI 1（另一台电脑）"
  "17:HDMI 2（本机）"
)
```

**以后有第 3 路输入，加一行即可**——菜单和一键切换自动跟着变：

```bash
  "18:HDMI 3"
```

常见 VCP 0x60 输入代码：`15`=HDMI1、`17`=HDMI2、`18`=HDMI3、`4`=DP1、`11`=DP2。
显示器不认这些代码？改数字即可（各品牌略有差异）。

每台机器的名称可以按喜好自定义（比如写清楚哪台电脑在哪一路）。

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| 某台电脑上切换/读取失败 | 显示器忽略非活动输入的 DDC，属正常现象；永远从"当前正被显示的那台"发起切换 |
| 所有 DDC 调用都失败 | 显示器 DDC 卡死 — 显示器断电重上电或重插线；检查 OSD 里 DDC/CI 是否开启（LG: 设置 → 常规 → DDC/CI） |
| macOS App 打不开（从 U 盘/移动硬盘拷的） | `chmod +x HDMISwitch.app/Contents/MacOS/HDMISwitch`；被 Gatekeeper 拦截则 `xattr -cr HDMISwitch.app` |
| macOS 图标点击无反应 | 实例卡死 — `pkill -x HDMISwitch` 后重新打开 |
| Windows 脚本被禁止运行 | 用 `-ExecutionPolicy Bypass` 参数（自带的 `.bat` 已带） |
| 切错了输入 | 按你的显示器型号调整配置区里的代码 |

## 参与贡献

欢迎 Issue 和 PR。重点方向：Windows 托盘体验完善、多显示器支持、
输入源代码自动探测、多语言翻译。

## 开源协议

[Apache-2.0](LICENSE)
