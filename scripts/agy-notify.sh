#!/usr/bin/env bash
# AgentFloat - Antigravity (agy) Notify Hook
# 该脚本供 Antigravity (~/.gemini/config/hooks.json) 的 Stop 钩子调用，
# 负责将 agy CLI / Antigravity 2.0 / IDE 的轮次完成与异常事件转交至 AgentFloat。

set -euo pipefail

SERVER_URL="${AGENTFLOAT_URL:-http://127.0.0.1:41920}"
TOKEN_FILE="${HOME}/.agentfloat/auth_token"

# 1. 提取传入参数或由标准输入接收 (Antigravity Hooks 通过 stdin 传入 JSON)
PAYLOAD=""
if [ "$#" -gt 0 ]; then
    PAYLOAD="${*: -1}"
elif [ ! -t 0 ]; then
    PAYLOAD=$(cat)
fi

if [ -z "${PAYLOAD}" ]; then
    printf '{}\n'
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
    printf '{}\n'
    exit 0
fi

# 3. 使用系统自带 Python3 解析 Antigravity Stop Hook 载荷并标准化
NORMALIZED_PAYLOAD=$(RAW_PAYLOAD="${PAYLOAD}" python3 - <<'EOF' 2>/dev/null || echo ""
import os, sys, json, time, re

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw) if raw else {}
except Exception:
    data = {"last_assistant_message": raw, "status": "unknown"}

hook_event = str(data.get("hookEventName") or data.get("hook_event_name") or "Stop")
conversation_id = data.get("conversationId") or data.get("conversation_id") or data.get("sessionId") or data.get("session_id") or ""
execution_num = data.get("executionNum") if data.get("executionNum") is not None else data.get("execution_num")
turn_id = data.get("turnId") or data.get("turn_id")
if not turn_id:
    suffix = f"-{execution_num}" if execution_num is not None else ""
    turn_id = f"turn-{int(time.time() * 1000)}{suffix}"

workspace_paths = data.get("workspacePaths") or data.get("workspace_paths") or []
cwd = data.get("cwd") or (workspace_paths[0] if isinstance(workspace_paths, list) and workspace_paths else "") or ""

prompt_summary = str(data.get("lastUserInput") or data.get("last_user_input") or data.get("promptSummary") or data.get("prompt_summary") or "")
msg = str(data.get("lastAssistantMessage") or data.get("last_assistant_message") or data.get("message") or "")
raw_status = data.get("status")
termination_reason = str(data.get("terminationReason") or data.get("termination_reason") or "")
transcript_path = str(data.get("transcriptPath") or data.get("transcript_path") or "")
model_name = str(data.get("modelName") or data.get("model_name") or "")

# 识别运行宿主：Antigravity 桌面端 / IDE / CLI 终端
term_app = data.get("terminalApp") or data.get("terminal_app") or ""
if not term_app:
    if "/.gemini/antigravity/" in transcript_path or "/.gemini/antigravity-ide/" in transcript_path:
        term_app = "antigravity"
    else:
        term_app = os.environ.get("TERM_PROGRAM") or "agy"

error = (
    data.get("error")
    or data.get("errorMessage")
    or data.get("error_message")
    or data.get("errorType")
    or data.get("error_type")
    or ""
)
if isinstance(error, dict):
    error = json.dumps(error, ensure_ascii=False)
else:
    error = str(error) if error else ""

# 4. 读取 transcript.jsonl 末尾以补充最新回复文本或检测步骤异常
transcript_step_error = False
if transcript_path:
    expanded_path = os.path.expanduser(transcript_path)
    if os.path.exists(expanded_path):
        try:
            size = os.path.getsize(expanded_path)
            read_size = min(size, 32768)
            with open(expanded_path, "rb") as f:
                if size > read_size:
                    f.seek(size - read_size)
                chunk = f.read().decode("utf-8", errors="ignore")

            lines = [l.strip() for l in chunk.strip().split("\n") if l.strip()]
            for line in reversed(lines):
                try:
                    entry = json.loads(line)
                except Exception:
                    continue

                etype = str(entry.get("type") or "")
                estatus = str(entry.get("status") or "").upper()
                content = entry.get("content")

                if etype == "USER_INPUT":
                    break
                if etype == "PLANNER_RESPONSE":
                    if not msg and isinstance(content, str) and content.strip():
                        msg = content.strip()
                    if estatus == "ERROR":
                        transcript_step_error = True
                        if not error and isinstance(content, str) and content.strip():
                            error = content.strip().split("\n")[0][:160]
                    break
        except Exception:
            pass

