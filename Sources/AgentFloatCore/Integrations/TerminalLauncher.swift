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
    case codex = "com.openai.codex"
    case dsh = "com.deepseek.dsh"
    case antigravity = "com.google.antigravity"
    
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
        case .codex: return "Codex"
        case .dsh: return "DeepSeek Harness"
        case .antigravity: return "Antigravity"
        }
    }

    /// 是否为传统终端仿真器
    public var isTerminal: Bool {
        switch self {
        case .codex, .dsh, .antigravity:
            return false
        default:
            return true
        }
    }

    /// 悬浮卡片与菜单栏中的跳转按钮文案
    public var actionTitle: String {
        switch self {
        case .codex, .dsh, .antigravity:
            return "应用"
        default:
            return "终端"
        }
    }

    /// 按钮对应图标
    public var actionIconName: String {
        switch self {
        case .codex, .dsh, .antigravity:
            return "macwindow"
        default:
            return "terminal"
        }
    }

    /// 悬停提示文案
    public var actionHelp: String {
        switch self {
        case .codex:
            return "跳转至 Codex 桌面应用"
        case .dsh:
            return "跳转至 DeepSeek Harness 桌面应用"
        case .antigravity:
            return "跳转至 Antigravity 桌面应用"
        default:
            return "激活当前终端窗口"
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
        if id.contains("codex") || id.contains("chatgpt") || id.contains("openai") { return .codex }
        if id.contains("deepseek") || id.contains("dsh") { return .dsh }
        if id.contains("antigravity") || id == "agy" { return .antigravity }
        if id.contains("terminal") || id.contains("apple") { return .terminal }
        return nil
    }
}

public struct TerminalLauncher: Sendable {
    
