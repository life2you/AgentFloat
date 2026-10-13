import Testing
@testable import AgentFloatCore

@Suite("AgentFloatVersion Tests")
struct AgentFloatVersionTests {
    @Test("版本号格式与获取")
    func versionString() {
        let version = AgentFloatVersion.current
        #expect(!version.isEmpty)
        #expect(version.contains("."))
        #expect(AgentFloatVersion.string == "1.0.10")
    }
}
