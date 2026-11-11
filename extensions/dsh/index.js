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
