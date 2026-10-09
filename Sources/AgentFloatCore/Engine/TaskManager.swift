import Foundation
import Combine

/// Codex CLI 传入的通知载荷
public struct CodexNotificationPayload: Codable, Sendable {
    public var threadId: String?
    public var turnId: String?
    public var cwd: String?
    public var lastAssistantMessage: String?
    public var status: String?
    public var error: String?
    public var durationMs: Int?
    public var title: String?
    public var terminalApp: String?
    
    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case threadIdAlt = "threadId"
        case threadIdKebab = "thread-id"
        
        case turnId = "turn_id"
        case turnIdAlt = "turnId"
        case turnIdKebab = "turn-id"
        
        case cwd
        
        case lastAssistantMessage = "last_assistant_message"
        case lastAssistantMessageAlt = "lastAssistantMessage"
        case lastAssistantMessageKebab = "last-assistant-message"
        case message
        
        case status
        case error
        case durationMs = "duration_ms"
        case durationMsAlt = "durationMs"
        case title
        case terminalApp = "terminal_app"
        case terminalAppAlt = "terminalApp"
    }
    
    public init(
        threadId: String? = nil,
        turnId: String? = nil,
        cwd: String? = nil,
        lastAssistantMessage: String? = nil,
        status: String? = nil,
        error: String? = nil,
        durationMs: Int? = nil,
        title: String? = nil,
        terminalApp: String? = nil
    ) {
        self.threadId = threadId
        self.turnId = turnId
        self.cwd = cwd
        self.lastAssistantMessage = lastAssistantMessage
        self.status = status
        self.error = error
        self.durationMs = durationMs
        self.title = title
        self.terminalApp = terminalApp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.threadId = try container.decodeIfPresent(String.self, forKey: .threadId)
            ?? container.decodeIfPresent(String.self, forKey: .threadIdAlt)
            ?? container.decodeIfPresent(String.self, forKey: .threadIdKebab)
            
        self.turnId = try container.decodeIfPresent(String.self, forKey: .turnId)
            ?? container.decodeIfPresent(String.self, forKey: .turnIdAlt)
            ?? container.decodeIfPresent(String.self, forKey: .turnIdKebab)
            
        self.cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        
        self.lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
            ?? container.decodeIfPresent(String.self, forKey: .lastAssistantMessageAlt)
            ?? container.decodeIfPresent(String.self, forKey: .lastAssistantMessageKebab)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        
        self.durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
            ?? container.decodeIfPresent(Int.self, forKey: .durationMsAlt)
            
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp)
            ?? container.decodeIfPresent(String.self, forKey: .terminalAppAlt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(threadId, forKey: .threadId)
        try container.encodeIfPresent(turnId, forKey: .turnId)
        try container.encodeIfPresent(cwd, forKey: .cwd)
        try container.encodeIfPresent(lastAssistantMessage, forKey: .lastAssistantMessage)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(title, forKey: .title)
    }
}

@MainActor
public final class TaskManager: ObservableObject {
    public let store: SQLiteTaskStore
    
    /// 未处理的任务列表 (is_resolved == 0)
    @Published public private(set) var pendingTasks: [AgentTask] = []
    
    /// 当前悬浮卡片展示的任务 (未隐藏且未处理的第一项)
    @Published public private(set) var currentCardTask: AgentTask? = nil
    
    /// 尚未隐藏卡片的未处理任务列表 (is_resolved == 0 AND dismissed_card == 0)
    @Published public private(set) var undismissedTasks: [AgentTask] = []
    
    /// 历史记录
    @Published public private(set) var recentHistory: [AgentTask] = []
    
    /// 卡片任务变更回调（单任务兼容）
    public var onCardTaskChanged: ((AgentTask?) -> Void)?
    
    /// 聚合任务列表变更回调（多任务聚合卡片使用）
    public var onTasksChanged: (([AgentTask]) -> Void)?
    
    public init(store: SQLiteTaskStore) {
        self.store = store
    }
    
    /// 初始化加载
    public func loadTasks() async {
        do {
            let pending = try await store.getPendingTasks()
            let undismissed = try await store.getUndismissedTasks()
            let history = try await store.getHistory(limit: 30)
            
            self.pendingTasks = pending
            self.undismissedTasks = undismissed
            self.recentHistory = history
            
            let nextCard = undismissed.first
            if self.currentCardTask?.id != nextCard?.id {
                self.currentCardTask = nextCard
                self.onCardTaskChanged?(nextCard)
            }
            self.onTasksChanged?(undismissed)
        } catch {
            print("[TaskManager] 加载任务失败: \(error)")
        }
    }
    
