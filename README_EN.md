# AgentFloat

<p align="center">
  <img src="assets/appicon/AppIcon-1024.png" width="128" height="128" alt="AgentFloat Icon" />
  <br />
  <b>A Lightweight, Always-On-Top Desktop Floating HUD for AI Coding Agent Turn Notifications and Task Tracking on macOS</b>
  <br />
  <i>Zero External Dependencies · Pure Swift 6 & SwiftUI · Local Loopback 127.0.0.1 Only · Never Equate Turn Completion with Code Verification</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2015+-blue?logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0%20%2F%206.1-orange?logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/Dependencies-Zero%20External-brightgreen" alt="Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-purple" alt="License" />
</p>

---

## 💡 Core Philosophy

> ⚠️ **Core Rule: Never equate task completion with code verification!**
> 
> In autonomous Agentic Coding workflows, an Agent finishing its turn or process **only means inference has concluded. It NEVER guarantees that code logic is sound or that tests have been verified by a human.**
> 
> AgentFloat explicitly highlights: **"Task Completed · Manual Code Verification Required"** on all success cards, and provides a streamlined loop with "Inspect Terminal" and "Resolve" actions to enforce deliberate code audits.

---

## ✨ Features

- 🪶 **Zero External Dependencies**:
  Built exclusively on Apple native system frameworks (`Foundation`, `SwiftUI`, `AppKit`, `SQLite3`, `Network.framework`). No NPM, CocoaPods, or third-party SPM packages.
- 🖥 **All-Spaces Floating Panel (`FloatingPanel`)**:
  Utilizes system-level `NSPanel` with `.floating` window level, supporting cross-space and full-screen auxiliary overlays (`canJoinAllSpaces`, `fullScreenAuxiliary`). Configured with `.nonactivatingPanel` so it **never steals keyboard input focus from your active terminal or editor**.
- 🔔 **High-Contrast Visual Feedback**:
  - 🟢 **Green Accent**: Task completed (*Task Completed · Manual Code Verification Required*)
  - 🔴 **Red Accent**: Execution error or aborted (*Task Error · Check Logs*)
  - 🟡 **Yellow Accent**: Unknown status
- 🎯 **One-Click Terminal Activation (`TerminalLauncher`)**:
  Jump directly into your target workspace directory with intelligent support for **Otty** (`io.appmakes.otty`), **Ghostty** (`com.mitchellh.ghostty`), **Apple Terminal** (`com.apple.Terminal`), and **iTerm2** (`com.googlecode.iterm2`).
- 🛡 **Secure Local Loopback**:
  Native HTTP server binds strictly to `127.0.0.1` via `Network.framework` loopback interface. Automatically generates a 32-byte secure token stored at `~/.agentfloat/auth_token` with strict POSIX `0600` permissions.
- 🗄 **Concurrent SQLite Storage (`SQLiteTaskStore`)**:
  Actor-isolated native SQLite3 C API wrapper with WAL mode and unique deduplication index `(source, session_id, turn_id)` to prevent notification storms from duplicate webhooks or retries.
- 🧩 **Zero-Configuration Ecosystem Integration**:
  Turnkey out-of-the-box! Upon launch, AgentFloat automatically detects local installations of **Codex (CLI & Desktop)** and **Pi Agent**, seamlessly configuring notification hooks and extensions with zero manual setup.

---

## 🏛 Architecture

```
AgentFloat
├── AgentFloatCore (Core Library)
│   ├── Models/AgentTask.swift          # Entity and task status definitions
│   ├── Storage/SQLiteTaskStore.swift   # Actor-isolated SQLite3 C API, WAL transactions & deduplication
│   ├── Network/AuthTokenManager.swift  # 0600 POSIX token management
│   ├── Network/LocalHttpServer.swift   # Network.framework NWListener HTTP server
│   ├── Integrations/TerminalLauncher.swift # Otty / Ghostty / Terminal / iTerm2 integration
│   └── Engine/TaskManager.swift        # Task coordinator & verification state management
│
├── AgentFloatApp (macOS Menu Bar Application)
│   ├── App/AppDelegate.swift           # NSApp accessory lifecycle & status item
│   ├── Windows/FloatingPanel.swift     # Top-right non-activating floating NSPanel
│   ├── Views/FloatingCardView.swift    # Visual floating card HUD
│   └── Views/MenuBarView.swift         # Menu bar popover task & history inspector
│
├── AgentFloatCLI (Command Line Tool)
│   └── main.swift                      # Diagnostic, emit, list, resolve, and test commands
│
├── extensions/pi/                      # Official Pi Agent extension
└── scripts/codex-notify.sh             # Codex CLI notification hook script
```

---

## 🚀 Installation & Quick Start

### Requirements
- macOS 15.0 (Sequoia) or later
- Swift 6.0+ (Only required when compiling from source)

