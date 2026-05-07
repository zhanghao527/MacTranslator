#!/usr/bin/env bash
# 构建并打包成 .app Bundle，便于授权辅助功能。
# 用法：
#   ./build.sh          # release 构建 + 打包到 build/MacTranslator.app
#   ./build.sh run      # 构建后直接启动
#   ./build.sh install  # 复制到 /Applications

set -euo pipefail

APP_NAME="MacTranslator"
BUNDLE_ID="com.local.mactranslator"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "[1/4] swift build -c release"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Binary not found at ${BIN_PATH}"
  exit 1
fi

echo "[2/4] 清理旧 .app"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "[3/4] 拷贝可执行文件 + 生成 Info.plist"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>         <string>Mac Translator</string>
    <key>CFBundleIdentifier</key>          <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>CFBundleShortVersionString</key>  <string>0.1.0</string>
    <key>CFBundleExecutable</key>          <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
    <key>NSHighResolutionCapable</key>     <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>用于读取当前选中文本进行翻译。</string>
</dict>
</plist>
PLIST

echo "[4/4] Ad-hoc 代码签名"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "✅ 打包完成：${APP_DIR}"

case "${1:-}" in
  run)
    echo "启动 ${APP_DIR}"
    open "${APP_DIR}"
    ;;
  install)
    echo "安装到 /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" /Applications/
    echo "已安装：/Applications/${APP_NAME}.app"
    ;;
esac