    /// 录入或更新任务
    @discardableResult
    public func ingestTask(
        id: String = UUID().uuidString,
        source: String,
        sessionId: String,
        turnId: String,
        title: String,
        promptSummary: String? = nil,
        resultSummary: String? = nil,
        status: TaskStatus,
        errorMessage: String? = nil,
        cwd: String? = nil,
        terminalApp: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String]? = nil
    ) async throws -> AgentTask {
        let task = AgentTask(
            id: id,
            source: source,
            sessionId: sessionId,
            turnId: turnId,
            title: title,
            promptSummary: promptSummary,
            resultSummary: resultSummary,
            status: status,
            errorMessage: errorMessage,
            cwd: cwd,
            terminalApp: terminalApp,
            isResolved: false,
            dismissedCard: false,
            createdAt: Date(),
            updatedAt: Date(),
            durationMs: durationMs,
            metadata: metadata
        )
        
        let saved = try await store.upsertTask(task)
        await loadTasks()
        
        // 确保新到来的任务会呈现在悬浮卡片中
        self.currentCardTask = saved
        self.onCardTaskChanged?(saved)
        
        return saved
    }
    
    /// 处理 Codex CLI notification
    @discardableResult
    public func ingestCodexNotification(payload: CodexNotificationPayload) async throws -> AgentTask {
        let sessionId = payload.threadId?.isEmpty == false ? payload.threadId! : UUID().uuidString
        let turnId = payload.turnId?.isEmpty == false ? payload.turnId! : UUID().uuidString
        let cwd = payload.cwd
        
        // 状态识别
        let status: TaskStatus
        let rawStatus = payload.status?.lowercased() ?? ""
        if let err = payload.error, !err.isEmpty {
            status = .error
        } else if rawStatus.contains("abort") || rawStatus.contains("cancel") {
            status = .aborted
        } else if rawStatus.contains("err") || rawStatus.contains("fail") {
            status = .error
        } else if rawStatus.contains("success") || rawStatus.contains("complete") || rawStatus.isEmpty {
            status = .completed
        } else {
            status = .unknown
        }
        
        let title = payload.title?.isEmpty == false ? payload.title! : "Codex Turn 执行完成"
        let resultSummary = payload.lastAssistantMessage
        
        return try await ingestTask(
            source: TaskSource.codex.rawValue,
            sessionId: sessionId,
            turnId: turnId,
            title: title,
            promptSummary: nil,
            resultSummary: resultSummary,
            status: status,
            errorMessage: payload.error,
            cwd: cwd,
            terminalApp: payload.terminalApp,
            durationMs: payload.durationMs,
            metadata: ["codex": "true"]
        )
    }
    
    /// 标记任务为已处理
    public func resolveTask(id: String) async throws {
        try await store.markResolved(id: id)
        await loadTasks()
        
        if currentCardTask?.id == id {
            let undismissed = try await store.getUndismissedTasks()
            self.currentCardTask = undismissed.first
            self.onCardTaskChanged?(undismissed.first)
        }
    }
    
    /// 关闭/隐藏当前悬浮卡片（不标记已处理）
    public func dismissCard(id: String) async throws {
        try await store.markCardDismissed(id: id)
        await loadTasks()
        
        if currentCardTask?.id == id {
            let undismissed = try await store.getUndismissedTasks()
            self.currentCardTask = undismissed.first
            self.onCardTaskChanged?(undismissed.first)
        }
    }
    
    /// 隐藏当前展示的卡片
    public func dismissCurrentCard() async throws {
        guard let current = currentCardTask else { return }
        try await dismissCard(id: current.id)
    }
    
    /// 隐藏所有待处理任务的悬浮卡片 (仅关闭悬浮窗，不标记为已处理)
    public func dismissAllCards() async throws {
        try await store.markAllCardsDismissed()
        await loadTasks()
    }
    
    /// 重新在卡片中展示指定待处理任务
    public func showCard(for task: AgentTask) {
        self.currentCardTask = task
        self.onCardTaskChanged?(task)
    }
    
    /// 标记所有待处理任务为已处理
    public func markAllResolved() async throws {
        try await store.markAllResolved()
        await loadTasks()
        self.currentCardTask = nil
        self.onCardTaskChanged?(nil)
    }
    
    /// 清空已处理历史
    public func clearResolvedHistory() async throws {
        try await store.clearResolvedTasks()
        await loadTasks()
    }
}