### Method 1: Install via Homebrew (Recommended)

```bash
brew install --cask life2you/tap/agentfloat
```
> 💡 Installing via Homebrew Cask places `AgentFloat.app` into `/Applications` and automatically links the `agentfloat` command-line utility into your PATH.

### Method 2: Build from Source

```bash
# Clone and enter directory
cd path/to/AgentFloat

# Build all targets in debug mode
make build

# Run unit tests
make test

# Package macOS App Bundle
make app
```
The packaged application will be generated at `build/AgentFloat.app`. Launch it directly:
```bash
open build/AgentFloat.app
```

### Install CLI Tool (If building from source)

```bash
make install-cli
# Default installed to /usr/local/bin/agentfloat
```

---

## 🛠 CLI Usage

`agentfloat` provides a complete command-line interface for scripts and integrations:

```bash
# 1. Emit simulated completed task (Green HUD)
agentfloat test --success

# 2. Emit simulated error task (Red HUD)
agentfloat test --error

# 3. Emit custom agent task
agentfloat emit \
  --source pi \
  --status completed \
  --title "Implement Auth Flow" \
  --cwd "$(pwd)" \
  --summary "Generated AuthController.swift and tests passed"

# 4. List pending tasks
agentfloat list

# 5. List all tasks (including history)
agentfloat list --all

# 6. Mark a task as resolved
agentfloat resolve <task-id>

# 7. Print local auth token
agentfloat token

# 8. Check health status
agentfloat health
```

---

## 🔌 Ecosystem Integration (Zero-Config · Out-of-the-Box)

> 🚀 **Turnkey Design**: Upon launching `AgentFloat.app` or running `agentfloat setup`, the system automatically detects local environments and seamlessly completes all integrations—**no manual config file editing required**!

### 1. Codex Automatic Integration (CLI & Desktop)
- Deploys a self-contained hook to `~/.agentfloat/hooks/codex-notify.sh` and automatically mounts it into `~/.codex/config.toml`.
- Supports transparent notification chaining with official desktop clients (such as `SkyComputerUseClient`).

### 2. Pi Agent Automatic Integration
- Automatically installs the native extension to `~/.pi/agent/extensions/agentfloat.ts`, automatically loaded by Pi across all workspaces.

### 3. One-Click Verification & Repair
If you install Codex or Pi later, click **"Re-detect"** in the macOS menu bar popover, or run anytime in terminal:
```bash
agentfloat setup
```

---

## 📡 HTTP API Reference

The local server listens on `http://127.0.0.1:41920`. Endpoints require the auth token header:
- `Authorization: Bearer <TOKEN>` or `X-AgentFloat-Token: <TOKEN>`

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Health check (public) |
| `POST` | `/api/events` | Ingest generic agent event |
| `POST` | `/api/codex/notify` | Ingest Codex CLI notification payload |
| `POST` | `/api/test/emit` | Emit simulated HUD test card |
| `GET` | `/api/tasks` | List tasks (`?filter=pending` or `?filter=all`) |
| `POST` | `/api/tasks/{id}/resolve` | Mark task as resolved |
| `POST` | `/api/tasks/{id}/dismiss` | Dismiss floating card without resolving |

---

## 💻 Terminal Integration (`TerminalLauncher`)

AgentFloat natively supports 4 macOS terminal applications when clicking **"Inspect Terminal"**:

1. **Otty** (`io.appmakes.otty`)
2. **Ghostty** (`com.mitchellh.ghostty`)
3. **Apple Terminal** (`com.apple.Terminal`)
4. **iTerm2** (`com.googlecode.iterm2`)

**Activation Logic**:
- If `terminalApp` is explicitly passed in payload, that terminal is preferred;
- Otherwise, inspects currently running terminals;
- Falls back to default terminal or Apple Terminal;
- Automatically navigates (`cd`) to the task's `cwd`.

---

## ❓ FAQ

**Q: Why does the card still display "Manual Code Verification Required" when the Agent succeeded?**
> **A:** This is intentional and central to AgentFloat's design. AI Coding Agents can hallucinate or introduce edge-case regressions. A completed turn means the machine stopped; you should review diffs and verify tests before marking it "Resolved".

**Q: Will the floating card steal keyboard focus while I am typing?**
> **A:** No. The panel is configured with AppKit's `.nonactivatingPanel`, ensuring your active editor or terminal window never loses focus.

**Q: What is the difference between clicking "X" and "Resolve"?**
> **A:**
> - Clicking "X" (Dismiss): Hides the card from screen, but keeps the task pending in the menu bar.
> - Clicking "Resolve": Confirms you have verified the code changes and archives the task into history.

---

## 📄 License

Licensed under the [MIT License](LICENSE).  
Copyright (c) 2026 AgentFloat Contributors.