    /// 获取当前系统中可用或正在运行的终端或 Agent 客户端
    public static func detectActiveTerminal(preferred: String? = nil, source: String? = nil) -> SupportedTerminal {
        if let preferredTerm = SupportedTerminal.from(identifier: preferred),
           isInstalled(terminal: preferredTerm) {
            return preferredTerm
        }
        
        let runningBundles = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        
        // 若来源是 Codex 且未明确指定终端：优先置顶 Codex 桌面应用
        if source == "codex" && (preferred == nil || preferred?.isEmpty == true || preferred?.contains("codex") == true) {
            if runningBundles.contains(SupportedTerminal.codex.rawValue) || isInstalled(terminal: .codex) {
                return .codex
            }
        }
        
        // 若来源是 dsh 且未明确指定终端：优先置顶 DeepSeek Harness 桌面应用
        if source == "dsh" && (preferred == nil || preferred?.isEmpty == true || preferred?.contains("dsh") == true || preferred?.contains("deepseek") == true) {
            if runningBundles.contains(SupportedTerminal.dsh.rawValue) || isInstalled(terminal: .dsh) {
                return .dsh
            }
        }
        
        // 若来源是 agy 且未明确指定终端：优先置顶 Antigravity 桌面应用
        if (source == "agy" || source == "antigravity") && (preferred == nil || preferred?.isEmpty == true || preferred?.lowercased().contains("agy") == true || preferred?.lowercased().contains("antigravity") == true) {
            if runningBundles.contains(SupportedTerminal.antigravity.rawValue) || isInstalled(terminal: .antigravity) {
                return .antigravity
            }
        }
        
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
    
    /// 激活终端或客户端：精确定位并切换至该任务对应的 Tab/Pane/窗口，并置顶终端，绝不打开多余的新 Tab 页
    @discardableResult
    public static func activate(
        cwd: String?,
        preferredApp: String? = nil,
        sessionId: String? = nil,
        source: String? = nil,
        metadata: [String: String]? = nil
    ) -> Bool {
        let target = detectActiveTerminal(preferred: preferredApp, source: source)
        let bundleId = target.rawValue
        
        // 0. 如果目标是 Codex 桌面端，优先通过 codex://threads/ 深度链接精准跳转至对应会话，并置顶应用
        if target == .codex {
            if let threadId = sessionId, !threadId.isEmpty {
                let deepLink = "codex://threads/\(threadId)"
                if let url = URL(string: deepLink) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.open(url, configuration: config, completionHandler: nil)
                    
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    proc.arguments = [deepLink]
                    if (try? proc.run()) != nil {
                        proc.waitUntilExit()
                    }
                    
                    bringToFront(bundleId: bundleId)
                    return true
                }
            }
            return bringToFront(bundleId: bundleId)
        }
        
        // 0.1 如果目标是 DeepSeek Harness 桌面端，通过 dsh://open 深度链接激活并置顶
        if target == .dsh {
            if let url = URL(string: "dsh://open") {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open(url, configuration: config, completionHandler: nil)
            }
            return bringToFront(bundleId: bundleId)
        }
        
        // 0.2 如果目标是 Antigravity 桌面端，置顶应用窗口
        if target == .antigravity {
            return bringToFront(bundleId: bundleId)
        }
        
        // 1. 如果目标终端是 Otty，优先通过 otty-cli 精确聚焦对应 Pane 与窗口
        if target == .otty {
            if focusOttyPane(cwd: cwd, sessionId: sessionId, source: source, metadata: metadata) {
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
    
    struct OttyPaneItem: Decodable, Equatable {
        let id: String
        let tab_id: String
        let window_id: String
        let cwd: String?
        let agent: String?
        let agent_session_id: String?
        let process: String?
    }

    private struct OttyListResponse: Decodable {
        let data: [OttyPaneItem]
    }

    static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let standardized = URL(fileURLWithPath: expanded).standardizedFileURL.path
        if standardized.count > 1 && standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized
    }

    static func isPath(_ path: String, equalOrInside ancestor: String) -> Bool {
        guard !path.isEmpty, !ancestor.isEmpty else { return false }
        if path == ancestor { return true }
        if ancestor == "/" { return path.hasPrefix("/") }
        return path.hasPrefix(ancestor + "/")
    }

    static func normalizeOttyPaneId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("p_") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }

    static func ottyAgentMatches(paneAgent: String?, source: String?) -> Bool {
        guard let p = paneAgent?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty,
              let s = source?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return false
        }
        if s == "agy" || s == "antigravity" {
            return p.contains("antigravity") || p.contains("agy")
        }
        if s == "claude" {
            return p.contains("claude")
        }
        if s == "codex" {
            return p.contains("codex")
        }
        if s == "pi" {
            return p == "pi" || p.hasPrefix("pi ") || p.contains("pi ")
        }
        return p.contains(s)
    }

    /// 精确匹配最符合条件的 Otty Pane（绝不回退到第一条无关 Tab）
    static func selectBestOttyPane(
        from panes: [OttyPaneItem],
        cwd: String?,
        sessionId: String?,
        source: String?,
        metadata: [String: String]? = nil,
        homeDirectory: String = NSHomeDirectory()
    ) -> OttyPaneItem? {
        guard !panes.isEmpty else { return nil }

        // 优先级 0: OTTY_PANE_ID 精确匹配
        if let rawPaneId = metadata?["otty_pane_id"] ?? metadata?["pane_id"], !rawPaneId.isEmpty {
            let targetNorm = normalizeOttyPaneId(rawPaneId)
            if let exactPane = panes.first(where: { normalizeOttyPaneId($0.id) == targetNorm || $0.id == rawPaneId }) {
                return exactPane
            }
        }

        // 优先级 1: Session ID 匹配 (agent_session_id 或 process 参数中的会话 ID)
        if let sId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines), !sId.isEmpty {
            if let bySession = panes.first(where: { item in
                if let pSession = item.agent_session_id, !pSession.isEmpty {
                    if pSession == sId || pSession.contains(sId) || sId.contains(pSession) {
                        return true
                    }
                }
                if let proc = item.process, !proc.isEmpty, sId.count >= 8, proc.contains(sId) {
                    return true
                }
                return false
            }) {
                return bySession
            }
        }

