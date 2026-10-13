#!/usr/bin/env bash
# AgentFloat.app 打包脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="AgentFloat"
BUILD_CONFIG="${1:-release}"
EXECUTABLE_NAME="AgentFloatApp"
CLI_NAME="agentfloat"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/build}"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🔨 正在构建 ${APP_NAME} (${BUILD_CONFIG})..."
swift build -c "${BUILD_CONFIG}" --product AgentFloatApp
swift build -c "${BUILD_CONFIG}" --product AgentFloatCLI

BIN_PATH=$(swift build -c "${BUILD_CONFIG}" --show-bin-path)

echo "📦 正在生成 macOS App Bundle: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}/AgentFloatApp" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

cp "${BIN_PATH}/AgentFloatCLI" "${APP_BUNDLE}/Contents/MacOS/${CLI_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${CLI_NAME}"

VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION" 2>/dev/null || echo "1.0.9")"

if [ -f "Sources/AgentFloatApp/Resources/Info.plist" ]; then
    cp "Sources/AgentFloatApp/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
    if command -v /usr/libexec/PlistBuddy &>/dev/null; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true

        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
    fi
fi

if [ -f "assets/appicon/AppIcon.icns" ]; then
    cp "assets/appicon/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
elif [ -f "Sources/AgentFloatApp/Resources/AppIcon.icns" ]; then
    cp "Sources/AgentFloatApp/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc 代码签名
if command -v codesign &>/dev/null; then
    echo "🔏 正在进行本地签名 (ad-hoc)..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "✅ 打包完成！"
echo "应用位置: ${APP_BUNDLE}"
echo "启动方式: open \"${APP_BUNDLE}\""
