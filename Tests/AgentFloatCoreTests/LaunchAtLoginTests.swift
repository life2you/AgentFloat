import Testing
import ServiceManagement
@testable import AgentFloatCore

@Suite("LaunchAtLogin Tests")
struct LaunchAtLoginTests {
    @Test("自启动管理器初始化与状态枚举")
    @MainActor
    func launchAtLoginInitialization() {
        let manager = LaunchAtLoginManager.shared
        manager.refresh()
        #expect(!manager.statusDescription.isEmpty)
        
        let validDescriptions = ["已开启", "未开启", "需系统设置批准", "服务未就绪", "未知状态"]
        #expect(validDescriptions.contains(manager.statusDescription))
    }
}
