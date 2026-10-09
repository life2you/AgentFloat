#!/usr/bin/env bash
# AgentFloat - Homebrew Cask 生成与更新脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OWNER="${OWNER:-life2you}"
REPO="${REPO:-AgentFloat}"
HOMEPAGE="${HOMEPAGE:-https://github.com/$OWNER/$REPO}"
CASK_TOKEN="${CASK_TOKEN:-agentfloat}"
APP_NAME="${APP_NAME:-AgentFloat}"
DESCRIPTION="${DESCRIPTION:-macOS desktop floating tracker for AI Coding Agents}"
VERSION=""
CASK_PATH=""
SHA256=""
DRY_RUN=0

show_help() {
  cat <<EOF
用法: ./scripts/update-homebrew-cask.sh [选项] [版本号]

选项:
  --output PATH     将生成的 Cask 写入指定路径
  --sha256 HASH     直接指定压缩包 SHA256（默认自动从 dist 读取或从 Release 下载计算）
  --dry-run         输出到终端而不写入文件
  --help            显示帮助信息
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      CASK_PATH="$2"
      shift 2
      ;;
    --output=*)
      CASK_PATH="${1#*=}"
      shift
      ;;
    --sha256)
      SHA256="$2"
      shift 2
      ;;
    --sha256=*)
      SHA256="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    -*)
      echo "未知选项: $1" >&2
      exit 1
      ;;
    *)
      VERSION="$1"
      shift
      ;;
  esac
done

VERSION="${VERSION:-$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")}"
if [[ -z "$VERSION" ]]; then
  echo "❌ 无法检测到版本号，请在 VERSION 文件中指定或通过参数传入" >&2
  exit 1
fi

TAG="v$VERSION"
ARCHIVE_NAME="AgentFloat-v${VERSION}.zip"
LOCAL_ARCHIVE="$REPO_ROOT/dist/$ARCHIVE_NAME"
LOCAL_SHA_FILE="$REPO_ROOT/dist/$ARCHIVE_NAME.sha256"

if [[ -z "$SHA256" ]]; then
  if [[ -f "$LOCAL_SHA_FILE" ]]; then
    SHA256="$(tr -d '[:space:]' < "$LOCAL_SHA_FILE")"
  elif [[ -f "$LOCAL_ARCHIVE" ]]; then
    SHA256="$(shasum -a 256 "$LOCAL_ARCHIVE" | awk '{print $1}')"
  else
    RELEASE_URL="https://github.com/$OWNER/$REPO/releases/download/$TAG/$ARCHIVE_NAME"
    echo "⬇️ 正在从 GitHub Release 计算 SHA256: $RELEASE_URL"
    SHA256="$(
      curl --fail --silent --show-error --location --retry 3 "$RELEASE_URL" |
        shasum -a 256 |
        awk '{print $1}'
    )"
  fi
fi

if [[ -z "$SHA256" ]]; then
  echo "❌ 无法获取或计算 SHA256 校验和" >&2
  exit 1
fi

CASK_CONTENT="$(cat <<EOF
cask "$CASK_TOKEN" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$OWNER/$REPO/releases/download/v#{version}/AgentFloat-v#{version}.zip"
  name "$APP_NAME"
  desc "$DESCRIPTION"
  homepage "$HOMEPAGE"

  depends_on macos: :sequoia

  app "$APP_NAME.app"
  binary "#{appdir}/$APP_NAME.app/Contents/MacOS/agentfloat"

  zap trash: [
    "~/.agentfloat",
    "~/Library/Preferences/com.agentfloat.AgentFloatApp.plist",
  ]
end
EOF
)"

if [[ "$DRY_RUN" == "1" || -z "$CASK_PATH" ]]; then
  printf '%s\n' "$CASK_CONTENT"
  if [[ "$DRY_RUN" == "1" ]]; then
    exit 0
  fi
fi

if [[ -n "$CASK_PATH" ]]; then
  mkdir -p "$(dirname "$CASK_PATH")"
  printf '%s\n' "$CASK_CONTENT" > "$CASK_PATH"
  echo "✅ 已生成 Cask 文件: $CASK_PATH"
  echo "版本:   $VERSION"
  echo "SHA256: $SHA256"
fi
