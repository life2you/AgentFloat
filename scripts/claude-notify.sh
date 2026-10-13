#!/usr/bin/env bash
# AgentFloat - Claude Code (CLI) Notify Hook
# 该脚本供 Claude CLI 的 hooks.Stop 配置调用，负责将 Claude 完成事件转交至 AgentFloat

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

# 3. 使用系统自带 Python3 对参数与状态进行提取与格式标准化
NORMALIZED_PAYLOAD=$(RAW_PAYLOAD="${PAYLOAD}" python3 - <<'EOF' 2>/dev/null || echo ""
import os, sys, json, time

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw)
except Exception:
    data = {"last_assistant_message": raw, "status": "completed"}

session_id = data.get("session_id") or data.get("sessionId") or ""
turn_id = data.get("turn_id") or data.get("turnId") or f"turn-{int(time.time() * 1000)}"
cwd = data.get("cwd") or ""
msg = data.get("last_assistant_message") or data.get("lastAssistantMessage") or data.get("message") or ""
status = data.get("status") or "completed"
error = data.get("error") or ""
term_app = data.get("terminal_app") or os.environ.get("TERM_PROGRAM") or ""

# 识别错误状态
if error or "fail" in str(status).lower() or "err" in str(status).lower():
    norm_status = "error"
elif "abort" in str(status).lower() or "cancel" in str(status).lower():
    norm_status = "aborted"
else:
    norm_status = "completed"

msg_snippet = ""
if msg:
    first_line = str(msg).strip().split("\n")[0].strip()
    if len(first_line) > 35:
        msg_snippet = first_line[:32] + "..."
    else:
        msg_snippet = first_line

final_title = data.get("title") or (f"Claude: {msg_snippet}" if msg_snippet else "Claude 执行完成")

output = {
    "session_id": session_id,
    "turn_id": turn_id,
    "cwd": cwd,
    "last_assistant_message": msg,
    "status": norm_status,
    "error": error if error else None,
    "terminal_app": term_app,
    "title": final_title
}

print(json.dumps(output))
EOF
)

if [ -z "${NORMALIZED_PAYLOAD}" ]; then
    exit 0
fi

# 4. 发送到本地 HTTP 监听端口 (/api/claude/notify 优先，失败降级 /api/events)
curl -s -X POST "${SERVER_URL}/api/claude/notify" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${TOKEN}" \
     -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || \
curl -s -X POST "${SERVER_URL}/api/events" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${TOKEN}" \
     -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true

exit 0
