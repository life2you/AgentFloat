import Foundation
import ServiceManagement
import Combine

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    private var isUpdating = false
    
    public init() {
        self.isEnabled = Self.checkIsEnabled()
    }
    
    /// 刷新当前系统开机自启状态
    public func refresh() {
        let current = Self.checkIsEnabled()
        if self.isEnabled != current {
            self.isEnabled = current
        }
    }
    
    /// 切换开机自启状态
    public func toggle() {
        set(enabled: !isEnabled)
    }
    
    /// 设置开机自启启用或禁用
    public func set(enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        
        if enabled {
            enableLaunchAtLogin()
        } else {
            disableLaunchAtLogin()
        }
        
        self.isEnabled = Self.checkIsEnabled()
    }
    
    private static func checkIsEnabled() -> Bool {
        if SMAppService.mainApp.status == .enabled {
            return true
        }
        return checkSystemEventsLoginItem()
    }
    
    private func enableLaunchAtLogin() {
        // 1. 优先尝试现代 SMAppService API (macOS 13+)
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .enabled {
                    return
                }
            }
        } catch {
            // 若为未签名/ad-hoc签名环境，继续回退到系统事件方案
        }
        
        // 2. 备用兜底方案：通过 macOS System Events 安全注册登录项
        let appPath = Self.currentAppPath()
        let script = """
        tell application "System Events"
            if not (exists login item "AgentFloat") then
                make login item at end with properties {path:"\(appPath)", hidden:false, name:"AgentFloat"}
            end if
        end tell
        """
        _ = Self.runAppleScript(script)
    }
    
    private func disableLaunchAtLogin() {
        // 1. 取消 SMAppService
        try? SMAppService.mainApp.unregister()
        
        // 2. 取消 System Events 登录项
        let script = """
        tell application "System Events"
            if exists login item "AgentFloat" then
                delete login item "AgentFloat"
            end if
        end tell
        """
        _ = Self.runAppleScript(script)
    }
    
    private static func checkSystemEventsLoginItem() -> Bool {
        let script = """
        tell application "System Events"
            return (exists login item "AgentFloat")
        end tell
        """
        guard let s = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        let result = s.executeAndReturnError(&error)
        return result.booleanValue
    }
    
    private static func currentAppPath() -> String {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            return bundleURL.path
        }
        if FileManager.default.fileExists(atPath: "/Applications/AgentFloat.app") {
            return "/Applications/AgentFloat.app"
        }
        return bundleURL.path
    }
    
    private static func runAppleScript(_ source: String) -> Bool {
        guard let s = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        s.executeAndReturnError(&error)
        return error == nil
    }
    
    /// 获取当前底层服务状态描述
    public var statusDescription: String {
        return isEnabled ? "已开启" : "未开启"
    }
}
