import Foundation
import AppKit

public struct IntegrationStatus: Sendable {
    public let codexInstalled: Bool
    public let codexConfigured: Bool
    public let piInstalled: Bool
    public let piConfigured: Bool
    public let claudeInstalled: Bool
    public let claudeConfigured: Bool
    public let dshInstalled: Bool
    public let dshConfigured: Bool
    public let messages: [String]
    
    public init(
        codexInstalled: Bool,
        codexConfigured: Bool,
        piInstalled: Bool,
        piConfigured: Bool,
        claudeInstalled: Bool,
        claudeConfigured: Bool,
        dshInstalled: Bool = false,
        dshConfigured: Bool = false,
        messages: [String]
    ) {
        self.codexInstalled = codexInstalled
        self.codexConfigured = codexConfigured
        self.piInstalled = piInstalled
        self.piConfigured = piConfigured
        self.claudeInstalled = claudeInstalled
        self.claudeConfigured = claudeConfigured
        self.dshInstalled = dshInstalled
        self.dshConfigured = dshConfigured
        self.messages = messages
    }
}

public struct AutoIntegrationManager: Sendable {
    
    /// 内置的 Codex 通知挂载脚本模板
    public static let embeddedCodexNotifyScript: String = """
    #!/usr/bin/env bash
    # AgentFloat - Codex Notify Hook (Auto-generated)
    set -euo pipefail

    SERVER_URL="${AGENTFLOAT_URL:-http://127.0.0.1:41920}"
    TOKEN_FILE="${HOME}/.agentfloat/auth_token"

    PAYLOAD=""
    if [ "$#" -gt 0 ]; then
        PAYLOAD="${*: -1}"
    elif [ ! -t 0 ]; then
        PAYLOAD=$(cat)
    fi

    if [ -z "${PAYLOAD}" ]; then
        exit 0
    fi

    TOKEN=""
    if [ -n "${AGENTFLOAT_TOKEN:-}" ]; then
        TOKEN="${AGENTFLOAT_TOKEN}"
    elif [ -f "${TOKEN_FILE}" ]; then
        TOKEN=$(cat "${TOKEN_FILE}" | tr -d '[:space:]')
    fi

    if [ -z "${TOKEN}" ]; then
        exit 0
    fi

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

    # 1. 过滤内部子任务 / 标题生成 Turn
    raw_msg = str(msg or "").strip()
    if raw_msg.startswith("{") and raw_msg.endswith("}"):
        try:
            parsed = json.loads(raw_msg)
            if isinstance(parsed, dict) and "title" in parsed and ("description" in parsed or len(parsed) <= 3):
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
            term_app = "codex"
        else:
            term_app = os.environ.get("TERM_PROGRAM") or "codex"

    if error or "fail" in str(status).lower() or "err" in str(status).lower():
        norm_status = "error"
    elif "abort" in str(status).lower() or "cancel" in str(status).lower():
        norm_status = "aborted"
    else:
        norm_status = "completed"

    msg_snippet = ""
    snippet_source = msg or error
    if snippet_source:
        first_line = str(snippet_source).strip().split("\\n")[0].strip()
        if len(first_line) > 35:
            msg_snippet = first_line[:32] + "..."
        else:
            msg_snippet = first_line

    default_title = "Codex 执行异常" if norm_status == "error" else ("Codex 任务已中止" if norm_status == "aborted" else "Codex 执行完成")
    final_title = data.get("title") or (f"Codex: {msg_snippet}" if msg_snippet else default_title)

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

    if [ -z "${NORMALIZED_PAYLOAD}" ] || [ "${NORMALIZED_PAYLOAD}" = "IGNORE" ]; then
        SKY_CLIENT="${HOME}/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
        if [ -n "${CODEX_CHAIN_NOTIFY:-}" ] && [ -x "${CODEX_CHAIN_NOTIFY}" ]; then
            "${CODEX_CHAIN_NOTIFY}" "$@" >/dev/null 2>&1 || true
        elif [ -x "${SKY_CLIENT}" ]; then
            "${SKY_CLIENT}" "$@" >/dev/null 2>&1 || true
        fi
        exit 0
    fi

    curl -s -X POST "${SERVER_URL}/api/codex/notify" \\
         -H "Content-Type: application/json" \\
         -H "Authorization: Bearer ${TOKEN}" \\
         -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true

    SKY_CLIENT="${HOME}/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
    if [ -n "${CODEX_CHAIN_NOTIFY:-}" ] && [ -x "${CODEX_CHAIN_NOTIFY}" ]; then
        "${CODEX_CHAIN_NOTIFY}" "$@" >/dev/null 2>&1 || true
    elif [ -x "${SKY_CLIENT}" ]; then
        "${SKY_CLIENT}" "$@" >/dev/null 2>&1 || true
    fi

    exit 0
    """

