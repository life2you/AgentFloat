#!/usr/bin/env bash
# AgentFloat - Codex CLI Notify Hook
# 该脚本供 Codex CLI 的 notify 配置调用，负责将 Codex 完成事件转交至 AgentFloat

set -euo pipefail

SERVER_URL="${AGENTFLOAT_URL:-http://127.0.0.1:41920}"
TOKEN_FILE="${HOME}/.agentfloat/auth_token"

# 1. 提取传入的最后一个参数或由标准输入接收
PAYLOAD=""
if [ "$#" -gt 0 ]; then
    PAYLOAD="${*: -1}"
elif [ ! -t 0 ]; then
    PAYLOAD=$(cat)
fi

if [ -z "${PAYLOAD}" ]; then
    exit 0
fi

# 2. 读取鉴权 Token
TOKEN=""
if [ -n "${AGENTFLOAT_TOKEN:-}" ]; then
    TOKEN="${AGENTFLOAT_TOKEN}"
elif [ -f "${TOKEN_FILE}" ]; then
    TOKEN=$(cat "${TOKEN_FILE}" | tr -d '[:space:]')
fi

if [ -z "${TOKEN}" ]; then
    exit 0
fi

# 3. 使用系统自带 Python3 对参数与状态进行提取与格式标准化，通过环境变量传递避免字符串转义问题
NORMALIZED_PAYLOAD=$(RAW_PAYLOAD="${PAYLOAD}" python3 - <<'EOF' 2>/dev/null || echo ""
import os, sys, json

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw)
except Exception:
    data = {"last_assistant_message": raw, "status": "completed"}

# 兼容 thread_id / thread-id / threadId
thread_id = data.get("thread_id") or data.get("thread-id") or data.get("threadId") or ""
turn_id = data.get("turn_id") or data.get("turn-id") or data.get("turnId") or ""
cwd = data.get("cwd") or ""
msg = data.get("last_assistant_message") or data.get("last-assistant-message") or data.get("lastAssistantMessage") or data.get("message") or ""
status = data.get("status") or "completed"
error = data.get("error") or ""

# 识别错误状态
if error or "fail" in str(status).lower() or "err" in str(status).lower():
    norm_status = "error"
elif "abort" in str(status).lower() or "cancel" in str(status).lower():
    norm_status = "aborted"
else:
    norm_status = "completed"

output = {
    "thread_id": thread_id,
    "turn_id": turn_id,
    "cwd": cwd,
    "last_assistant_message": msg,
    "status": norm_status,
    "error": error if error else None,
    "title": "Codex Turn 执行结束"
}

print(json.dumps(output))
EOF
)

if [ -z "${NORMALIZED_PAYLOAD}" ]; then
    NORMALIZED_PAYLOAD="{\"last_assistant_message\":\"Codex 执行结束\",\"status\":\"completed\"}"
fi

# 4. 发送到本地 HTTP 监听端口
curl -s -X POST "${SERVER_URL}/api/codex/notify" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${TOKEN}" \
     -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true

exit 0
