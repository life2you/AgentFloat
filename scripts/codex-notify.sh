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
import os, sys, json, sqlite3

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw)
except Exception:
    data = {"last_assistant_message": raw, "status": "completed"}

thread_id = data.get("thread_id") or data.get("thread-id") or data.get("threadId") or ""
turn_id = data.get("turn_id") or data.get("turn-id") or data.get("turnId") or ""
cwd = data.get("cwd") or ""
msg = data.get("last_assistant_message") or data.get("last-assistant-message") or data.get("lastAssistantMessage") or data.get("message") or ""
status = data.get("status") or "completed"
error = data.get("error") or ""

# 1. 过滤内部子任务 / 标题生成 Turn（例如单纯生成 {"title": "...", "description": "..."} 的内部推理）
raw_msg = str(msg or "").strip()
if raw_msg.startswith("{") and raw_msg.endswith("}"):
    try:
        parsed = json.loads(raw_msg)
        if isinstance(parsed, dict) and "title" in parsed and ("description" in parsed or len(parsed) <= 3):
            # 内部元数据更新任务，忽略不发通知
            print("IGNORE")
            sys.exit(0)
    except Exception:
        pass

# 2. 识别发起客户端 (Originator): 优先从 ~/.codex/state_5.sqlite 中查询 thread 来源
originator = data.get("originator") or ""
if not originator and thread_id:
    try:
        db_path = os.path.expanduser("~/.codex/state_5.sqlite")
        if os.path.exists(db_path):
            conn = sqlite3.connect(db_path, timeout=1.0)
            c = conn.cursor()
            c.execute("SELECT originator FROM threads WHERE id = ? LIMIT 1", (thread_id,))
            row = c.fetchone()
            if row and row[0]:
                originator = row[0]
            conn.close()
    except Exception:
        pass

# 3. 精准判断终端还是桌面应用
term_app = data.get("terminal_app") or ""
if not term_app:
    if "desktop" in originator.lower():
        # 来源于 Codex 桌面端，绝不能使用继承自后台 daemon 的 TERM_PROGRAM！
        term_app = "codex"
    else:
        term_app = os.environ.get("TERM_PROGRAM") or "codex"

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

final_title = data.get("title") or (f"Codex: {msg_snippet}" if msg_snippet else "Codex 执行完成")

output = {
    "thread_id": thread_id,
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

# 过滤内部或无效任务
if [ -z "${NORMALIZED_PAYLOAD}" ] || [ "${NORMALIZED_PAYLOAD}" = "IGNORE" ]; then
    # 若存在下游 SkyClient 依然保持透传，但不上报 AgentFloat
    SKY_CLIENT="${HOME}/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
    if [ -n "${CODEX_CHAIN_NOTIFY:-}" ] && [ -x "${CODEX_CHAIN_NOTIFY}" ]; then
        "${CODEX_CHAIN_NOTIFY}" "$@" >/dev/null 2>&1 || true
    elif [ -x "${SKY_CLIENT}" ]; then
        "${SKY_CLIENT}" "$@" >/dev/null 2>&1 || true
    fi
    exit 0
fi

# 4. 发送到本地 HTTP 监听端口
curl -s -X POST "${SERVER_URL}/api/codex/notify" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${TOKEN}" \
     -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true

# 5. 支持链式转发：若系统存在下游 notify 处理程序（如 SkyComputerUseClient），保持透传
SKY_CLIENT="${HOME}/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
if [ -n "${CODEX_CHAIN_NOTIFY:-}" ] && [ -x "${CODEX_CHAIN_NOTIFY}" ]; then
    "${CODEX_CHAIN_NOTIFY}" "$@" >/dev/null 2>&1 || true
elif [ -x "${SKY_CLIENT}" ]; then
    "${SKY_CLIENT}" "$@" >/dev/null 2>&1 || true
fi

exit 0