    /// 内置的 Claude Code (CLI) 通知挂载脚本模板
    public static let embeddedClaudeNotifyScript: String = """
    #!/usr/bin/env bash
    # AgentFloat - Claude Code (CLI) Notify Hook (Auto-generated)
    set -euo pipefail

    SERVER_URL="${AGENTFLOAT_URL:-http://127.0.0.1:41920}"
    TOKEN_FILE="${HOME}/.agentfloat/auth_token"

    PAYLOAD=""
    if [ "$#" -gt 0 ]; then
        PAYLOAD="${*: -1}"
    elif [ ! -t 0 ]; then
        PAYLOAD=$(cat)
    fi

    if [ -z "${PAYLOAD}" ]; then
        exit 0
    fi

    TOKEN=""
    if [ -n "${AGENTFLOAT_TOKEN:-}" ]; then
        TOKEN="${AGENTFLOAT_TOKEN}"
    elif [ -f "${TOKEN_FILE}" ]; then
        TOKEN=$(cat "${TOKEN_FILE}" | tr -d '[:space:]')
    fi

    if [ -z "${TOKEN}" ]; then
        exit 0
    fi

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

    if error or "fail" in str(status).lower() or "err" in str(status).lower():
        norm_status = "error"
    elif "abort" in str(status).lower() or "cancel" in str(status).lower():
        norm_status = "aborted"
    else:
        norm_status = "completed"

    msg_snippet = ""
    snippet_source = msg or error
    if snippet_source:
        first_line = str(snippet_source).strip().split("\\n")[0].strip()
        if len(first_line) > 35:
            msg_snippet = first_line[:32] + "..."
        else:
            msg_snippet = first_line

    default_title = "Claude 执行异常" if norm_status == "error" else ("Claude 任务已中止" if norm_status == "aborted" else "Claude 执行完成")
    final_title = data.get("title") or (f"Claude: {msg_snippet}" if msg_snippet else default_title)

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

    curl -s -X POST "${SERVER_URL}/api/claude/notify" \\
         -H "Content-Type: application/json" \\
         -H "Authorization: Bearer ${TOKEN}" \\
         -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || \\
    curl -s -X POST "${SERVER_URL}/api/events" \\
         -H "Content-Type: application/json" \\
         -H "Authorization: Bearer ${TOKEN}" \\
         -d "${NORMALIZED_PAYLOAD}" >/dev/null 2>&1 || true

    exit 0
    """

