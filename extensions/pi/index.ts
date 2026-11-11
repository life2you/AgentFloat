import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

/**
 * Pi Agent Extension for AgentFloat
 * 兼容 Pi 官方扩展接口 (export default function(pi))
 * 监听 Pi 生命周期事件，在任务结束/异常/中止时上报至 AgentFloat 悬浮窗。
 */

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
  } catch {
    // 忽略异常
  }
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
  } catch {
    // 本地服务未开启或网络不可达时静默忽略，不阻塞 Pi 正常流程
  }
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
    if (file) return path.basename(String(file)).replace(/\.jsonl$/, "");
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

  // 记录用户最新提示词与 Assistant 执行结果状态
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

  // 记录 Turn 结束与最终结算边界的 outcome
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
      metadata: {
        agent: 'pi',
        event: sourceEvent,
      },
    };

    await sendToAgentFloat(payload, serverUrl);
  };

  // agent_settled 为权威最终结算事件；对旧版本没有 agent_settled 的情况用 agent_end 延迟兜底
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
