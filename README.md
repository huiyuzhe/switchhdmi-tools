# HDMISwitch

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.3.0-orange)](VERSION)

**English** | [简体中文](README.zh-CN.md)

One-click monitor input source switching from the menu bar / system tray.
No more reaching behind the monitor to press physical buttons when you have
two (or more) computers sharing one display.

Works over the standard **DDC/CI** protocol — no vendor drivers needed.

## Features

- **One-click cycle switch** — cycles through your configured input list
- **Input list menu** — jump directly to any input, current input shows a checkmark
- **Cross-platform** — identical CLI and UI behavior on macOS, Windows, Linux
- **Universal macOS binary** — Apple Silicon + Intel, built-in app icon
- **Zero third-party dependencies** — Windows uses the native DDC/CI API;
  macOS uses `m1ddc` (or `ddcctl`); Linux uses `ddcutil`
- **Robust** — retries on flaky DDC reads, 5s timeout protection, state-file fallback
- **Launch at login** — built-in toggle in the menu (macOS: SMAppService, Windows: Run registry key)
- **Bilingual UI** — English / 简体中文 (follows system language by default, switchable in the menu)

## How it works

The switch is always initiated by the computer that is **currently displayed**:

```
[ Mac A shown ]  -- click switch on A -->  monitor switches to B
[ PC B shown ]   -- click switch on B -->  monitor switches back to A
```

DDC/CI commands from the inactive input are usually ignored by the monitor,
so **install the tool on every computer** that shares the display. Each install
lets that machine "switch away"; the next machine switches you back.

## Install

### Download a prebuilt package

Grab the package for your platform from
[Releases](https://github.com/huiyuzhe/switchhdmi-tools/releases) (zip / tar.gz,
SHA256 checksums included):

| Package | Contents |
|---|---|
| `HDMISwitch-x.y.z-macOS-AppleSilicon.zip` | `HDMISwitch.app` for Apple Silicon (M1–M4) |
| `HDMISwitch-x.y.z-macOS-Intel.zip` | `HDMISwitch.app` for Intel Macs |
| `HDMISwitch-x.y.z-Windows.zip` | PowerShell scripts + tray app + launcher |
| `HDMISwitch-x.y.z-Linux.tar.gz` | `switch_hdmi.sh` |

### macOS

```bash
brew install m1ddc            # Intel Mac fallback: brew install ddcctl
unzip HDMISwitch-*-macOS-AppleSilicon.zip   # Intel Macs: -macOS-Intel.zip
mv HDMISwitch-macOS-AppleSilicon/HDMISwitch.app /Applications
chmod +x /Applications/HDMISwitch.app/Contents/MacOS/HDMISwitch
open /Applications/HDMISwitch.app
```

A `⇄` icon appears in the menu bar. First launch: right-click → Open if
Gatekeeper complains, or run `xattr -cr HDMISwitch.app`.

### Windows

1. Unzip `HDMISwitch-*-Windows.zip` to a fixed folder (e.g. `D:\tools\HDMISwitch`)
2. Double-click `HDMISwitch.bat` — a tray icon appears; right-click for the menu
3. Tick **开机自启 (Launch at login)** in the menu

No third-party software required (uses the built-in Windows DDC/CI API).

### Linux

```bash
sudo apt install ddcutil     # or your distro's package manager
tar xzf HDMISwitch-*-Linux.tar.gz
./HDMISwitch-Linux/switch_hdmi.sh toggle
```

## Build from source

### Requirements

| Platform | Requires |
|---|---|
| macOS | Xcode Command Line Tools (`xcode-select --install`), `brew install m1ddc` |
| Windows | Nothing to build — scripts run as-is |
| Linux | Nothing to build |

### Build the macOS app

```bash
git clone https://github.com/huiyuzhe/switchhdmi-tools.git
cd changehdmi-tools
./MenuBarSwitch/build.sh
```

The build script does everything:

1. Compiles the Swift menu bar app as a **universal binary**
   (`-target arm64` + `-target x86_64`, merged with `lipo`)
2. Generates the app icon programmatically (`make_icon.swift`) → `AppIcon.icns`
3. Copies the core script into the bundle resources
4. Writes `Info.plist` with the version from the `VERSION` file
5. If `/Applications/HDMISwitch.app` exists, syncs the new build there and relaunches

Output: `HDMISwitch.app` (in the repo root, kept out of git by `.gitignore`).

### Package all platforms

```bash
./release.sh
```

Produces a `release/` folder with versioned artifacts for all three platforms
plus a `SHA256SUMS.txt`. Pushing a tag `v*` to GitHub also triggers the same
packaging via [GitHub Actions](.github/workflows/release.yml) and publishes a Release.

## Usage

### Menu / tray

- **One-click switch** — cycle to the next input in your list
- **Current input** — shows what the monitor is on right now
- **Input list** — click any entry to jump directly; ✓ marks the current one
- **Launch at login** — toggle
- **Quit**

### Command line (identical on all platforms)

```
switch_hdmi.sh [toggle|list|current|status|<code>]     # macOS / Linux
switch_hdmi.ps1 [toggle|list|current|status|<code>]    # Windows
```

- `toggle` — cycle to next input (default)
- `list` — print all inputs (`code<TAB>label`)
- `current` — print current input code (exit 1 on failure)
- `status` — human-readable status
- `<code>` — switch directly, e.g. `15`

## Configuration

All platforms share the same config block at the top of the core script —
an ordered list of `code:label` entries:

```bash
INPUTS=(
  "15:HDMI 1（另一台电脑）"      # HDMI 1 (the other computer)
  "17:HDMI 2（本机）"           # HDMI 2 (this machine)
)
```

**To add a third input, just add one line** — the menu and cycle switching
pick it up automatically:

```bash
  "18:HDMI 3"
```

Common VCP 0x60 input codes: `15`=HDMI1, `17`=HDMI2, `18`=HDMI3, `4`=DP1, `11`=DP2.
Wrong code for your monitor? Change the numbers and re-run.

Each machine can customize labels to taste (e.g. write which computer is on which input).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Switch/reads fail on one machine | Monitor ignores DDC from the inactive input — that's normal. Always switch from the currently-displayed machine. |
| All DDC calls fail | Monitor DDC got stuck — power-cycle the monitor or replug the cable. Check OSD setting DDC/CI = On (LG: Settings → General → DDC/CI). |
| macOS app won't open (copied from USB drive) | `chmod +x HDMISwitch.app/Contents/MacOS/HDMISwitch`, and `xattr -cr HDMISwitch.app` for Gatekeeper |
| macOS app icon unresponsive | Stale instance — `pkill -x HDMISwitch` then reopen |
| Windows script blocked | Run with `-ExecutionPolicy Bypass` (the bundled `.bat` does this) |
| Wrong input switched | Adjust the codes in the config block for your monitor model |

## Contributing

Issues and PRs welcome. Key areas: Windows tray polish, multi-monitor support,
auto-detecting input codes, translations.

## License

[Apache-2.0](LICENSE)
