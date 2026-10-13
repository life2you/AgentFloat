import Foundation

/// AgentFloat 全局版本管理
public struct AgentFloatVersion: Sendable {
    /// 当前版本号
    public static let string: String = "1.0.10"
    
    /// 获取当前运行环境的版本号（优先自 App Bundle 读取，若无则使用标准版本号）
    public static var current: String {
        if let bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !bundleVer.isEmpty {
            return bundleVer
        }
        return string
    }
}