        let normTaskCwd = cwd.map(normalizePath) ?? ""
        let normHome = normalizePath(homeDirectory)

        if !normTaskCwd.isEmpty {
            // 优先级 2: 精确目录 + Agent 类型匹配
            if let exactCwdAndAgent = panes.first(where: { item in
                guard let pCwd = item.cwd, !pCwd.isEmpty else { return false }
                return normalizePath(pCwd) == normTaskCwd && ottyAgentMatches(paneAgent: item.agent, source: source)
            }) {
                return exactCwdAndAgent
            }

            // 优先级 3: 精确目录匹配
            if let exactCwd = panes.first(where: { item in
                guard let pCwd = item.cwd, !pCwd.isEmpty else { return false }
                return normalizePath(pCwd) == normTaskCwd
            }) {
                return exactCwd
            }

            // 优先级 4 & 5: 目录边界祖先/子目录匹配（优先匹配最近的祖先目录，且当 taskCwd 为用户主目录/根目录时禁止向下匹配任意子目录）
            let allowChildMatch = normTaskCwd != normHome && normTaskCwd != "/"
            let pathCandidates: [(pane: OttyPaneItem, panePathLen: Int, isAncestor: Bool)] = panes.compactMap { item in
                guard let pCwd = item.cwd, !pCwd.isEmpty else { return nil }
                let normPane = normalizePath(pCwd)
                if isPath(normTaskCwd, equalOrInside: normPane) {
                    return (item, normPane.count, true)
                }
                if allowChildMatch && isPath(normPane, equalOrInside: normTaskCwd) {
                    return (item, normPane.count, false)
                }
                return nil
            }

            let sortedCandidates = pathCandidates.sorted { lhs, rhs in
                if lhs.isAncestor != rhs.isAncestor {
                    return lhs.isAncestor && !rhs.isAncestor
                }
                if lhs.isAncestor {
                    return lhs.panePathLen > rhs.panePathLen
                }
                return lhs.panePathLen < rhs.panePathLen
            }

            if let bestWithAgent = sortedCandidates.first(where: { ottyAgentMatches(paneAgent: $0.pane.agent, source: source) }) {
                return bestWithAgent.pane
            }
            if let bestPathOnly = sortedCandidates.first {
                return bestPathOnly.pane
            }
            return nil
        }

        // 优先级 6: 仅在未提供 cwd 时回退按 Agent 类型匹配
        if let byAgent = panes.first(where: { ottyAgentMatches(paneAgent: $0.agent, source: source) }) {
            return byAgent
        }
        return nil
    }

    /// 精确定位并聚焦 Otty 的对应 Tab / Pane
    private static func focusOttyPane(
        cwd: String?,
        sessionId: String?,
        source: String?,
        metadata: [String: String]? = nil
    ) -> Bool {
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
        guard let list = try? JSONDecoder().decode(OttyListResponse.self, from: data), !list.data.isEmpty else {
            return false
        }
        
        guard let targetPane = selectBestOttyPane(
            from: list.data,
            cwd: cwd,
            sessionId: sessionId,
            source: source,
            metadata: metadata
        ) else {
            return false
        }
        
        // 先聚焦 Window、Tab，再聚焦对应 Pane，确保切换 Tab 与焦点准确生效
        if !targetPane.window_id.isEmpty {
            runOttyCli(cliPath: cliPath, arguments: ["window", "focus", targetPane.window_id])
        }
        if !targetPane.tab_id.isEmpty {
            runOttyCli(cliPath: cliPath, arguments: ["tab", "focus", targetPane.tab_id])
        }
        runOttyCli(cliPath: cliPath, arguments: ["pane", "focus", targetPane.id])
        
        return true
    }

    private static func runOttyCli(cliPath: String, arguments: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cliPath)
        proc.arguments = arguments
        try? proc.run()
        proc.waitUntilExit()
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
