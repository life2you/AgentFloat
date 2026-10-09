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
    }
    
    @Test("当前活跃终端识别")
    func activeTerminalDetection() {
        let detected = TerminalLauncher.detectActiveTerminal()
        #expect(SupportedTerminal.allCases.contains(detected))
    }
}