# 5. 状态判定（优先依据 terminationReason 与显式 error）
norm_status = None
reason_upper = termination_reason.strip().upper()

if error.strip():
    norm_status = "error"
elif reason_upper:
    if reason_upper == "USER_CANCELED":
        norm_status = "aborted"
    elif reason_upper == "ERROR":
        norm_status = "error"
        error = "Antigravity 执行异常 (ERROR)"
    elif reason_upper in ("MAX_INVOCATIONS", "MAX_FORCED_INVOCATIONS", "MAX_TOKEN_BUDGET_EXCEEDED"):
        norm_status = "error"
        error = f"Antigravity 执行达到限制 ({termination_reason})"
    elif reason_upper in ("NO_TOOL_CALL", "TERMINAL_STEP_TYPE", "TERMINAL_CUSTOM_HOOK", "INJECTED_RESPONSE"):
        norm_status = "completed"

if not norm_status and raw_status:
    s_lower = str(raw_status).lower()
    if "abort" in s_lower or "cancel" in s_lower:
        norm_status = "aborted"
    elif "fail" in s_lower or "err" in s_lower:
        norm_status = "error"
        if not error:
            error = str(raw_status)
    elif "complete" in s_lower or "success" in s_lower or s_lower in ("done", "ok"):
        norm_status = "completed"

if not norm_status and transcript_step_error:
    norm_status = "error"
    if not error:
        error = "Antigravity 执行过程中发生异常"

if not norm_status:
    norm_status = "completed"

if norm_status == "error" and not error:
    error = "Antigravity 执行过程中发生异常"

def make_snippet(text):
    if not text:
        return ""
    first_line = str(text).strip().split("\n")[0].strip()
    first_line = re.sub(r'^[#>\-*`~_]+\s*', '', first_line).strip()
    if len(first_line) > 35:
        return first_line[:32] + "..."
    return first_line

msg_snippet = make_snippet(msg or prompt_summary or error)
default_title = (
    "Antigravity 执行异常"
    if norm_status == "error"
    else ("Antigravity 任务已中止" if norm_status == "aborted" else "Antigravity 执行完成")
)
if norm_status == "error":
    err_snippet = make_snippet(error or msg)
    final_title = data.get("title") or (f"Antigravity 报错: {err_snippet}" if err_snippet else default_title)
else:
    final_title = data.get("title") or (f"Antigravity: {msg_snippet}" if msg_snippet else default_title)

otty_pane_id = "" if term_app == "antigravity" else (os.environ.get("OTTY_PANE_ID") or "")

output = {
    "conversationId": conversation_id,
    "turnId": turn_id,
    "executionNum": execution_num,
    "cwd": cwd,
    "workspacePaths": workspace_paths if isinstance(workspace_paths, list) else None,
    "lastAssistantMessage": msg if msg else None,
    "lastUserInput": prompt_summary[:120] if prompt_summary else None,
    "status": norm_status,
    "error": error if norm_status == "error" else None,
    "terminationReason": termination_reason if termination_reason else None,
    "hookEventName": hook_event,
    "transcriptPath": transcript_path if transcript_path else None,
    "modelName": model_name if model_name else None,
    "terminalApp": term_app,
    "title": final_title,
    "metadata": {"otty_pane_id": otty_pane_id} if otty_pane_id else None
}

print(json.dumps({k: v for k, v in output.items() if v is not None}, ensure_ascii=False))
EOF
)

if [ -n "${NORMALIZED_PAYLOAD}" ]; then
    # 4. 发送到本地 HTTP 监听端口 (/api/agy/notify 优先，失败降级 /api/events)，短超时防止阻塞 agy
    curl -s --connect-timeout 1 --max-time 2 -X POST "${SERVER_URL}/api/agy/notify" \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer ${TOKEN}" \
         -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || \
    curl -s --connect-timeout 1 --max-time 2 -X POST "${SERVER_URL}/api/events" \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer ${TOKEN}" \
         -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true
fi

# 5. Antigravity Hook 契约要求向 stdout 输出有效 JSON 对象
printf '{}\n'
exit 0
