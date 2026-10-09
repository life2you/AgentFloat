#!/usr/bin/env bash
# AgentFloat.app 打包脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="AgentFloat"
BUILD_CONFIG="${1:-release}"
OUTPUT_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🔨 正在构建 ${APP_NAME} (${BUILD_CONFIG})..."
swift build -c "${BUILD_CONFIG}" --product AgentFloatApp

BIN_PATH=$(swift build -c "${BUILD_CONFIG}" --show-bin-path)

echo "📦 正在生成 macOS App Bundle: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}/AgentFloatApp" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [ -f "Sources/AgentFloatApp/Resources/Info.plist" ]; then
    cp "Sources/AgentFloatApp/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
fi

# Ad-hoc 代码签名
if command -v codesign &>/dev/null; then
    echo "🔏 正在进行本地签名 (ad-hoc)..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "✅ 打包完成！"
echo "应用位置: ${APP_BUNDLE}"
echo "启动方式: open \"${APP_BUNDLE}\""