    /// 内置的 Pi Agent 官方 TypeScript 扩展模板
    public static let embeddedPiExtensionTypeScript: String = """
    import * as fs from 'fs';
    import * as path from 'path';
    import * as os from 'os';

    export interface AgentFloatEventPayload {
      source: 'pi';
      sessionId: string;
      turnId: string;
      title: string;
      promptSummary?: string;
      resultSummary?: string;
      status: 'completed' | 'error' | 'aborted' | 'unknown';
      errorMessage?: string;
      cwd?: string;
      terminalApp?: string;
      durationMs?: number;
      metadata?: Record<string, string>;
    }

    function loadAuthToken(): string | null {
      if (process.env.AGENTFLOAT_TOKEN) {
        return process.env.AGENTFLOAT_TOKEN.trim();
      }
      const tokenPath = path.join(os.homedir(), '.agentfloat', 'auth_token');
      try {
        if (fs.existsSync(tokenPath)) {
          return fs.readFileSync(tokenPath, 'utf-8').trim();
        }
      } catch {}
      return null;
    }

    async function sendToAgentFloat(payload: AgentFloatEventPayload, serverUrl: string): Promise<void> {
      const token = loadAuthToken();
      if (!token) return;

      try {
        await fetch(`${serverUrl}/api/events`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
          },
          body: JSON.stringify(payload),
        });
      } catch {}
    }

    function truncate(str: string, maxLen: number): string {
      const trimmed = str.trim();
      if (trimmed.length <= maxLen) return trimmed;
      return trimmed.slice(0, maxLen - 3) + '...';
    }

    function extractPrompt(messages: any[]): string | undefined {
      if (!Array.isArray(messages)) return undefined;
      for (let i = messages.length - 1; i >= 0; i--) {
        const item = messages[i];
        const msg = item?.type === 'message' && item?.message ? item.message : item;
        if (msg?.role === 'user') {
          const content = msg.content;
          if (typeof content === 'string') return content;
          if (Array.isArray(content)) {
            const textItem = content.find((c: any) => c.type === 'text');
            if (textItem?.text) return textItem.text;
          }
        }
      }
      return undefined;
    }

    function sessionIdFor(ctx: any): string {
      try {
        const file = ctx && ctx.sessionManager && ctx.sessionManager.getSessionFile
          ? ctx.sessionManager.getSessionFile()
          : null;
        if (file) return path.basename(String(file)).replace(/\\.jsonl$/, "");
      } catch {}
      try {
        if (ctx && ctx.sessionManager && ctx.sessionManager.getSessionId) {
          return ctx.sessionManager.getSessionId();
        }
      } catch {}
      return `pid-${process.pid}`;
    }

    export function setupAgentFloatExtension(pi: any) {
      const serverUrl = process.env.AGENTFLOAT_URL || 'http://127.0.0.1:41920';
      let sessionStartTime = Date.now();
      let lastPrompt: string | undefined = undefined;
      let lastOutcome: 'completed' | 'error' | 'aborted' = 'completed';
      let lastErrorMessage: string | undefined = undefined;
      let settleTimer: ReturnType<typeof setTimeout> | undefined = undefined;

      if (!pi || typeof pi.on !== 'function') return;

      const resetRunState = () => {
        sessionStartTime = Date.now();
        lastOutcome = 'completed';
        lastErrorMessage = undefined;
        if (settleTimer) {
          clearTimeout(settleTimer);
          settleTimer = undefined;
        }
      };

      pi.on('before_agent_start', (event: any, _ctx: any) => {
        resetRunState();
        if (event?.prompt && typeof event.prompt === 'string') {
          lastPrompt = event.prompt;
        }
      });

      pi.on('agent_start', (_event: any, _ctx: any) => {
        sessionStartTime = Date.now();
        if (settleTimer) {
          clearTimeout(settleTimer);
          settleTimer = undefined;
        }
      });

      pi.on('message_end', (event: any, _ctx: any) => {
        const msg = event?.message;
        if (!msg) return;

        if (msg.role === 'user') {
          const content = msg.content;
          if (typeof content === 'string') {
            lastPrompt = content;
          } else if (Array.isArray(content)) {
            const textItem = content.find((c: any) => c.type === 'text');
            if (textItem?.text) lastPrompt = textItem.text;
          }
        } else if (msg.role === 'assistant') {
          if (msg.stopReason === 'error' || msg.errorMessage) {
            lastOutcome = 'error';
            if (msg.errorMessage) {
              lastErrorMessage = String(msg.errorMessage);
            }
          } else if (msg.stopReason === 'aborted') {
            lastOutcome = 'aborted';
          } else {
            lastOutcome = 'completed';
            lastErrorMessage = undefined;
          }
        }
      });

      pi.on('turn_end', (event: any, _ctx: any) => {
        if (event?.outcome === 'error') {
          lastOutcome = 'error';
          if (event?.message?.errorMessage) {
            lastErrorMessage = String(event.message.errorMessage);
          }
        } else if (event?.outcome === 'aborted') {
          lastOutcome = 'aborted';
        } else if (event?.outcome === 'completed') {
          lastOutcome = 'completed';
          lastErrorMessage = undefined;
        }
      });

      pi.on('agent_before_settle', (event: any, _ctx: any) => {
        if (event?.outcome === 'error') {
          lastOutcome = 'error';
        } else if (event?.outcome === 'aborted') {
          lastOutcome = 'aborted';
        } else if (event?.outcome === 'completed') {
          lastOutcome = 'completed';
          lastErrorMessage = undefined;
        }
      });

      const inspectMessagesOutcome = (messages: any[]): { outcome?: 'completed' | 'error' | 'aborted'; errorMessage?: string } => {
        if (!Array.isArray(messages)) return {};
        for (let i = messages.length - 1; i >= 0; i--) {
          const msg = messages[i];
          if (msg?.role === 'assistant') {
            if (msg.stopReason === 'error' || msg.errorMessage) {
              return {
                outcome: 'error',
                errorMessage: msg.errorMessage ? String(msg.errorMessage) : undefined,
              };
            }
            if (msg.stopReason === 'aborted') {
              return { outcome: 'aborted' };
            }
            return { outcome: 'completed' };
          }
        }
        return {};
      };

      const handleTurnFinish = async (
        options: { isAborted?: boolean; isError?: boolean; errorMessage?: string; messages?: any[] },
        ctx: any,
        sourceEvent: string
      ) => {
        const now = Date.now();
        const durationMs = Math.max(0, now - sessionStartTime);
        const sessionId = sessionIdFor(ctx);

        const branchEntries = ctx?.sessionManager?.getBranch?.() || [];
        const branchMessages = branchEntries
          .filter((e: any) => e?.type === 'message' && e?.message)
          .map((e: any) => e.message);
        const msgCheck = inspectMessagesOutcome(options.messages || branchMessages);

        const isAborted = Boolean(options.isAborted) || lastOutcome === 'aborted' || msgCheck.outcome === 'aborted';
        const isError = !isAborted && (Boolean(options.isError) || lastOutcome === 'error' || msgCheck.outcome === 'error');
        const finalErrorMsg = isError
          ? (options.errorMessage || lastErrorMessage || msgCheck.errorMessage || 'Agent 执行过程中发生异常')
          : undefined;

        const status: 'completed' | 'error' | 'aborted' = isAborted
          ? 'aborted'
          : isError
          ? 'error'
          : 'completed';

        const cwd = ctx?.cwd || process.cwd();
        const prompt = lastPrompt || extractPrompt(branchMessages.length > 0 ? branchMessages : branchEntries);
        const defaultTitle = status === 'error'
          ? 'Pi Agent 执行异常'
          : status === 'aborted'
          ? 'Pi Agent 任务已中止'
          : 'Pi Agent 任务完成';
        const title = prompt ? `Pi: ${truncate(prompt, 35)}` : defaultTitle;

        const resultSummary = status === 'error'
          ? truncate(finalErrorMsg || '任务异常，请检查错误日志', 120)
          : status === 'aborted'
          ? '用户中止当前任务'
          : '执行完成，请核对代码变动';

        const payload: AgentFloatEventPayload = {
          source: 'pi',
          sessionId,
          turnId: `turn-${now}`,
          title,
          promptSummary: prompt ? truncate(prompt, 120) : undefined,
          resultSummary,
          status,
          errorMessage: finalErrorMsg ? truncate(finalErrorMsg, 200) : undefined,
          cwd,
          terminalApp: ctx?.terminalApp || process.env.TERM_PROGRAM || undefined,
          durationMs,
          metadata: { agent: 'pi', event: sourceEvent },
        };

        await sendToAgentFloat(payload, serverUrl);
      };

      pi.on('agent_end', (event: any, ctx: any) => {
        const msgCheck = inspectMessagesOutcome(event?.messages);
        if (msgCheck.outcome === 'error') {
          lastOutcome = 'error';
          if (msgCheck.errorMessage) lastErrorMessage = msgCheck.errorMessage;
        } else if (msgCheck.outcome === 'aborted') {
          lastOutcome = 'aborted';
        }

        if (settleTimer) clearTimeout(settleTimer);
        settleTimer = setTimeout(() => {
          settleTimer = undefined;
          void handleTurnFinish({ messages: event?.messages }, ctx, 'agent_end');
        }, 300);
      });

      pi.on('agent_settled', async (event: any, ctx: any) => {
        if (settleTimer) {
          clearTimeout(settleTimer);
          settleTimer = undefined;
        }
        await handleTurnFinish(
          {
            isAborted: Boolean(event?.aborted),
            isError: event?.outcome === 'error' || Boolean(event?.error),
            errorMessage: event?.errorMessage || (typeof event?.error === 'string' ? event.error : event?.error?.message),
          },
          ctx,
          'agent_settled'
        );
      });
    }

    export default function (pi: any) {
      setupAgentFloatExtension(pi);
    }

    export function activate(context: any) {
      setupAgentFloatExtension(context);
    }
    """

