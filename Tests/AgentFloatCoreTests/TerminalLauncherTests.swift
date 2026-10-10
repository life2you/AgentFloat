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
        
        #expect(SupportedTerminal.ghostty.actionTitle == "终端")
        #expect(SupportedTerminal.ghostty.actionIconName == "terminal")
        #expect(SupportedTerminal.ghostty.isTerminal)
    }
}
