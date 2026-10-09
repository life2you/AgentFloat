# 贡献指南 (Contributing to AgentFloat)

感谢你关注并参与 **AgentFloat** 项目！

AgentFloat 致力于为开发者提供一个**极致轻量、零外部第三方依赖、安全透明**的桌面端 AI Coding Agent 悬浮任务提示与状态追踪工具。

---

## 核心设计准则

在提交任何代码或 Pull Request 之前，请务必遵循以下核心原则：

1. **严禁将任务结束等同于代码验证通过**：
   - Agent 的执行结束（`completed`）仅代表进程轮次完成，**绝对不代表代码逻辑已通过人工核验**。
   - 界面上必须保持醒目的“任务结束 · 请人工验证代码”提示。
2. **零第三方依赖 (Zero External Dependencies)**：
   - 仅允许使用 Apple 系统原生框架（Foundation, AppKit, SwiftUI, Network, SQLite3）。
   - 严禁引入 CocoaPods / SPM 第三方仓库或包依赖。
3. **安全第一**：
   - HTTP 服务仅监听 `127.0.0.1` 环回接口，拒绝外部网络监听。
   - 强制使用本地自动生成的安全 Token（文件权限为严格的 POSIX `0600`）。
4. **轻量与非侵入式交互**：
   - 悬浮窗面板不抢占终端和编辑器的打字输入焦点 (`.nonactivatingPanel`)。

---

## 本地开发指南

### 环境要求
- macOS 15.0+ (Sequoia)
- Swift 6.0+

### 常用命令

```bash
# 编译所有 target
make build

# 运行单元测试
make test

# 打包 AgentFloat.app
make app

# 安装本地 CLI 工具
make install-cli
```

---

## 提交代码流程

1. Fork 本仓库并新建特性分支 (`feature/your-feature-name` 或 `fix/your-fix-name`)。
2. 确保你的修改通过了单元测试：
   ```bash
   swift test --disable-xctest
   ```
3. 确保代码风格清晰，变量和方法命名表意明确。
4. 提交清晰的 Git Commit Message，例如：
   - `feat(core): add support for custom webhook headers`
   - `fix(store): resolve transaction lock issue in WAL mode`
5. 创建 Pull Request 并描述你的改动意图与测试验证结果。
