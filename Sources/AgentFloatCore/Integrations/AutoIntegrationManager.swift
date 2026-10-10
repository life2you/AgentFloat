import Foundation

public struct IntegrationStatus: Sendable {
    public let codexInstalled: Bool
    public let codexConfigured: Bool
    public let piInstalled: Bool
    public let piConfigured: Bool
    public let messages: [String]
    
    public init(
        codexInstalled: Bool,
        codexConfigured: Bool,
        piInstalled: Bool,
        piConfigured: Bool,
        messages: [String]
    ) {
        self.codexInstalled = codexInstalled
        self.codexConfigured = codexConfigured
        self.piInstalled = piInstalled
        self.piConfigured = piConfigured
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
    import os, sys, json

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
    term_app = data.get("terminal_app") or os.environ.get("TERM_PROGRAM") or ""

    if error or "fail" in str(status).lower() or "err" in str(status).lower():
        norm_status = "error"
    elif "abort" in str(status).lower() or "cancel" in str(status).lower():
        norm_status = "aborted"
    else:
        norm_status = "completed"

    msg_snippet = ""
    if msg:
        first_line = str(msg).strip().split("\\n")[0].strip()
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

    if [ -z "${NORMALIZED_PAYLOAD}" ]; then
        NORMALIZED_PAYLOAD="{\\"last_assistant_message\\":\\"Codex 执行结束\\",\\"status\\":\\"completed\\"}"
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
        const msg = messages[i];
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
      let reportedTurns = new Set<string>();

      if (!pi || typeof pi.on !== 'function') return;

      pi.on('before_agent_start', (_event: any, _ctx: any) => {
        sessionStartTime = Date.now();
      });

      pi.on('agent_start', (_event: any, _ctx: any) => {
        sessionStartTime = Date.now();
      });

      pi.on('message_end', (event: any, _ctx: any) => {
        if (event?.message?.role === 'user') {
          const content = event.message.content;
          if (typeof content === 'string') {
            lastPrompt = content;
          } else if (Array.isArray(content)) {
            const textItem = content.find((c: any) => c.type === 'text');
            if (textItem?.text) lastPrompt = textItem.text;
          }
        }
      });

      const handleTurnFinish = async (isAborted: boolean, ctx: any, sourceEvent: string) => {
        const now = Date.now();
        const durationMs = Math.max(0, now - sessionStartTime);
        const sessionId = sessionIdFor(ctx);
        const turnKey = `${sessionId}-${Math.floor(now / 3000)}`;
        if (reportedTurns.has(turnKey)) return;
        reportedTurns.add(turnKey);

        const cwd = ctx?.cwd || process.cwd();
        const prompt = lastPrompt || extractPrompt(ctx?.sessionManager?.getBranch?.() || []);
        const title = prompt ? `Pi: ${truncate(prompt, 35)}` : 'Pi Agent 任务完成';
        const status: 'completed' | 'aborted' = isAborted ? 'aborted' : 'completed';

        const payload: AgentFloatEventPayload = {
          source: 'pi',
          sessionId,
          turnId: `turn-${now}`,
          title,
          promptSummary: prompt ? truncate(prompt, 120) : undefined,
          resultSummary: isAborted ? '用户中止当前任务' : '执行完成，请核对代码变动',
          status,
          errorMessage: undefined,
          cwd,
          terminalApp: ctx?.terminalApp || process.env.TERM_PROGRAM || undefined,
          durationMs,
          metadata: { agent: 'pi', event: sourceEvent },
        };

        await sendToAgentFloat(payload, serverUrl);
      };

      pi.on('agent_end', async (_event: any, ctx: any) => {
        await handleTurnFinish(false, ctx, 'agent_end');
      });

      pi.on('agent_settled', async (event: any, ctx: any) => {
        await handleTurnFinish(Boolean(event?.aborted), ctx, 'agent_settled');
      });
    }

    export default function (pi: any) {
      setupAgentFloatExtension(pi);
    }

    export function activate(context: any) {
      setupAgentFloatExtension(context);
    }
    """

    private static var homeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// 部署自包含的 codex-notify.sh 到 ~/.agentfloat/hooks/codex-notify.sh
    @discardableResult
    public static func ensureHooksDeployed() -> String {
        let hooksDir = homeDir.appendingPathComponent(".agentfloat/hooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o755
        ])
        let hookFile = hooksDir.appendingPathComponent("codex-notify.sh")
        try? embeddedCodexNotifyScript.write(to: hookFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookFile.path)
        return hookFile.path
    }

    /// 自动检测并无感配置 Codex (CLI 与 桌面版)
    @discardableResult
    public static func setupCodex() -> (Bool, String) {
        let codexDir = homeDir.appendingPathComponent(".codex", isDirectory: true)
        guard FileManager.default.fileExists(atPath: codexDir.path) else {
            return (false, "未检测到本地 Codex 环境 (~/.codex)")
        }

        let hookPath = ensureHooksDeployed()
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

    /// 一键全自动检测与接入所有环境
    public static func autoSetupAll() -> IntegrationStatus {
        _ = ensureHooksDeployed()
        
        let (codexOk, codexMsg) = setupCodex()
        let (piOk, piMsg) = setupPi()
        
        let codexInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".codex").path)
        let piInstalled = FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".pi/agent").path)
        
        return IntegrationStatus(
            codexInstalled: codexInstalled,
            codexConfigured: codexOk,
            piInstalled: piInstalled,
            piConfigured: piOk,
            messages: [codexMsg, piMsg]
        )
    }
}
