#!/bin/bash
# 多平台打包脚本：生成 release/ 目录下的发布包 + SHA256SUMS.txt
# 用法: ./release.sh
#   macOS(Apple Silicon) → HDMISwitch-<版本>-macOS-AppleSilicon.zip (arm64 App + 文档)
#   macOS(Intel)         → HDMISwitch-<版本>-macOS-Intel.zip        (x86_64 App + 文档)
#   Windows              → HDMISwitch-<版本>-Windows.zip            (PowerShell 托盘应用 + 文档)
#   Linux                → HDMISwitch-<版本>-Linux.tar.gz           (核心脚本 + 文档)
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(tr -d '[:space:]' < VERSION 2>/dev/null || echo "0.0.0")
OUT="release"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

copy_docs() {
  cp README.md README.zh-CN.md LICENSE "$1/"
}

package_macos() {
  local arch="$1" name="$2"
  echo "==> 构建 macOS $arch App"
  SKIP_INSTALL=1 APP_ARCH="$arch" APP_OUT="$STAGE/mac-$arch/HDMISwitch.app" ./MenuBarSwitch/build.sh >/dev/null
  echo "==> 打包 macOS $name"
  mkdir -p "$STAGE/HDMISwitch-macOS-$name"
  cp -R "$STAGE/mac-$arch/HDMISwitch.app" "$STAGE/HDMISwitch-macOS-$name/"
  copy_docs "$STAGE/HDMISwitch-macOS-$name"
  ditto -c -k --sequesterRsrc --keepParent \
    "$STAGE/HDMISwitch-macOS-$name" "$OUT/HDMISwitch-$VERSION-macOS-$name.zip"
}

rm -rf "$OUT"
mkdir -p "$OUT"

package_macos arm64 "AppleSilicon"
package_macos x86_64 "Intel"

echo "==> 打包 Windows"
mkdir -p "$STAGE/HDMISwitch-Windows"
cp windows/switch_hdmi.ps1 windows/HDMISwitch-Tray.ps1 windows/HDMISwitch.bat windows/HDMISwitch.png \
   "$STAGE/HDMISwitch-Windows/"
copy_docs "$STAGE/HDMISwitch-Windows"
ditto -c -k --keepParent \
  "$STAGE/HDMISwitch-Windows" "$OUT/HDMISwitch-$VERSION-Windows.zip"

echo "==> 打包 Linux"
mkdir -p "$STAGE/HDMISwitch-Linux"
cp switch_hdmi.sh "$STAGE/HDMISwitch-Linux/"
chmod +x "$STAGE/HDMISwitch-Linux/switch_hdmi.sh"
copy_docs "$STAGE/HDMISwitch-Linux"
tar -czf "$OUT/HDMISwitch-$VERSION-Linux.tar.gz" -C "$STAGE" HDMISwitch-Linux

echo "==> 生成校验和"
(cd "$OUT" && shasum -a 256 *.zip *.tar.gz > SHA256SUMS.txt)

echo "打包完成: $OUT/"
ls -la "$OUT"
