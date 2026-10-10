import Foundation
import Testing
@testable import AgentFloatCore

@Suite("SQLiteTaskStore Tests")
struct SQLiteTaskStoreTests {
    
    private func createTempStore() throws -> (SQLiteTaskStore, String) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDbPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).sqlite3").path
        let store = try SQLiteTaskStore(dbPath: tempDbPath)
        return (store, tempDbPath)
    }
    
    @Test("去重与 Upsert 逻辑验证")
    func upsertAndDeduplication() async throws {
        let (store, path) = try createTempStore()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let task1 = AgentTask(
            id: "task-1",
            source: "pi",
            sessionId: "session-abc",
            turnId: "turn-1",
            title: "Task Attempt 1",
            status: .completed
        )
        
        let saved1 = try await store.upsertTask(task1)
        #expect(saved1.title == "Task Attempt 1")
        
        // 相同 (source, session_id, turn_id) 应触发更新与去重
        let task2 = AgentTask(
            id: "task-2",
            source: "pi",
            sessionId: "session-abc",
            turnId: "turn-1",
            title: "Task Attempt 1 (Updated)",
            status: .completed
        )
        
        let saved2 = try await store.upsertTask(task2)
        #expect(saved2.id == "task-1")
        #expect(saved2.title == "Task Attempt 1 (Updated)")
        
        let allPending = try await store.getPendingTasks()
        #expect(allPending.count == 1)
    }

    @Test("同一 Session 的新轮次自动覆盖前一个未处理任务")
    func sameSessionMultipleTurnsOverwritePending() async throws {
        let (store, path) = try createTempStore()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        // 1. Session 1 第 1 轮
        let turn1 = AgentTask(
            id: "turn-1-id",
            source: "pi",
            sessionId: "session-pi-1",
            turnId: "turn-1",
            title: "Pi: 代码直接提交",
            status: .completed,
            durationMs: 267200
        )
        _ = try await store.upsertTask(turn1)
        
        var pending = try await store.getPendingTasks()
        #expect(pending.count == 1)
        #expect(pending[0].title == "Pi: 代码直接提交")
        
        // 用户暂时未处理，中途将卡片临时关闭 (X)
        try await store.markCardDismissed(id: turn1.id)
        var undismissed = try await store.getUndismissedTasks()
        #expect(undismissed.isEmpty) // 卡片已隐藏
        
        // 2. 同一个 Session 发生第 2 轮
        let turn2 = AgentTask(
            id: "turn-2-id",
            source: "pi",
            sessionId: "session-pi-1",
            turnId: "turn-2",
            title: "Pi: 我说的是当前未提交的新接口...",
            status: .completed,
            durationMs: 57700
        )
        let savedTurn2 = try await store.upsertTask(turn2)
        #expect(savedTurn2.title == "Pi: 我说的是当前未提交的新接口...")
        
        // 验证：直接覆盖了前一个任务，且卡片重新唤醒 (dismissedCard == false)
        pending = try await store.getPendingTasks()
        #expect(pending.count == 1) // 依然只有 1 个任务，绝不累积
        #expect(pending[0].title == "Pi: 我说的是当前未提交的新接口...")
        #expect(pending[0].turnId == "turn-2")
        #expect(pending[0].id == "turn-1-id") // 保持原有任务槽位更新
        #expect(!pending[0].dismissedCard) // 自动重新展示卡片
        
        undismissed = try await store.getUndismissedTasks()
        #expect(undismissed.count == 1)
        
        // 3. 不同的 Session 应独立保留
        let anotherSessionTask = AgentTask(
            id: "another-session-id",
            source: "pi",
            sessionId: "session-pi-2",
            turnId: "turn-1",
            title: "Pi: 另一个项目任务",
            status: .completed
        )
        _ = try await store.upsertTask(anotherSessionTask)
        
        pending = try await store.getPendingTasks()
        #expect(pending.count == 2) // 两个不同 Session 各自保留最新 1 个
    }
    
    @Test("待办获取与处理完成")
    func pendingAndResolve() async throws {
        let (store, path) = try createTempStore()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let task = AgentTask(
            source: "codex",
            sessionId: "s1",
            turnId: "t1",
            title: "Fix bug",
            status: .completed
        )
        
        let saved = try await store.upsertTask(task)
        
        var pending = try await store.getPendingTasks()
        #expect(pending.count == 1)
        #expect(!pending[0].isResolved)
        
        try await store.markResolved(id: saved.id)
        
        pending = try await store.getPendingTasks()
        #expect(pending.isEmpty)
        
        let history = try await store.getHistory()
        #expect(history.count == 1)
        #expect(history[0].isResolved)
    }
    
    @Test("关闭卡片但不标记已处理")
    func dismissCardWithoutResolving() async throws {
        let (store, path) = try createTempStore()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let task = AgentTask(
            source: "custom",
            sessionId: "s1",
            turnId: "t1",
            title: "Background Task",
            status: .completed
        )
        
        let saved = try await store.upsertTask(task)
        
        var undismissed = try await store.getUndismissedTasks()
        #expect(undismissed.count == 1)
        
        try await store.markCardDismissed(id: saved.id)
        
        undismissed = try await store.getUndismissedTasks()
        #expect(undismissed.isEmpty)
        
        let pending = try await store.getPendingTasks()
        #expect(pending.count == 1)
        #expect(!pending[0].isResolved)
        #expect(pending[0].dismissedCard)
    }
    
    @Test("分页查询与清空")
    func historyPaginationAndClear() async throws {
        let (store, path) = try createTempStore()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        for i in 1...10 {
            let task = AgentTask(
                source: "custom",
                sessionId: "s\(i)",
                turnId: "t\(i)",
                title: "Task #\(i)",
                status: .completed,
                isResolved: true
            )
            _ = try await store.upsertTask(task)
        }
        
        let page1 = try await store.getHistory(limit: 5, offset: 0)
        #expect(page1.count == 5)
        
        let page2 = try await store.getHistory(limit: 5, offset: 5)
        #expect(page2.count == 5)
        
        try await store.clearResolvedTasks()
        let afterClear = try await store.getHistory()
        #expect(afterClear.isEmpty)
    }
}
