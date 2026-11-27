#!/bin/bash
# 多平台打包脚本：生成 release/ 目录下的三平台发布包 + SHA256SUMS.txt
# 用法: ./release.sh
#   macOS   → HDMISwitch-<版本>-macOS.zip   (universal App + 文档)
#   Windows → HDMISwitch-<版本>-Windows.zip (PowerShell 托盘应用 + 文档)
#   Linux   → HDMISwitch-<版本>-Linux.tar.gz(核心脚本 + 文档)
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(tr -d '[:space:]' < VERSION 2>/dev/null || echo "0.0.0")
OUT="release"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

copy_docs() {
  cp README.md README.zh-CN.md LICENSE "$1/"
}

echo "==> 构建 macOS universal App"
./MenuBarSwitch/build.sh >/dev/null
[ -d HDMISwitch.app ] || { echo "构建失败"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> 打包 macOS"
mkdir -p "$STAGE/HDMISwitch-macOS"
cp -R HDMISwitch.app "$STAGE/HDMISwitch-macOS/"
copy_docs "$STAGE/HDMISwitch-macOS"
ditto -c -k --sequesterRsrc --keepParent \
  "$STAGE/HDMISwitch-macOS" "$OUT/HDMISwitch-$VERSION-macOS.zip"

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
