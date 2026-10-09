import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

/**
 * Pi Agent Extension for AgentFloat
 * 兼容 Pi 官方扩展接口 (export default function(pi))
 * 监听 Pi 生命周期事件，将完成/异常/中止状态上报至 AgentFloat 悬浮窗。
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

export function setupAgentFloatExtension(pi: any) {
  const serverUrl = process.env.AGENTFLOAT_URL || 'http://127.0.0.1:41920';
  let sessionStartTime = Date.now();
  let lastPrompt: string | undefined = undefined;

  if (!pi || typeof pi.on !== 'function') return;

  // 记录提示词
  pi.on('before_agent_start', (event: any, ctx: any) => {
    sessionStartTime = Date.now();
    if (event?.systemPrompt) {
      // 保留状态
    }
  });

  pi.on('agent_start', (event: any, ctx: any) => {
    sessionStartTime = Date.now();
  });

  // 提取用户最新提问
  pi.on('message_end', (event: any, ctx: any) => {
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

  // 监听 Agent 结束及最终结算状态
  pi.on('agent_settled', async (event: any, ctx: any) => {
    const durationMs = Math.max(0, Date.now() - sessionStartTime);
    const isAborted = Boolean(event?.aborted);

    const sessionId = (typeof ctx?.sessionManager?.getSessionId === 'function')
      ? ctx.sessionManager.getSessionId()
      : `pi-session-${Date.now()}`;

    const turnId = `turn-${Date.now()}`;
    const cwd = ctx?.cwd || process.cwd();

    let status: 'completed' | 'error' | 'aborted' = 'completed';
    let errorMessage: string | undefined = undefined;

    if (isAborted) {
      status = 'aborted';
    }

    const title = lastPrompt ? `Pi: ${truncate(lastPrompt, 35)}` : 'Pi Agent 任务结束';

    const payload: AgentFloatEventPayload = {
      source: 'pi',
      sessionId,
      turnId,
      title,
      promptSummary: lastPrompt ? truncate(lastPrompt, 120) : undefined,
      resultSummary: isAborted ? '用户中止执行' : '执行完成',
      status,
      errorMessage,
      cwd,
      durationMs,
      metadata: {
        agent: 'pi',
      },
    };

    await sendToAgentFloat(payload, serverUrl);
  });
}

// 兼容官方扩展导出格式: export default function(pi: ExtensionAPI)
export default function (pi: any) {
  setupAgentFloatExtension(pi);
}

// 兼容 activate(context) 导出格式
export function activate(context: any) {
  setupAgentFloatExtension(context);
}