    /// 内置的 DeepSeek Harness 插件 package.json
    public static let embeddedDshPluginPackageJson: String = #"""
    {
      "name": "agentfloat-dsh",
      "version": "1.0.0",
      "description": "DeepSeek Harness extension for AgentFloat desktop notifications",
      "type": "module",
      "main": "index.js",
      "peerDependencies": {
        "@deepseek-ai/schemastery": "^3"
      },
      "dsh": {
        "bundle": {
          "patch": "./cordis.patch.yml"
        }
      }
    }
    """#

    /// 内置的 DeepSeek Harness 插件 cordis.patch.yml
    public static let embeddedDshPluginCordisPatchYml: String = #"""
    - insert:
        - id: agentfloat-dsh
          name: agentfloat-dsh
    """#

    /// 内置的 DeepSeek Harness 插件 index.js
    public static let embeddedDshPluginIndexJs: String = #"""
    import fs from 'fs';
    import path from 'path';
    import os from 'os';

    export const name = 'agentfloat-dsh';

    function loadAuthToken() {
      if (process.env.AGENTFLOAT_TOKEN) {
        const envToken = process.env.AGENTFLOAT_TOKEN.trim();
        if (envToken) return envToken;
      }
      try {
        const tokenPath = path.join(os.homedir(), '.agentfloat', 'auth_token');
        if (fs.existsSync(tokenPath)) {
          const fileToken = fs.readFileSync(tokenPath, 'utf8').trim();
          if (fileToken) return fileToken;
        }
      } catch {}
      return null;
    }

    function extractFirstLineSummary(data) {
      if (!data) return '';
      const errText = data.error?.message ?? (typeof data.error === 'string' ? data.error : '');
      const candidate = data.summary || data.title || data.lastAssistantMessage || data.message || errText || data.prompt || '';
      if (typeof candidate !== 'string' || !candidate.trim()) return '';
      const firstLine = candidate.trim().split(/[\r\n]+/)[0].trim();
      return firstLine.slice(0, 32);
    }

    function debugLog(message) {
      try {
        if (process.env.AGENTFLOAT_DSH_DEBUG === '1') {
          fs.appendFileSync('/tmp/agentfloat-dsh.log', `[${new Date().toISOString()}] ${message}\n`);
        }
      } catch {}
    }

