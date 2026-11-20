#!/usr/bin/env bash
# AgentFloat - Claude Code (CLI) Notify Hook
# 该脚本供 Claude CLI 的 hooks.Stop 与 hooks.StopFailure 配置调用，负责将 Claude 轮次完成/异常事件转交至 AgentFloat

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
import os, sys, json, time, re

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw) if raw else {}
except Exception:
    data = {"last_assistant_message": raw, "status": "unknown"}

hook_event = str(data.get("hook_event_name") or data.get("hookEventName") or "")
session_id = data.get("session_id") or data.get("sessionId") or ""
turn_id = data.get("turn_id") or data.get("turnId") or f"turn-{int(time.time() * 1000)}"
cwd = data.get("cwd") or ""
msg = data.get("last_assistant_message") or data.get("lastAssistantMessage") or data.get("message") or ""
raw_status = data.get("status")
transcript_path = data.get("transcript_path") or data.get("transcriptPath") or ""
stop_reason = str(data.get("stop_reason") or data.get("stopReason") or "")
term_app = data.get("terminal_app") or os.environ.get("TERM_PROGRAM") or ""

# 汇总显式传入的错误字段
error = (
    data.get("error")
    or data.get("error_message")
    or data.get("errorMessage")
    or data.get("error_type")
    or data.get("errorType")
    or data.get("tool_error")
    or data.get("denial_reason")
    or ""
)
if isinstance(error, dict):
    error = json.dumps(error, ensure_ascii=False)
else:
    error = str(error) if error else ""

norm_status = None

# 1. Hook 事件明确为失败 (例如 StopFailure)
if "fail" in hook_event.lower() or "err" in hook_event.lower():
    norm_status = "error"
    if not error:
        error = f"Claude 执行失败 ({hook_event})"

# 2. 显式 error 字段非空
if not norm_status and error.strip():
    norm_status = "error"

# 3. 显式 status 声明判定
if not norm_status and raw_status:
    s_lower = str(raw_status).lower()
    if "fail" in s_lower or "err" in s_lower:
        norm_status = "error"
        if not error:
            error = str(raw_status)
    elif "abort" in s_lower or "cancel" in s_lower:
        norm_status = "aborted"

# 4. stop_reason 判定
if not norm_status and stop_reason:
    sr_lower = stop_reason.lower()
    if "abort" in sr_lower or "cancel" in sr_lower or "interrupt" in sr_lower:
        norm_status = "aborted"
    elif "err" in sr_lower or "fail" in sr_lower:
        norm_status = "error"
        if not error:
            error = f"Stop reason: {stop_reason}"

# 5. 分析 transcript_path: 检查该轮次的执行结果是否以工具错误告终
if not norm_status and transcript_path:
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
            last_tool_result = None
            for line in reversed(lines):
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                
                etype = entry.get("type")
                if etype == "assistant":
                    asst_msg = entry.get("message", {})
                    asst_sr = str(asst_msg.get("stop_reason") or asst_msg.get("stopReason") or "").lower()
                    if "err" in asst_sr or "fail" in asst_sr:
                        norm_status = "error"
                        if not error:
                            error = f"Assistant stop reason: {asst_sr}"
                        break
                    if "abort" in asst_sr or "cancel" in asst_sr:
                        norm_status = "aborted"
                        break
                elif etype == "user":
                    user_msg = entry.get("message", {})
                    content = user_msg.get("content", [])
                    if isinstance(content, list):
                        results = [item for item in content if isinstance(item, dict) and item.get("type") == "tool_result"]
                        if results and last_tool_result is None:
                            last_tool_result = results[-1]
                    if entry.get("userType") or "lastPrompt" in entry or isinstance(content, str):
                        break

            if not norm_status and last_tool_result:
                is_err = last_tool_result.get("is_error")
                c_text = str(last_tool_result.get("content", ""))
                if is_err or "<tool_use_error>" in c_text or re.search(r'\bexit code [1-9]\b', c_text, re.IGNORECASE):
                    norm_status = "error"
                    if not error:
                        first_l = c_text.strip().split("\n")[0].strip()
                        error = first_l[:120] if first_l else "Tool execution failed"
        except Exception:
            pass

# 6. 从 last_assistant_message 中识别错误指示
clean_msg = str(msg or "").strip()
if not norm_status and clean_msg:
    stripped = re.sub(r'^(?:[#>\-*`~_]+|\s+|\[ERROR\]|\[WARNING\])+', '', clean_msg, flags=re.IGNORECASE).strip()
    err_prefix_regex = r'^(?:error|fatal|exception|panic|typeerror|syntaxerror|referenceerror|runtimeerror|build failed|command failed|execution failed|test(?:s)? failed|task failed|operation failed|failed with exit code|process exited with code\s+[1-9]|api error|request failed|anthropic api error|错误|报错|执行失败|构建失败|测试失败|运行失败|命令失败|调用失败|异常退出|发生异常|操作失败)(?:[:：\s\.]|$)'
    if re.search(err_prefix_regex, stripped, re.IGNORECASE):
        norm_status = "error"
        if not error:
            first_line = clean_msg.split("\n")[0].strip()
            error = first_line[:120]

    if not norm_status:
        strong_phrases = [
            "claude code encountered an error",
            "command failed with exit code",
            "failed with exit code",
            "process exited with exit code",
            "rate limit exceeded",
            "credit balance is too low",
            "insufficient quota",
            "overloaded_error"
        ]
        clean_lower = clean_msg.lower()
        for phrase in strong_phrases:
            if phrase in clean_lower:
                norm_status = "error"
                if not error:
                    error = phrase
                break

# 7. 兜底默认值
if not norm_status:
    norm_status = "completed"

if norm_status == "error" and not error:
    error = "Claude 执行过程中发生异常"

msg_snippet = ""
snippet_source = msg or error
if snippet_source:
    first_line = str(snippet_source).strip().split("\n")[0].strip()
    first_line = re.sub(r'^[#>\-*`~_]+\s*', '', first_line).strip()
    if len(first_line) > 35:
        msg_snippet = first_line[:32] + "..."
    else:
        msg_snippet = first_line

default_title = "Claude 执行异常" if norm_status == "error" else ("Claude 任务已中止" if norm_status == "aborted" else "Claude 执行完成")
if norm_status == "error":
    final_title = data.get("title") or (f"Claude 报错: {msg_snippet}" if msg_snippet else default_title)
else:
    final_title = data.get("title") or (f"Claude: {msg_snippet}" if msg_snippet else default_title)

otty_pane_id = os.environ.get("OTTY_PANE_ID") or ""

output = {
    "session_id": session_id,
    "turn_id": turn_id,
    "cwd": cwd,
    "last_assistant_message": msg,
    "status": norm_status,
    "error": error if norm_status == "error" else None,
    "terminal_app": term_app,
    "title": final_title,
    "hook_event_name": hook_event,
    "metadata": {"otty_pane_id": otty_pane_id} if otty_pane_id else None
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
