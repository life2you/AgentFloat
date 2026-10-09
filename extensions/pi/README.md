# Pi Extension for AgentFloat

本扩展负责在 Pi Agent 运行过程中监听轮次状态，并将结算结果自动同步至 macOS 本地 AgentFloat 悬浮卡片。

## 工作机制

1. 监听生命周期事件：
   - `agent_start`: 记录轮次起始时间
   - `turn_end` / `agent_settled` / `agent_end`: 汇总任务结果
2. 识别状态：
   - `completed`: 正常完成（悬浮卡片醒目提示：**“任务结束 · 请人工验证代码”**）
   - `error`: 执行异常或抛出错误
   - `aborted`: 用户主动中止
3. 通过读取 `~/.agentfloat/auth_token` 自动鉴权，调用 `http://127.0.0.1:41920/api/events` 发送通知。

## 安装与配置

在 Pi 的配置文件或扩展目录中引入该扩展即可。
如果 AgentFloat 未启动，扩展将静默跳过，不会中断 Pi 本身的运行。
