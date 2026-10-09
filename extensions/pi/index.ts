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

  // 记录用户最新提示词
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

    const sessionId = (typeof ctx?.sessionManager?.getSessionId === 'function')
      ? ctx.sessionManager.getSessionId()
      : `pi-${process.pid}`;

    // 基于时间和 prompt 生成防抖 turn 唯一标识
    const turnKey = `${sessionId}-${Math.floor(now / 3000)}`;
    if (reportedTurns.has(turnKey)) {
      return;
    }
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
      durationMs,
      metadata: {
        agent: 'pi',
        event: sourceEvent,
      },
    };

    await sendToAgentFloat(payload, serverUrl);
  };

  // 监听 agent_end 和 agent_settled 双重保险
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
