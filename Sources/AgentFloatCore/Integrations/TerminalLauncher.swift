import Foundation
import AppKit

public enum SupportedTerminal: String, CaseIterable, Sendable {
    case otty = "io.appmakes.otty"
    case ghostty = "com.mitchellh.ghostty"
    case terminal = "com.apple.Terminal"
    case iterm2 = "com.googlecode.iterm2"
    case warp = "dev.warp.Warp-Stable"
    case wezterm = "com.github.wez.wezterm"
    case alacritty = "org.alacritty"
    case vscode = "com.microsoft.VSCode"
    case cursor = "com.todesktop.230313mzl4w4u92"
    
    public var displayName: String {
        switch self {
        case .otty: return "Otty"
        case .ghostty: return "Ghostty"
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .warp: return "Warp"
        case .wezterm: return "WezTerm"
        case .alacritty: return "Alacritty"
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        }
    }
    
    public static func from(identifier: String?) -> SupportedTerminal? {
        guard let id = identifier?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        if id.contains("otty") { return .otty }
        if id.contains("ghostty") { return .ghostty }
        if id.contains("iterm") { return .iterm2 }
        if id.contains("warp") { return .warp }
        if id.contains("wezterm") { return .wezterm }
        if id.contains("alacritty") { return .alacritty }
        if id.contains("cursor") { return .cursor }
        if id.contains("vscode") || id == "code" { return .vscode }
        if id.contains("terminal") || id.contains("apple") { return .terminal }
        return nil
    }
}

public struct TerminalLauncher: Sendable {
    
    /// 获取当前系统中可用或正在运行的终端
    public static func detectActiveTerminal(preferred: String? = nil) -> SupportedTerminal {
        if let preferredTerm = SupportedTerminal.from(identifier: preferred),
           isInstalled(terminal: preferredTerm) {
            return preferredTerm
        }
        
        let runningBundles = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        for candidate: SupportedTerminal in [.ghostty, .otty, .warp, .wezterm, .alacritty, .cursor, .vscode, .iterm2, .terminal] {
            if runningBundles.contains(candidate.rawValue) {
                return candidate
            }
        }
        
        for candidate: SupportedTerminal in [.ghostty, .otty, .warp, .wezterm, .alacritty, .cursor, .vscode, .iterm2, .terminal] {
            if isInstalled(terminal: candidate) {
                return candidate
            }
        }
        
        return .terminal
    }
    
