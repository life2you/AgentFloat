# 更新日志 (Changelog)

所有重要的项目演进与版本更迭均记录于此。遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。

## [1.0.0] - 2026-03-31

### 新增 (Added)
- **AgentFloatCore**:
  - `AgentTask` 模型，全面支持 Pi、Codex CLI 及自定义 Agent 来源。
  - `SQLiteTaskStore` actor 封装，内置系统 SQLite3 原生 C API，支持 WAL 高并发模式、事务安全以及基于 `(source, session_id, turn_id)` 的去重唯一索引。
  - `LocalHttpServer`，基于原生 Network.framework `NWListener` 实现 127.0.0.1 HTTP 环回服务端。
  - `AuthTokenManager`，开机自动生成 32 字节高强度安全 Token 并存储于 `~/.agentfloat/auth_token`（POSIX 权限 0600）。
  - `TerminalLauncher`，支持一键定位并激活 Otty、Ghostty、Terminal 与 iTerm2 终端。
  - `TaskManager` 核心任务管理器，落地**“严禁将任务结束等同于代码验证通过”**的设计原则。
- **AgentFloatApp**:
  - 常驻菜单栏 Accessory 应用，支持实时未处理任务数徽标及下拉菜单。
  - 右上角非侵入式全屏置顶悬浮卡片 (`NSPanel` / `FloatingPanel`)。
  - 醒目悬浮卡片视图 (`FloatingCardView`)，不同状态色彩区分（绿色完成、红色异常/中止、黄色未知），内置“查看终端”与“已处理”交互。
- **AgentFloatCLI**:
  - 提供 `agentfloat` 命令行工具，支持 `emit`、`codex-notify`、`test`、`list`、`resolve`、`token` 与 `health` 子命令。
- **生态扩展**:
  - Pi Agent 官方扩展 (`extensions/pi/index.ts`)，监听生命周期事件。
  - Codex CLI 通知脚本 (`scripts/codex-notify.sh`)。
- **构建与分发**:
  - `scripts/build-app.sh` 一键打包并本地签名 `AgentFloat.app`。
  - Makefile 与 GitHub Actions CI 自动化流程。
