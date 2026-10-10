# 更新日志 (Changelog)

所有重要的项目演进与版本更迭均记录于此。遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。

## [1.0.3] - 2026-10-10

### 新增与优化 (Added & Improved)
- **Codex 桌面版深度兼容**:
  - 全面支持 OpenAI 官方 Codex 桌面版（基于 `com.openai.codex` / `ChatGPT.app` 与 `codex app-server`）。
  - `TerminalLauncher` 原生集成 `com.openai.codex`，在悬浮卡片中点击激活按钮可一键智能置顶唤醒 Codex 桌面端窗口。
  - `scripts/codex-notify.sh` 优化任务标题提取，自动从 `last_assistant_message` 提炼直观的操作摘要。
  - 文档补充 `~/.codex/config.toml` 配置示例与透明链式转发机制说明。

## [1.0.2] - 2026-10-10

### 修复与优化 (Fixed & Improved)
- **Session 级多轮次智能覆盖**:
  - 同一个 Session（如同一会话多轮交互）的新到达轮次通知自动覆盖更新该 Session 上一个未处理任务，悬浮卡片中不再堆叠该会话的历史过期轮次，始终只保留最新的一条待核对记录。
  - 若前一轮卡片被用户临时隐藏（X），新轮次到达时自动唤醒展示，无需手动打开菜单栏。
  - 启动时自动清理同 Session 历史残留的冗余未处理任务，保持悬浮窗和菜单栏列表精简整洁。

## [1.0.1] - 2026-10-10

### 新增 (Added)
- **视觉设计与品牌图标 (App Icon)**:
  - 全新设计并生成 macOS 原生 Squircle 应用图标（深色宇宙渐变、双层玻璃拟态悬浮卡片堆叠、高精终端提示符 `>` 与贝塞尔曲线 AI 灵动星标 `✦`）。
  - 内置 `scripts/generate-app-icon.py` 自动化多分辨率生成脚本（支持 1024x1024 Master PNG 与 `AppIcon.icns`）。
  - 打包流程（`build-app.sh`）与 `Info.plist` 全面集成原生图标支持。
  - Homebrew Cask 与 GitHub Release 全面集成该原生应用图标。

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