    public static func isInstalled(terminal: SupportedTerminal) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.rawValue) != nil
    }
    
    /// 激活终端：精确定位并切换至该任务对应的 Tab/Pane/窗口，并置顶终端，绝不打开多余的新 Tab 页
    @discardableResult
    public static func activate(
        cwd: String?,
        preferredApp: String? = nil,
        sessionId: String? = nil,
        source: String? = nil
    ) -> Bool {
        let target = detectActiveTerminal(preferred: preferredApp)
        let bundleId = target.rawValue
        
        // 1. 如果目标终端是 Otty，优先通过 otty-cli 精确聚焦对应 Pane 与窗口
        if target == .otty {
            if focusOttyPane(cwd: cwd, sessionId: sessionId, source: source) {
                bringToFront(bundleId: bundleId)
                return true
            }
        }
        
        // 2. 如果目标是 Apple Terminal，查找匹配工作目录的窗口置顶
        if target == .terminal {
            if focusAppleTerminalWindow(cwd: cwd) {
                bringToFront(bundleId: bundleId)
                return true
            }
        }
        
        // 3. 如果目标是 iTerm2，查找匹配会话
        if target == .iterm2 {
            if focusITerm2Window(cwd: cwd) {
                bringToFront(bundleId: bundleId)
                return true
            }
        }
        
        // 4. 通用兜底：系统级强制置顶已有窗口
        return bringToFront(bundleId: bundleId)
    }
    
    /// 精确定位并聚焦 Otty 的对应 Tab / Pane
    private static func focusOttyPane(cwd: String?, sessionId: String?, source: String?) -> Bool {
        let cliPath = "/Applications/Otty.app/Contents/MacOS/otty-cli"
        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            return false
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cliPath)
        proc.arguments = ["pane", "list", "--json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        guard (try? proc.run()) != nil else { return false }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return false }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        struct OttyPaneItem: Decodable {
            let id: String
            let tab_id: String
            let window_id: String
            let cwd: String?
            let agent: String?
            let agent_session_id: String?
        }
        struct OttyListResponse: Decodable {
            let data: [OttyPaneItem]
        }
        
        guard let list = try? JSONDecoder().decode(OttyListResponse.self, from: data), !list.data.isEmpty else {
            return false
        }
        
        // 优先级多级匹配
        var matchedPane: OttyPaneItem? = nil
        
        // 优先级 1: Session ID 精确匹配 (Pi / Codex)
        if let sId = sessionId, !sId.isEmpty {
            matchedPane = list.data.first(where: { item in
                guard let pSession = item.agent_session_id, !pSession.isEmpty else { return false }
                return pSession == sId || pSession.contains(sId) || sId.contains(pSession)
            })
        }
        
        // 优先级 2: 目录 + Agent 类型匹配
        if matchedPane == nil, let taskCwd = cwd, !taskCwd.isEmpty {
            matchedPane = list.data.first(where: { item in
                guard let pCwd = item.cwd, !pCwd.isEmpty else { return false }
                let cwdMatch = taskCwd.hasPrefix(pCwd) || pCwd.hasPrefix(taskCwd)
                if let src = source?.lowercased(), let pAgent = item.agent?.lowercased() {
                    return cwdMatch && pAgent.contains(src)
                }
                return cwdMatch
            })
        }
        
        // 优先级 3: 单纯工作目录前缀/包含匹配
        if matchedPane == nil, let taskCwd = cwd, !taskCwd.isEmpty {
            matchedPane = list.data.first(where: { item in
                guard let pCwd = item.cwd, !pCwd.isEmpty else { return false }
                return taskCwd.hasPrefix(pCwd) || pCwd.hasPrefix(taskCwd)
            })
        }
        
        // 优先级 4: Agent 类型匹配
        if matchedPane == nil, let src = source?.lowercased() {
            matchedPane = list.data.first(where: { item in
                item.agent?.lowercased().contains(src) == true
            })
        }
        
        guard let targetPane = matchedPane ?? list.data.first else {
            return false
        }
        
        // 聚焦对应 Pane
        let focusPaneProc = Process()
        focusPaneProc.executableURL = URL(fileURLWithPath: cliPath)
        focusPaneProc.arguments = ["pane", "focus", targetPane.id]
        try? focusPaneProc.run()
        focusPaneProc.waitUntilExit()
        
        // 聚焦对应 Window
        let focusWinProc = Process()
        focusWinProc.executableURL = URL(fileURLWithPath: cliPath)
        focusWinProc.arguments = ["window", "focus", targetPane.window_id]
        try? focusWinProc.run()
        focusWinProc.waitUntilExit()
        
        return true
    }
    
    private static func focusAppleTerminalWindow(cwd: String?) -> Bool {
        guard let cwd = cwd, !cwd.isEmpty else { return false }
        let script = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    if custom title of t contains "\(escapeForAppleScript(cwd))" or title of t contains "\(escapeForAppleScript(cwd))" then
                        set index of w to 1
                        set selected of t to true
                        return true
                    end if
                end repeat
            end repeat
            return false
        end tell
        """
        return runAppleScript(script)
    }
    
    private static func focusITerm2Window(cwd: String?) -> Bool {
        guard let cwd = cwd, !cwd.isEmpty else { return false }
        let script = """
        tell application "iTerm"
            activate
            repeat with w in windows
                tell w
                    repeat with t in tabs
                        tell t
                            repeat with s in sessions
                                if (variable named "currentDir" of s) contains "\(escapeForAppleScript(cwd))" then
                                    select t
                                    select s
                                    return true
                                end if
                            end repeat
                        end tell
                    end repeat
                end tell
            end repeat
            return false
        end tell
        """
        return runAppleScript(script)
    }
    
    @discardableResult
    private static func bringToFront(bundleId: String) -> Bool {
        // 1. 系统级 open -b 强制置顶 (LaunchServices 原生权限)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-b", bundleId]
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                return true
            }
        }
        
        // 2. AppleScript 激活
        let script = "tell application id \"\(bundleId)\" to activate"
        if runAppleScript(script) {
            return true
        }
        
        // 3. NSWorkspace 备用
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
            return true
        }
        
        return false
    }
    
    private static func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        return errorInfo == nil
    }
    
    private static func escapeForAppleScript(_ string: String) -> String {
        return string.replacingOccurrences(of: "\\", with: "\\\\")
                     .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
