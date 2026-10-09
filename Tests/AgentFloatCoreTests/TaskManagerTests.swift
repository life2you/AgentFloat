import Foundation
import Testing
@testable import AgentFloatCore

@Suite("TaskManager Tests")
struct TaskManagerTests {
    
    @MainActor
    private func createManager() throws -> (TaskManager, String) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDbPath = tempDir.appendingPathComponent("test_tm_\(UUID().uuidString).sqlite3").path
        let store = try SQLiteTaskStore(dbPath: tempDbPath)
        let manager = TaskManager(store: store)
        return (manager, tempDbPath)
    }
    
    @Test("核心规则：醒目人工验证提示")
    @MainActor
    func verificationNoticeRequirements() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let completedTask = try await manager.ingestTask(
            source: "pi",
            sessionId: "s1",
            turnId: "t1",
            title: "Build App",
            status: .completed
        )
        #expect(completedTask.verificationNotice == "任务结束 · 请人工验证代码")
        
        let errorTask = try await manager.ingestTask(
            source: "codex",
            sessionId: "s2",
            turnId: "t2",
            title: "Compile Code",
            status: .error,
            errorMessage: "Segmentation fault"
        )
        #expect(errorTask.verificationNotice == "任务异常 · 请检查错误日志")
        
        let abortedTask = try await manager.ingestTask(
            source: "custom",
            sessionId: "s3",
            turnId: "t3",
            title: "Migrate DB",
            status: .aborted
        )
        #expect(abortedTask.verificationNotice == "任务已中止 · 请检查当前状态")
    }
    
    @Test("Codex 通知解析与摄取")
    @MainActor
    func codexNotificationIngestion() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let payload = CodexNotificationPayload(
            threadId: "thread-xyz",
            turnId: "turn-123",
            cwd: "/Users/dev/myproject",
            lastAssistantMessage: "I have edited the files and ran tests.",
            status: "completed",
            error: nil,
            durationMs: 3500
        )
        
        let task = try await manager.ingestCodexNotification(payload: payload)
        #expect(task.source == "codex")
        #expect(task.sessionId == "thread-xyz")
        #expect(task.turnId == "turn-123")
        #expect(task.cwd == "/Users/dev/myproject")
        #expect(task.status == .completed)
        #expect(task.verificationNotice == "任务结束 · 请人工验证代码")
        #expect(manager.currentCardTask?.id == task.id)
    }
    
    @Test("卡片关闭与处理流程联动")
    @MainActor
    func cardTaskWorkflow() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let task1 = try await manager.ingestTask(
            source: "pi",
            sessionId: "s1",
            turnId: "t1",
            title: "Task 1",
            status: .completed
        )
        
        #expect(manager.currentCardTask?.id == task1.id)
        
        // 关闭当前卡片（不标记已处理）
        try await manager.dismissCurrentCard()
        #expect(manager.currentCardTask == nil)
        #expect(manager.pendingTasks.count == 1)
        
        // 标记为已处理
        try await manager.resolveTask(id: task1.id)
        #expect(manager.pendingTasks.isEmpty)
    }
}
