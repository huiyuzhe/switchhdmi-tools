#!/bin/bash
# 编译菜单栏切换 App 并生成 HDMISwitch.app（含图标）
#
# 环境变量（可选）:
#   APP_ARCH      arm64 | x86_64 | universal（默认 universal）
#   APP_OUT       输出的 .app 路径（默认仓库根目录 HDMISwitch.app）
#   SKIP_INSTALL  1=跳过同步 /Applications（release.sh 分架构打包时用）
set -e
cd "$(dirname "$0")"

ROOT="$(cd .. && pwd)"
APP_ARCH="${APP_ARCH:-universal}"
APP_OUT="${APP_OUT:-$ROOT/HDMISwitch.app}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
ICONSET_DIR="./AppIcon.iconset"

rm -rf "$APP_OUT" "$ICONSET_DIR"
mkdir -p "$APP_OUT/Contents/MacOS" "$APP_OUT/Contents/Resources" "$ICONSET_DIR"

# 1. 编译主程序
TMP_DIR="$(mktemp -d)"
case "$APP_ARCH" in
  arm64)
    swiftc -O -target arm64-apple-macos13.0 main.swift -o "$TMP_DIR/HDMISwitch.bin"
    cp "$TMP_DIR/HDMISwitch.bin" "$APP_OUT/Contents/MacOS/HDMISwitch"
    ;;
  x86_64)
    swiftc -O -target x86_64-apple-macos13.0 main.swift -o "$TMP_DIR/HDMISwitch.bin"
    cp "$TMP_DIR/HDMISwitch.bin" "$APP_OUT/Contents/MacOS/HDMISwitch"
    ;;
  universal)
    swiftc -O -target arm64-apple-macos13.0 main.swift -o "$TMP_DIR/HDMISwitch.arm64"
    swiftc -O -target x86_64-apple-macos13.0 main.swift -o "$TMP_DIR/HDMISwitch.x86_64"
    lipo -create "$TMP_DIR/HDMISwitch.arm64" "$TMP_DIR/HDMISwitch.x86_64" \
         -output "$APP_OUT/Contents/MacOS/HDMISwitch"
    ;;
  *)
    echo "未知架构: $APP_ARCH (可选 arm64|x86_64|universal)"; exit 1
    ;;
esac
rm -rf "$TMP_DIR"
chmod +x "$APP_OUT/Contents/MacOS/HDMISwitch"
lipo -info "$APP_OUT/Contents/MacOS/HDMISwitch"

# 2. 生成图标 icns
swift make_icon.swift ./icon_1024.png
sips -z 16 16     icon_1024.png --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
sips -z 32 32     icon_1024.png --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     icon_1024.png --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
sips -z 64 64     icon_1024.png --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   icon_1024.png --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
sips -z 256 256   icon_1024.png --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   icon_1024.png --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
sips -z 512 512   icon_1024.png --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   icon_1024.png --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
sips -z 1024 1024 icon_1024.png --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_OUT/Contents/Resources/AppIcon.icns"

# 3. 拷贝切换脚本
cp "$ROOT/switch_hdmi.sh" "$APP_OUT/Contents/Resources/switch_hdmi.sh"
chmod +x "$APP_OUT/Contents/Resources/switch_hdmi.sh"

# 4. Windows 托盘图标 PNG（与 make_icon 同源，跨平台共用）
if [ -d "$ROOT/windows" ]; then
  sips -z 256 256 ./icon_1024.png --out "$ROOT/windows/HDMISwitch.png" >/dev/null
fi
rm -rf "$ICONSET_DIR" icon_1024.png

# 5. Info.plist（版本号取自仓库根目录的 VERSION 文件）
APP_VERSION=$(cat "$ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')
[ -n "$APP_VERSION" ] || APP_VERSION="1.0.0"
cat > "$APP_OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HDMISwitch</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lhj.hdmi-switch</string>
    <key>CFBundleName</key>
    <string>HDMISwitch</string>
    <key>CFBundleDisplayName</key>
    <string>HDMI 切换</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "构建完成: $APP_OUT ($APP_ARCH)"

# 6. 若是本机默认构建且已安装到 /Applications，自动同步更新并重启
INSTALL_DIR="/Applications/HDMISwitch.app"
if [ "$SKIP_INSTALL" != "1" ] && [ "$APP_OUT" = "$ROOT/HDMISwitch.app" ] && [ -d "$INSTALL_DIR" ]; then
  pkill -x HDMISwitch 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  cp -R "$APP_OUT" "$INSTALL_DIR"
  chmod +x "$INSTALL_DIR/Contents/MacOS/HDMISwitch" "$INSTALL_DIR/Contents/Resources/switch_hdmi.sh"
  open "$INSTALL_DIR"
  echo "已同步更新 $INSTALL_DIR"
fi
