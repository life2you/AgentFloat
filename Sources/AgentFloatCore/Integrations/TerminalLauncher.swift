import Foundation
import AppKit

public enum SupportedTerminal: String, CaseIterable, Sendable {
    case otty = "io.appmakes.otty"
    case ghostty = "com.mitchellh.ghostty"
    case terminal = "com.apple.Terminal"
    case iterm2 = "com.googlecode.iterm2"
    
    public var displayName: String {
        switch self {
        case .otty: return "Otty"
        case .ghostty: return "Ghostty"
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        }
    }
    
    public static func from(identifier: String?) -> SupportedTerminal? {
        guard let id = identifier?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        if id.contains("otty") { return .otty }
        if id.contains("ghostty") { return .ghostty }
        if id.contains("iterm") { return .iterm2 }
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
        for candidate: SupportedTerminal in [.ghostty, .otty, .iterm2, .terminal] {
            if runningBundles.contains(candidate.rawValue) {
                return candidate
            }
        }
        
        for candidate: SupportedTerminal in [.ghostty, .otty, .iterm2, .terminal] {
            if isInstalled(terminal: candidate) {
                return candidate
            }
        }
        
        return .terminal
    }
    
    public static func isInstalled(terminal: SupportedTerminal) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.rawValue) != nil
    }
    
    /// 激活终端：优先置顶并激活用户当前已有的终端窗口/会话，避免打开多余的新 Tab 页
    @discardableResult
    public static func activate(cwd: String?, preferredApp: String? = nil) -> Bool {
        let target = detectActiveTerminal(preferred: preferredApp)
        
        // 1. 若该终端正在运行，直接激活其当前窗口，保留在原有会话与 Tab，绝不打开新窗口或新 Tab
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == target.rawValue }) {
            if #available(macOS 14.0, *) {
                runningApp.activate()
                return true
            } else {
                if runningApp.activate(options: [.activateIgnoringOtherApps]) {
                    return true
                }
            }
        }
        
        // 2. 尝试使用 AppleScript 唤起既有会话
        let script = "tell application id \"\(target.rawValue)\" to activate"
        if runAppleScript(script) {
            return true
        }
        
        // 3. 若终端尚未运行，则启动该终端
        return activateBundle(target.rawValue)
    }
    
    private static func openAppleTerminal(cwd: String?) -> Bool {
        if let cwd = cwd, FileManager.default.fileExists(atPath: cwd) {
            let script = """
            tell application "Terminal"
                activate
                do script "cd " & quoted form of "\(escapeForAppleScript(cwd))"
            end tell
            """
            if runAppleScript(script) {
                return true
            }
        }
        return activateBundle("com.apple.Terminal")
    }
    
    private static func openITerm2(cwd: String?) -> Bool {
        if let cwd = cwd, FileManager.default.fileExists(atPath: cwd) {
            let script = """
            tell application "iTerm"
                activate
                try
                    tell current window
                        tell current session
                            write text "cd " & quoted form of "\(escapeForAppleScript(cwd))"
                        end tell
                    end tell
                on error
                    create window with default profile
                    tell current window
                        tell current session
                            write text "cd " & quoted form of "\(escapeForAppleScript(cwd))"
                        end tell
                    end tell
                end try
            end tell
            """
            if runAppleScript(script) {
                return true
            }
        }
        return activateBundle("com.googlecode.iterm2")
    }
    
    private static func openBundleWithCwd(bundleId: String, cwd: String?) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return activateBundle("com.apple.Terminal")
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        if let cwd = cwd, FileManager.default.fileExists(atPath: cwd) {
            let dirURL = URL(fileURLWithPath: cwd)
            NSWorkspace.shared.open([dirURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
            return true
        }
        
        return activateBundle(bundleId)
    }
    
    private static func activateBundle(_ bundleId: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
        return true
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
