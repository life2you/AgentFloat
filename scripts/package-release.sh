#!/usr/bin/env bash
# AgentFloat - Release 打包脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="$(tr -d '[:space:]' < VERSION)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${ROOT_DIR}/build/AgentFloat.app"
ARCHIVE_NAME="AgentFloat-v${VERSION}.zip"
ARCHIVE_PATH="${DIST_DIR}/${ARCHIVE_NAME}"

echo "🔨 1. 编译并生成 App Bundle..."
./scripts/build-app.sh release

echo "📦 2. 使用 ditto 制作 Release 压缩包..."
mkdir -p "${DIST_DIR}"
rm -f "${ARCHIVE_PATH}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ARCHIVE_PATH}"

echo "🔐 3. 计算 SHA256 校验和..."
SHA256="$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')"
echo "${SHA256}" > "${ARCHIVE_PATH}.sha256"

echo ""
echo "=================================================="
echo "✅ Release 打包完成！"
echo "版本:      v${VERSION}"
echo "归档位置:  ${ARCHIVE_PATH}"
echo "SHA256:    ${SHA256}"
echo "=================================================="