    export function apply(ctx, config = {}) {
      debugLog(`apply() invoked with config keys: ${Object.keys(config || {}).join(',')}`);
      const token = loadAuthToken();
      if (!token) {
        debugLog('no auth token found, plugin disabled');
        return;
      }
      debugLog('auth token loaded, registering listeners');

      // 诊断：记录所有事件分发（仅在 AGENTFLOAT_DSH_DEBUG=1 时）
      try {
        ctx.on('internal/dispatch', (type, name) => {
          try {
            if (name && (name.includes('agent') || name.includes('session') || name.includes('turn'))) {
              debugLog(`dispatch: ${type} ${name}`);
            }
          } catch {}
        });
        debugLog('internal/dispatch 监听已注册');
      } catch (e) {
        debugLog(`internal/dispatch 注册失败: ${e?.message}`);
      }

      const serverBaseUrl = (process.env.AGENTFLOAT_URL || 'http://127.0.0.1:41920').replace(/\/+$/, '');
      const eventsUrl = `${serverBaseUrl}/api/events`;
      const minTurnDurationMs = typeof config?.minTurnDurationMs === 'number' ? config.minTurnDurationMs : 3000;

      async function sendToAgentFloat(payload) {
        try {
          await fetch(eventsUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`,
            },
            body: JSON.stringify(payload),
          }).catch(() => {});
        } catch {}
      }

      // dsh 的 Cordis 实现：未 declare inject 的属性不能直接读（会抛 “cannot get property without inject”）
      // 因此所有 ctx.xxx 访问必须通过安全包装器。
      function safeGet(obj, key) {
        try {
          const v = obj[key];
          return v === undefined ? undefined : v;
        } catch {
          return undefined;
        }
      }
      function getWorkspaceCwd() {
        const workspace = safeGet(ctx, 'workspace');
        if (!workspace) return undefined;
        return safeGet(workspace, 'root') || safeGet(workspace, 'cwd') || undefined;
      }
      function getSessionIdFromCtx() {
        const session = safeGet(ctx, 'session');
        if (!session) return undefined;
        const id = safeGet(session, 'id');
        return typeof id === 'string' ? id : undefined;
      }
      debugLog('ctx 安全访问器已就绪');

      const agentStateMap = new Map();
      const reportedTurns = new Set();
      let lastErrorInfo = null; // 记录最近一次 agent/error，防止 turn/end 无 error 字段或重复覆盖

      function recordReportedTurn(sessionId, turnId) {
        const key = `${sessionId}:${turnId}`;
        if (reportedTurns.has(key)) return false;
        if (reportedTurns.size > 2000) reportedTurns.clear();
        reportedTurns.add(key);
        return true;
      }

      // 1. 监听 session/event (event.type === 'turn/end' 是权威轮次结束)
      try {
        ctx.on('session/event', (sessionArg, eventArg) => {
          try {
            debugLog(`session/event received: type=${eventArg?.type}`);
            let session = sessionArg;
            let event = eventArg;
            if (!event && session && session.event) {
              event = session.event;
              session = session.session;
            }
            if (!event || event.type !== 'turn/end') return;

            const data = event.data || {};
            const turnId = data.turnId || data.turn?.id || (data.status ? `turn-${Date.now()}` : undefined) || `turn-${Date.now()}`;
            const sessionId = (typeof session === 'string' ? session : session?.id) || data.sessionId || getSessionIdFromCtx() || 'unknown-session';

            // 若同一轮刚由 agent/error 上报过（3秒内），则不再用 turn/end 覆盖
            if (lastErrorInfo && (Date.now() - lastErrorInfo.at < 3000) &&
                (lastErrorInfo.turnId === turnId || lastErrorInfo.sessionId === sessionId || sessionId === 'unknown-session' || lastErrorInfo.sessionId === 'unknown-session')) {
              if (lastErrorInfo.reported) {
                debugLog(`turn/end skipped because agent/error already reported for ${sessionId}/${turnId}`);
                return;
              }
            }

            if (!recordReportedTurn(sessionId, turnId)) return;

            // 标记所有关联 agent 的 turnEnd 已上报
            for (const [k, v] of agentStateMap.entries()) {
              if (!v.sessionId || v.sessionId === sessionId || sessionId === 'unknown-session') {
                v.turnEndReported = true;
              }
            }

            let status = 'completed';
            const rawStatus = String(data.status || data.turn?.status || data.outcome || '').toLowerCase();
            if (rawStatus) {
              if (rawStatus.includes('err') || rawStatus.includes('fail')) status = 'error';
              else if (rawStatus.includes('abort') || rawStatus.includes('cancel')) status = 'aborted';
              else if (rawStatus.includes('complete') || rawStatus.includes('success') || rawStatus === 'done' || rawStatus === 'ok') status = 'completed';
              else status = 'unknown';
            }
            if (data.error || data.turn?.error || data.isError) {
              status = 'error';
            }

            let errorMessage = undefined;
            const errObj = data.error || data.turn?.error;
            if (errObj) {
              const raw = errObj?.message ?? (typeof errObj === 'string' ? errObj : JSON.stringify(errObj));
              if (raw) errorMessage = String(raw).slice(0, 200);
            } else if (status === 'error' && lastErrorInfo?.errorMessage) {
              errorMessage = lastErrorInfo.errorMessage;
            }

            const summary = extractFirstLineSummary(data);
            const defaultTitle = status === 'error'
              ? 'DeepSeek Harness 执行异常'
              : status === 'aborted'
              ? 'DeepSeek Harness 已中止'
              : 'DeepSeek Harness 执行完成';
            const title = summary ? `DeepSeek Harness: ${summary}` : defaultTitle;

            let resultSummary = status === 'error'
              ? (errorMessage || '任务异常，请检查错误日志')
              : '执行完成，请核对代码变动';
            if (status === 'aborted') resultSummary = '任务已中止';
            else if (status === 'unknown') resultSummary = '状态未知';

            const cwd = (typeof data.cwd === 'string' && data.cwd) || getWorkspaceCwd();

            let durationMs = undefined;
            if (typeof data.durationMs === 'number') {
              durationMs = data.durationMs;
            } else if (typeof data.duration === 'number') {
              durationMs = data.duration;
            }

            sendToAgentFloat({
              source: 'dsh',
              sessionId,
              turnId,
              title,
              resultSummary,
              status,
              errorMessage,
              cwd,
              durationMs,
              metadata: { plugin: 'agentfloat-dsh', event: 'session/event' },
            }).then(() => debugLog(`turn/end reported: ${sessionId}/${turnId} status=${status}`));
          } catch (e) {
            debugLog(`session/event handler error: ${e?.message} ${e?.stack?.split('\n')[1] || ''}`);
          }
        });
      } catch (e) {
        debugLog(`session/event 注册失败: ${e?.message}`);
      }

      // 2. 监听 agent/error
      try {
        ctx.on('agent/error', (arg1, arg2) => {
          try {
            debugLog(`agent/error received (不 JSON 序列化): keys=${arg1 && typeof arg1 === 'object' ? Object.keys(arg1).join(',') : typeof arg1}`);
            let error, turn, step, agentObj;
            if (arg1 && typeof arg1 === 'object' && ('error' in arg1 || 'turn' in arg1 || 'agent' in arg1)) {
              error = arg1.error ?? arg2;
              turn = arg1.turn;
              step = arg1.step;
              agentObj = arg1.agent;
            } else {
              error = arg1;
              turn = arg2;
            }

            const stepLabel = step?.name ?? (typeof step === 'string' ? step : undefined);
            const rawError = error?.message ?? (typeof error === 'string' ? error : (error ? JSON.stringify(error) : 'Unknown error'));
            const errorMessage = String(rawError).slice(0, 200);
            const turnId = turn?.id || (typeof turn === 'string' ? turn : `turn-err-${Date.now()}`);

            let activeSessionId = agentObj?.sessionId || agentObj?.session?.id || turn?.sessionId || getSessionIdFromCtx();
            if (!activeSessionId) {
              for (const [, v] of agentStateMap.entries()) {
                if (v.sessionId && v.sessionId !== 'unknown-session') {
                  activeSessionId = v.sessionId;
                  break;
                }
              }
            }
            const sessionId = activeSessionId || 'unknown-session';

            lastErrorInfo = {
              sessionId,
              turnId,
              errorMessage,
              at: Date.now(),
              reported: true,
            };

            if (!recordReportedTurn(sessionId, turnId)) return;

            // 标记 agentStateMap 中的 turn 已结束
            for (const [k, v] of agentStateMap.entries()) {
              v.turnEndReported = true;
            }

            const summary = errorMessage.split(/[\r\n]+/)[0].trim().slice(0, 32);
            const title = summary ? `DeepSeek Harness: ${summary}` : 'DeepSeek Harness 执行异常';

            sendToAgentFloat({
              source: 'dsh',
              sessionId,
              turnId,
              title,
              resultSummary: errorMessage || '任务异常，请检查错误日志',
              status: 'error',
              errorMessage,
              cwd: getWorkspaceCwd(),
              metadata: { plugin: 'agentfloat-dsh', event: 'agent/error', ...(stepLabel ? { step: stepLabel } : {}) },
            });
          } catch (e) {
            debugLog(`agent/error handler error: ${e?.message}`);
          }
        });
      } catch (e) {
        debugLog(`agent/error 注册失败: ${e?.message}`);
      }

      // 3. 监听 agent/status (running -> idle 兜底)
      try {
        ctx.on('agent/status', (arg1, arg2) => {
          try {
            debugLog(`agent/status received (不 JSON 序列化): arg1 keys=${arg1 && typeof arg1 === 'object' ? Object.keys(arg1).join(',') : typeof arg1}, arg2=${typeof arg2 === 'string' ? arg2 : typeof arg2}`);
            let agent, status;
            if (arg1 && typeof arg1 === 'object' && 'status' in arg1) {
              agent = arg1.agent;
              status = arg1.status;
            } else {
              agent = arg1;
              status = arg2;
            }

            const agentKey = agent || 'default-agent';
            const statusStr = typeof status === 'string' ? status.toLowerCase() : '';
            debugLog(`agent/status parsed: agentKey=${agentKey}, status=${statusStr}`);

            if (statusStr === 'running') {
              debugLog('agent/status running');
              const sessionId = agent?.sessionId || agent?.session?.id || getSessionIdFromCtx() || 'unknown-session';
              lastErrorInfo = null;
              agentStateMap.set(agentKey, {
                startedAt: Date.now(),
                sessionId,
                turnEndReported: false,
              });
              return;
            }

            const state = agentStateMap.get(agentKey);
            if (state && !state.turnEndReported) {
              const now = Date.now();
              const durationMs = Math.max(0, now - state.startedAt);
              const isErrorOrAbort = statusStr.includes('err') || statusStr.includes('fail') || statusStr.includes('abort') || statusStr.includes('cancel') || Boolean(lastErrorInfo);
              if (durationMs >= minTurnDurationMs || isErrorOrAbort) {
                state.turnEndReported = true;
                const turnId = `turn-${now}`;
                const sessionId = state.sessionId || 'unknown-session';

                if (!recordReportedTurn(sessionId, turnId)) return;

                // 兜底上报：仅在 turn/end 与 agent/error 都未触发时到达；按非 running 状态映射，避免把异常误报为完成
                let fallbackStatus = 'completed';
                let fallbackResult = '执行完成，请核对代码变动';
                let fallbackTitle = 'DeepSeek Harness 执行完成';
                let fallbackError = undefined;
                if (statusStr === 'error' || statusStr === 'failed' || lastErrorInfo) {
                  fallbackStatus = 'error';
                  fallbackError = lastErrorInfo?.errorMessage;
                  fallbackResult = fallbackError || '任务异常，请检查错误日志';
                  fallbackTitle = 'DeepSeek Harness 执行异常';
                } else if (statusStr === 'aborted' || statusStr === 'cancelled' || statusStr === 'canceled') {
                  fallbackStatus = 'aborted';
                  fallbackResult = '任务已中止';
                  fallbackTitle = 'DeepSeek Harness 已中止';
                } else if (statusStr && statusStr !== 'idle' && statusStr !== 'completed' && statusStr !== 'success' && statusStr !== 'done') {
                  fallbackStatus = 'unknown';
                  fallbackResult = '状态未知';
                }

                sendToAgentFloat({
                  source: 'dsh',
                  sessionId,
                  turnId,
                  title: fallbackTitle,
                  resultSummary: fallbackResult,
                  status: fallbackStatus,
                  errorMessage: fallbackError,
                  durationMs,
                  cwd: getWorkspaceCwd(),
                  metadata: { plugin: 'agentfloat-dsh', event: 'agent/status' },
                });
              }
            }
          } catch (e) {
            debugLog(`agent/status handler error: ${e?.message}`);
          }
        });
      } catch (e) {
        debugLog(`agent/status 注册失败: ${e?.message}`);
      }
    }

    """#

    private static var homeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// 部署自包含的通知脚本到 ~/.agentfloat/hooks/
    @discardableResult
    public static func ensureHooksDeployed() -> (codex: String, claude: String) {
        let hooksDir = homeDir.appendingPathComponent(".agentfloat/hooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o755
        ])
        let codexHookFile = hooksDir.appendingPathComponent("codex-notify.sh")
        try? embeddedCodexNotifyScript.write(to: codexHookFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: codexHookFile.path)

        let claudeHookFile = hooksDir.appendingPathComponent("claude-notify.sh")
        try? embeddedClaudeNotifyScript.write(to: claudeHookFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: claudeHookFile.path)

        return (codexHookFile.path, claudeHookFile.path)
    }

    /// 自动检测并无感配置 Codex (CLI 与 桌面版)
    @discardableResult
    public static func setupCodex() -> (Bool, String) {
        let codexDir = homeDir.appendingPathComponent(".codex", isDirectory: true)
        guard FileManager.default.fileExists(atPath: codexDir.path) else {
            return (false, "未检测到本地 Codex 环境 (~/.codex)")
        }

        let hookPath = ensureHooksDeployed().codex
        let configToml = codexDir.appendingPathComponent("config.toml")
        
        var tomlContent = (try? String(contentsOf: configToml, encoding: .utf8)) ?? ""
        let notifyDeclaration = "notify = [\"\(hookPath)\", \"turn-ended\"]"
        
        if tomlContent.contains("codex-notify.sh") {
            // 已配置，检查是否需要修正为标准路径 ~/.agentfloat/hooks/codex-notify.sh
            if !tomlContent.contains(hookPath) {
                let regexPattern = #"(?m)^notify\s*=.*$"#
                if let regex = try? NSRegularExpression(pattern: regexPattern) {
                    let range = NSRange(location: 0, length: tomlContent.utf16.count)
                    tomlContent = regex.stringByReplacingMatches(in: tomlContent, options: [], range: range, withTemplate: notifyDeclaration)
                    try? tomlContent.write(to: configToml, atomically: true, encoding: .utf8)
                    return (true, "已自动校准 Codex 通知挂载至标准路径: \(hookPath)")
                }
            }
            return (true, "Codex 已就绪（已配置通知联动）")
        }

        // 备份原有配置
        let backupFile = codexDir.appendingPathComponent("config.toml.bak")
        try? tomlContent.write(to: backupFile, atomically: true, encoding: .utf8)

        // 写入新配置
        if tomlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tomlContent = "\(notifyDeclaration)\n"
        } else if tomlContent.contains("notify =") || tomlContent.contains("notify=") {
            // 替换已有 notify
            let regexPattern = #"(?m)^notify\s*=.*$"#
            if let regex = try? NSRegularExpression(pattern: regexPattern) {
                let range = NSRange(location: 0, length: tomlContent.utf16.count)
                tomlContent = regex.stringByReplacingMatches(in: tomlContent, options: [], range: range, withTemplate: notifyDeclaration)
            } else {
                tomlContent += "\n\(notifyDeclaration)\n"
            }
        } else {
            // 追加到文件头部
            tomlContent = "\(notifyDeclaration)\n\n" + tomlContent
        }

        do {
            try tomlContent.write(to: configToml, atomically: true, encoding: .utf8)
            return (true, "已自动无感注入 Codex 通知挂载 (~/.codex/config.toml)")
        } catch {
            return (false, "写入 Codex 配置失败: \(error.localizedDescription)")
        }
    }

    /// 自动检测并无感安装 Pi Agent 官方扩展
    @discardableResult
    public static func setupPi() -> (Bool, String) {
        let piAgentDir = homeDir.appendingPathComponent(".pi/agent", isDirectory: true)
        guard FileManager.default.fileExists(atPath: piAgentDir.path) else {
            return (false, "未检测到本地 Pi Agent 环境 (~/.pi/agent)")
        }

        let extDir = piAgentDir.appendingPathComponent("extensions", isDirectory: true)
        try? FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o755
        ])

        let targetExtFile = extDir.appendingPathComponent("agentfloat.ts")
        
        // 如果原本是断链或非标准文件，先清理
        if FileManager.default.fileExists(atPath: targetExtFile.path) {
            try? FileManager.default.removeItem(at: targetExtFile)
        }

        do {
            try embeddedPiExtensionTypeScript.write(to: targetExtFile, atomically: true, encoding: .utf8)
            return (true, "已自动无感安装 Pi Agent 官方扩展 (~/.pi/agent/extensions/agentfloat.ts)")
        } catch {
            return (false, "安装 Pi 扩展失败: \(error.localizedDescription)")
        }
    }

    /// 自动检测并无感配置 Claude CLI (Claude Code)
    @discardableResult
    public static func setupClaude() -> (Bool, String) {
        let claudeDir = homeDir.appendingPathComponent(".claude", isDirectory: true)
        guard FileManager.default.fileExists(atPath: claudeDir.path) else {
            return (false, "未检测到本地 Claude CLI 环境 (~/.claude)")
        }

        let hookPath = ensureHooksDeployed().claude
        let settingsFile = claudeDir.appendingPathComponent("settings.json")
        
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }
        
        // 备份原有配置
        let backupFile = claudeDir.appendingPathComponent("settings.json.bak")
        if let originalData = try? Data(contentsOf: settingsFile) {
            try? originalData.write(to: backupFile)
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var stopHooks = hooks["Stop"] as? [[String: Any]] ?? []
        
        let alreadyConfigured = stopHooks.contains { entry in
            if let subHooks = entry["hooks"] as? [[String: Any]] {
                return subHooks.contains { h in
                    (h["command"] as? String)?.contains("claude-notify.sh") == true
                }
            }
            return false
        }
        
        if alreadyConfigured {
            return (true, "Claude Code 已就绪（已配置通知联动）")
        }
        
        let newHookEntry: [String: Any] = [
            "hooks": [
                [
                    "type": "command",
                    "command": hookPath
                ]
            ]
        ]
        
        stopHooks.append(newHookEntry)
        hooks["Stop"] = stopHooks
        settings["hooks"] = hooks
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsFile, options: .atomic)
            return (true, "已自动无感注入 Claude Code 通知挂载 (~/.claude/settings.json)")
        } catch {
            return (false, "写入 Claude 配置失败: \(error.localizedDescription)")
        }
    }

    /// 部署 DeepSeek Harness 扩展插件至 ~/.agentfloat/extensions/dsh/
    @discardableResult
    public static func ensureDshPluginDeployed() -> (Bool, String) {
        let dshDir = homeDir.appendingPathComponent(".agentfloat/extensions/dsh", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dshDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o755
            ])
            let pkgFile = dshDir.appendingPathComponent("package.json")
            try embeddedDshPluginPackageJson.write(to: pkgFile, atomically: true, encoding: .utf8)
            
            let patchFile = dshDir.appendingPathComponent("cordis.patch.yml")
            try embeddedDshPluginCordisPatchYml.write(to: patchFile, atomically: true, encoding: .utf8)
            
            let indexFile = dshDir.appendingPathComponent("index.js")
            try embeddedDshPluginIndexJs.write(to: indexFile, atomically: true, encoding: .utf8)
            
            return (true, dshDir.path)
        } catch {
            return (false, "部署 dsh 插件文件失败: \(error.localizedDescription)")
        }
    }

    /// 自动检测并无感配置 DeepSeek Harness (dsh 桌面版)
    @discardableResult
    public static func setupDsh() -> (Bool, String) {
        let dshHome = homeDir.appendingPathComponent(".dsh", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dshHome.path) else {
            return (false, "未检测到本地 DeepSeek Harness 环境 (~/.dsh)")
        }

        let (deployed, deployMsg) = ensureDshPluginDeployed()
        guard deployed else {
            return (false, deployMsg)
        }
        let pluginPath = deployMsg

        let desktopProfileDir = homeDir.appendingPathComponent(".dsh/profiles/desktop", isDirectory: true)
        guard FileManager.default.fileExists(atPath: desktopProfileDir.path) else {
            return (false, "DeepSeek Harness 桌面版 profile 未初始化（请先启动一次桌面应用后重试）")
        }

        let desktopPkgFile = desktopProfileDir.appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: desktopPkgFile.path) {
            let content = (try? String(contentsOf: desktopPkgFile, encoding: .utf8)) ?? ""
            if content.contains("agentfloat-dsh") {
                return (true, "DeepSeek Harness 已就绪（已配置通知联动）")
            }
        }

        let isRunning = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.deepseek.dsh"
        }
        if isRunning {
            return (false, "请完全退出 DeepSeek Harness 桌面应用后重新检测（运行期间 profile 有写锁）")
        }

        var cliCandidates = [
            "/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh"
        ]
        // dsh 桌面端注册命令会创建 /usr/local/bin/dsh（桌面菜单 Manage dsh Command…），若存在则优先
        if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/dsh") {
            cliCandidates.insert("/usr/local/bin/dsh", at: 0)
        }
        // 兜底：PATH 中的 dsh（用户自行安装的 npm 版本等）
        if let pathDsh = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map({ URL(fileURLWithPath: String($0)).appendingPathComponent("dsh").path })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            cliCandidates.append(pathDsh)
        }
        guard let dshCliPath = cliCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return (false, "未找到 DeepSeek Harness CLI (dsh)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: dshCliPath)
        process.arguments = ["plugin", "--profile", "desktop", "add", pluginPath]
        process.currentDirectoryURL = homeDir

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (true, "已自动无感安装 DeepSeek Harness 通知插件 (~/.dsh/profiles/desktop)")
            } else {
                return (false, "dsh 插件安装失败: \(process.terminationStatus)")
            }
        } catch {
            return (false, "执行 dsh 安装命令失败: \(error.localizedDescription)")
        }
    }

    /// 一键全自动检测与接入所有环境
    public static func autoSetupAll() -> IntegrationStatus {
        _ = ensureHooksDeployed()
        
        let (codexOk, codexMsg) = setupCodex()
        let (piOk, piMsg) = setupPi()
        let (claudeOk, claudeMsg) = setupClaude()
        let (dshOk, dshMsg) = setupDsh()
        
        let codexInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".codex").path)
        let piInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".pi/agent").path)
        let claudeInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".claude").path)
        let dshInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".dsh").path)
        
        return IntegrationStatus(
            codexInstalled: codexInstalled,
            codexConfigured: codexOk,
            piInstalled: piInstalled,
            piConfigured: piOk,
            claudeInstalled: claudeInstalled,
            claudeConfigured: claudeOk,
            dshInstalled: dshInstalled,
            dshConfigured: dshOk,
            messages: [codexMsg, piMsg, claudeMsg, dshMsg]
        )
    }
}
