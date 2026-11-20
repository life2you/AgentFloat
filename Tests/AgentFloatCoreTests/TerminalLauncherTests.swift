import Testing
@testable import AgentFloatCore

@Suite("TerminalLauncher Tests")
struct TerminalLauncherTests {
    @Test("终端映射识别")
    func terminalMapping() {
        #expect(SupportedTerminal.from(identifier: "ghostty") == .ghostty)
        #expect(SupportedTerminal.from(identifier: "Ghostty") == .ghostty)
        #expect(SupportedTerminal.from(identifier: "otty") == .otty)
        #expect(SupportedTerminal.from(identifier: "iterm") == .iterm2)
        #expect(SupportedTerminal.from(identifier: "iterm2") == .iterm2)
        #expect(SupportedTerminal.from(identifier: "warp") == .warp)
        #expect(SupportedTerminal.from(identifier: "wezterm") == .wezterm)
        #expect(SupportedTerminal.from(identifier: "alacritty") == .alacritty)
        #expect(SupportedTerminal.from(identifier: "vscode") == .vscode)
        #expect(SupportedTerminal.from(identifier: "cursor") == .cursor)
        #expect(SupportedTerminal.from(identifier: "codex") == .codex)
        #expect(SupportedTerminal.from(identifier: "chatgpt") == .codex)
        #expect(SupportedTerminal.from(identifier: "dsh") == .dsh)
        #expect(SupportedTerminal.from(identifier: "deepseek") == .dsh)
        #expect(SupportedTerminal.from(identifier: "agy") == .antigravity)
        #expect(SupportedTerminal.from(identifier: "antigravity") == .antigravity)
        #expect(SupportedTerminal.from(identifier: "terminal") == .terminal)
        #expect(SupportedTerminal.from(identifier: "apple") == .terminal)
        #expect(SupportedTerminal.from(identifier: "unknown_shell") == nil)
    }
    
    @Test("Bundle ID 配置")
    func bundleIdentifiers() {
        #expect(SupportedTerminal.otty.rawValue == "io.appmakes.otty")
        #expect(SupportedTerminal.ghostty.rawValue == "com.mitchellh.ghostty")
        #expect(SupportedTerminal.terminal.rawValue == "com.apple.Terminal")
        #expect(SupportedTerminal.iterm2.rawValue == "com.googlecode.iterm2")
        #expect(SupportedTerminal.codex.rawValue == "com.openai.codex")
        #expect(SupportedTerminal.dsh.rawValue == "com.deepseek.dsh")
        #expect(SupportedTerminal.antigravity.rawValue == "com.google.antigravity")
    }
    
    @Test("当前活跃终端识别")
    func activeTerminalDetection() {
        let detected = TerminalLauncher.detectActiveTerminal()
        #expect(SupportedTerminal.allCases.contains(detected))
    }
    
    @Test("终端与应用操作文案与图标适配")
    func actionTitlesAndIcons() {
        #expect(SupportedTerminal.codex.actionTitle == "应用")
        #expect(SupportedTerminal.codex.actionIconName == "macwindow")
        #expect(!SupportedTerminal.codex.isTerminal)
        
        #expect(SupportedTerminal.dsh.actionTitle == "应用")
        #expect(SupportedTerminal.dsh.actionIconName == "macwindow")
        #expect(!SupportedTerminal.dsh.isTerminal)
        
        #expect(SupportedTerminal.antigravity.actionTitle == "应用")
        #expect(SupportedTerminal.antigravity.actionIconName == "macwindow")
        #expect(!SupportedTerminal.antigravity.isTerminal)
        
        #expect(SupportedTerminal.ghostty.actionTitle == "终端")
        #expect(SupportedTerminal.ghostty.actionIconName == "terminal")
        #expect(SupportedTerminal.ghostty.isTerminal)
    }

    @Test("Otty Pane 精确匹配：避免主目录前缀误跳到第一条 Tab")
    func ottyPaneMatchingAccuracy() {
        let home = "/Users/tester"
        let panes: [TerminalLauncher.OttyPaneItem] = [
            .init(
                id: "p_first_tab",
                tab_id: "t_first",
                window_id: "w_1",
                cwd: "/Users/tester/vibeCodes/worktrees/proj/feature-a",
                agent: "Pi",
                agent_session_id: "pi-session-1",
                process: "pi"
            ),
            .init(
                id: "p_claude_tab",
                tab_id: "t_claude",
                window_id: "w_1",
                cwd: "/Users/tester/vibeCodes/worktrees/proj/feature-b",
                agent: "Claude Code",
                agent_session_id: "claude-session-1",
                process: "claude"
            ),
            .init(
                id: "p_agy_repo",
                tab_id: "t_agy_repo",
                window_id: "w_1",
                cwd: "/Users/tester/vibeCodes/github/AgentFloat",
                agent: "Google Antigravity CLI",
                agent_session_id: "",
                process: "agy --conversation=1a5c8c34-7849-46ec-b408-e4103add8e64"
            ),
            .init(
                id: "p_home_agy",
                tab_id: "t_home_agy",
                window_id: "w_1",
                cwd: "/Users/tester",
                agent: "Google Antigravity CLI",
                agent_session_id: "",
                process: "agy"
            ),
            .init(
                id: "p_home_other",
                tab_id: "t_home_other",
                window_id: "w_1",
                cwd: "/Users/tester",
                agent: "Pi",
                agent_session_id: "pi-session-home",
                process: "pi"
            )
        ]

        // 1. OTTY_PANE_ID 精确匹配（即使同目录有多个相同 agent Tab，也能锁定具体 Pane）
        let byPaneId = TerminalLauncher.selectBestOttyPane(
            from: panes,
            cwd: "/Users/tester",
            sessionId: "any",
            source: "pi",
            metadata: ["otty_pane_id": "home_other"],
            homeDirectory: home
        )
        #expect(byPaneId?.id == "p_home_other")

        // 2. 主目录任务绝不能误匹配第一条子目录 Tab，应精确命中 /Users/tester + Google Antigravity CLI
        let byHomeCwd = TerminalLauncher.selectBestOttyPane(
            from: panes,
            cwd: "/Users/tester",
            sessionId: "241a1d02-unknown",
            source: "agy",
            metadata: nil,
            homeDirectory: home
        )
        #expect(byHomeCwd?.id == "p_home_agy")

        // 3. Session ID 可从 agy process 参数中匹配
        let byProcessSession = TerminalLauncher.selectBestOttyPane(
            from: panes,
            cwd: nil,
            sessionId: "1a5c8c34-7849-46ec-b408-e4103add8e64",
            source: "agy",
            metadata: nil,
            homeDirectory: home
        )
        #expect(byProcessSession?.id == "p_agy_repo")

        // 4. 子目录任务匹配最近的祖先目录，不匹配更浅的 /Users/tester
        let bySubdir = TerminalLauncher.selectBestOttyPane(
            from: panes,
            cwd: "/Users/tester/vibeCodes/github/AgentFloat/Sources/AgentFloatCore",
            sessionId: "unmatched",
            source: "agy",
            metadata: nil,
            homeDirectory: home
        )
        #expect(bySubdir?.id == "p_agy_repo")

        // 5. 完全无关的目录（如 /tmp 已关闭）返回 nil，不强制回跳到第一条 Tab
        let unmatched = TerminalLauncher.selectBestOttyPane(
            from: panes,
            cwd: "/tmp/closed-workspace",
            sessionId: "unmatched-session",
            source: "agy",
            metadata: nil,
            homeDirectory: home
        )
        #expect(unmatched == nil)
    }
}
