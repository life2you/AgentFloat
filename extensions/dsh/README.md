# DeepSeek Harness (dsh) Extension for AgentFloat

本扩展负责在 DeepSeek Harness 桌面端运行过程中监听轮次状态与生命周期事件，并将结算结果自动同步至 macOS 本地 AgentFloat 悬浮卡片。

## 工作机制

1. 监听生命周期事件：
   - `session/event`: 捕获 `turn/end` 权威轮次结束事件
   - `agent/error`: 捕获执行异常并上报
   - `agent/status`: 监听 `running` -> 非 `running` 状态变迁并作为安全兜底
2. 识别状态：
   - `completed`: 正常完成（悬浮卡片醒目提示：**“任务结束 · 请人工验证代码”**）
   - `error`: 执行异常或抛出错误
   - `aborted`: 用户主动中止
3. 通过读取 `~/.agentfloat/auth_token` 自动鉴权，调用 `http://127.0.0.1:41920/api/events` 发送通知。

## 安装与配置

由 AgentFloat 在启动时通过 `AutoIntegrationManager` 自动部署并挂载至 `~/.dsh/profiles/desktop`。
如果 AgentFloat 未启动，扩展将静默跳过，绝不阻塞 DeepSeek Harness Agent 执行循环。
