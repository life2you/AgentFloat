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
    public var metadata: [String: String]?
    
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
        case metadata
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
        terminalApp: String? = nil,
        metadata: [String: String]? = nil
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
        self.metadata = metadata
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
        self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
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
        try container.encodeIfPresent(terminalApp, forKey: .terminalApp)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// Claude CLI 传入的通知载荷
public struct ClaudeNotificationPayload: Codable, Sendable {
    public var sessionId: String?
    public var turnId: String?
    public var cwd: String?
    public var lastAssistantMessage: String?
    public var status: String?
    public var error: String?
    public var durationMs: Int?
    public var title: String?
    public var terminalApp: String?
    public var hookEventName: String?
    public var errorType: String?
    public var errorMessage: String?
    public var transcriptPath: String?
    public var metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sessionIdAlt = "sessionId"
        
        case turnId = "turn_id"
        case turnIdAlt = "turnId"
        
        case cwd
        
        case lastAssistantMessage = "last_assistant_message"
        case lastAssistantMessageAlt = "lastAssistantMessage"
        case message
        
        case status
        case error
        case durationMs = "duration_ms"
        case durationMsAlt = "durationMs"
        case title
        case terminalApp = "terminal_app"
        case terminalAppAlt = "terminalApp"
        
        case hookEventName = "hook_event_name"
        case hookEventNameAlt = "hookEventName"
        
        case errorType = "error_type"
        case errorTypeAlt = "errorType"
        
        case errorMessage = "error_message"
        case errorMessageAlt = "errorMessage"
        
        case transcriptPath = "transcript_path"
        case transcriptPathAlt = "transcriptPath"
        case metadata
    }
    
    public init(
        sessionId: String? = nil,
        turnId: String? = nil,
        cwd: String? = nil,
        lastAssistantMessage: String? = nil,
        status: String? = nil,
        error: String? = nil,
        durationMs: Int? = nil,
        title: String? = nil,
        terminalApp: String? = nil,
        hookEventName: String? = nil,
        errorType: String? = nil,
        errorMessage: String? = nil,
        transcriptPath: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.sessionId = sessionId
        self.turnId = turnId
        self.cwd = cwd
        self.lastAssistantMessage = lastAssistantMessage
        self.status = status
        self.error = error
        self.durationMs = durationMs
        self.title = title
        self.terminalApp = terminalApp
        self.hookEventName = hookEventName
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.transcriptPath = transcriptPath
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
            ?? container.decodeIfPresent(String.self, forKey: .sessionIdAlt)
        self.turnId = try container.decodeIfPresent(String.self, forKey: .turnId)
            ?? container.decodeIfPresent(String.self, forKey: .turnIdAlt)
        self.cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        self.lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
            ?? container.decodeIfPresent(String.self, forKey: .lastAssistantMessageAlt)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
            ?? container.decodeIfPresent(Int.self, forKey: .durationMsAlt)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp)
            ?? container.decodeIfPresent(String.self, forKey: .terminalAppAlt)
        self.hookEventName = try container.decodeIfPresent(String.self, forKey: .hookEventName)
            ?? container.decodeIfPresent(String.self, forKey: .hookEventNameAlt)
        self.errorType = try container.decodeIfPresent(String.self, forKey: .errorType)
            ?? container.decodeIfPresent(String.self, forKey: .errorTypeAlt)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            ?? container.decodeIfPresent(String.self, forKey: .errorMessageAlt)
        self.transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
            ?? container.decodeIfPresent(String.self, forKey: .transcriptPathAlt)
        self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(turnId, forKey: .turnId)
        try container.encodeIfPresent(cwd, forKey: .cwd)
        try container.encodeIfPresent(lastAssistantMessage, forKey: .lastAssistantMessage)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(terminalApp, forKey: .terminalApp)
        try container.encodeIfPresent(hookEventName, forKey: .hookEventName)
        try container.encodeIfPresent(errorType, forKey: .errorType)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(transcriptPath, forKey: .transcriptPath)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// Antigravity (agy CLI / 桌面端 / IDE) 传入的通知载荷
public struct AgyNotificationPayload: Codable, Sendable {
    public var conversationId: String?
    public var turnId: String?
    public var executionNum: Int?
    public var cwd: String?
    public var workspacePaths: [String]?
    public var lastAssistantMessage: String?
    public var lastUserInput: String?
    public var status: String?
    public var error: String?
    public var errorMessage: String?
    public var terminationReason: String?
    public var hookEventName: String?
    public var transcriptPath: String?
    public var modelName: String?
    public var durationMs: Int?
    public var title: String?
    public var terminalApp: String?
    public var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversationId"
        case conversationIdSnake = "conversation_id"
        case sessionId = "sessionId"
        case sessionIdSnake = "session_id"

        case turnId = "turnId"
        case turnIdSnake = "turn_id"

        case executionNum = "executionNum"
        case executionNumSnake = "execution_num"

        case cwd
        case workspacePaths = "workspacePaths"
        case workspacePathsSnake = "workspace_paths"

        case lastAssistantMessage = "lastAssistantMessage"
        case lastAssistantMessageSnake = "last_assistant_message"
        case message

        case lastUserInput = "lastUserInput"
        case lastUserInputSnake = "last_user_input"
        case promptSummary = "promptSummary"
        case promptSummarySnake = "prompt_summary"

        case status
        case error
        case errorMessage = "errorMessage"
        case errorMessageSnake = "error_message"

        case terminationReason = "terminationReason"
        case terminationReasonSnake = "termination_reason"

        case hookEventName = "hookEventName"
        case hookEventNameSnake = "hook_event_name"

        case transcriptPath = "transcriptPath"
        case transcriptPathSnake = "transcript_path"

        case modelName = "modelName"
        case modelNameSnake = "model_name"

        case durationMs = "durationMs"
        case durationMsSnake = "duration_ms"

        case title
        case terminalApp = "terminalApp"
        case terminalAppSnake = "terminal_app"
        case metadata
    }

    public init(
        conversationId: String? = nil,
        turnId: String? = nil,
        executionNum: Int? = nil,
        cwd: String? = nil,
        workspacePaths: [String]? = nil,
        lastAssistantMessage: String? = nil,
        lastUserInput: String? = nil,
        status: String? = nil,
        error: String? = nil,
        errorMessage: String? = nil,
        terminationReason: String? = nil,
        hookEventName: String? = nil,
        transcriptPath: String? = nil,
        modelName: String? = nil,
        durationMs: Int? = nil,
        title: String? = nil,
        terminalApp: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.conversationId = conversationId
        self.turnId = turnId
        self.executionNum = executionNum
        self.cwd = cwd
        self.workspacePaths = workspacePaths
        self.lastAssistantMessage = lastAssistantMessage
        self.lastUserInput = lastUserInput
        self.status = status
        self.error = error
        self.errorMessage = errorMessage
        self.terminationReason = terminationReason
        self.hookEventName = hookEventName
        self.transcriptPath = transcriptPath
        self.modelName = modelName
        self.durationMs = durationMs
        self.title = title
        self.terminalApp = terminalApp
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            ?? container.decodeIfPresent(String.self, forKey: .conversationIdSnake)
            ?? container.decodeIfPresent(String.self, forKey: .sessionId)
            ?? container.decodeIfPresent(String.self, forKey: .sessionIdSnake)
        self.turnId = try container.decodeIfPresent(String.self, forKey: .turnId)
            ?? container.decodeIfPresent(String.self, forKey: .turnIdSnake)
        self.executionNum = try container.decodeIfPresent(Int.self, forKey: .executionNum)
            ?? container.decodeIfPresent(Int.self, forKey: .executionNumSnake)
        self.cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        self.workspacePaths = try container.decodeIfPresent([String].self, forKey: .workspacePaths)
            ?? container.decodeIfPresent([String].self, forKey: .workspacePathsSnake)
        self.lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
            ?? container.decodeIfPresent(String.self, forKey: .lastAssistantMessageSnake)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        self.lastUserInput = try container.decodeIfPresent(String.self, forKey: .lastUserInput)
            ?? container.decodeIfPresent(String.self, forKey: .lastUserInputSnake)
            ?? container.decodeIfPresent(String.self, forKey: .promptSummary)
            ?? container.decodeIfPresent(String.self, forKey: .promptSummarySnake)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            ?? container.decodeIfPresent(String.self, forKey: .errorMessageSnake)
        self.terminationReason = try container.decodeIfPresent(String.self, forKey: .terminationReason)
            ?? container.decodeIfPresent(String.self, forKey: .terminationReasonSnake)
        self.hookEventName = try container.decodeIfPresent(String.self, forKey: .hookEventName)
            ?? container.decodeIfPresent(String.self, forKey: .hookEventNameSnake)
        self.transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
            ?? container.decodeIfPresent(String.self, forKey: .transcriptPathSnake)
        self.modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
            ?? container.decodeIfPresent(String.self, forKey: .modelNameSnake)
        self.durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
            ?? container.decodeIfPresent(Int.self, forKey: .durationMsSnake)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp)
            ?? container.decodeIfPresent(String.self, forKey: .terminalAppSnake)
        self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(turnId, forKey: .turnId)
        try container.encodeIfPresent(executionNum, forKey: .executionNum)
        try container.encodeIfPresent(cwd, forKey: .cwd)
        try container.encodeIfPresent(workspacePaths, forKey: .workspacePaths)
        try container.encodeIfPresent(lastAssistantMessage, forKey: .lastAssistantMessage)
        try container.encodeIfPresent(lastUserInput, forKey: .lastUserInput)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(terminationReason, forKey: .terminationReason)
        try container.encodeIfPresent(hookEventName, forKey: .hookEventName)
        try container.encodeIfPresent(transcriptPath, forKey: .transcriptPath)
        try container.encodeIfPresent(modelName, forKey: .modelName)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(terminalApp, forKey: .terminalApp)
        try container.encodeIfPresent(metadata, forKey: .metadata)
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
    
    /// 解析任务状态（兼容大小写、同义词及 errorMessage 存在性判定）
    nonisolated public static func resolveStatus(rawStatus: String?, errorMessage: String?) -> TaskStatus {
        let trimmedError = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedError.isEmpty {
            return .error
        }
        let raw = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if raw.isEmpty {
            return .completed
        }
        if let exact = TaskStatus(rawValue: raw) {
            return exact
        }
        if raw.contains("abort") || raw.contains("cancel") {
            return .aborted
        }
        if raw.contains("err") || raw.contains("fail") {
            return .error
        }
        if raw.contains("complete") || raw.contains("success") || raw == "done" || raw == "ok" {
            return .completed
        }
        return .unknown
    }
    
    /// 处理 Codex CLI notification
    @discardableResult
    public func ingestCodexNotification(payload: CodexNotificationPayload) async throws -> AgentTask {
        let sessionId = payload.threadId?.isEmpty == false ? payload.threadId! : UUID().uuidString
        let turnId = payload.turnId?.isEmpty == false ? payload.turnId! : UUID().uuidString
        let cwd = payload.cwd
        
        let status = Self.resolveStatus(rawStatus: payload.status, errorMessage: payload.error)
        let defaultTitle: String = {
            switch status {
            case .error: return "Codex 执行异常"
            case .aborted: return "Codex 任务已中止"
            case .completed, .unknown: return "Codex Turn 执行完成"
            }
        }()
        let title = payload.title?.isEmpty == false ? payload.title! : defaultTitle
        let resultSummary = payload.lastAssistantMessage
        
        var metadata = payload.metadata ?? [:]
        metadata["codex"] = "true"

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
            metadata: metadata
        )
    }
    
    /// 处理 Claude CLI notification
    @discardableResult
    public func ingestClaudeNotification(payload: ClaudeNotificationPayload) async throws -> AgentTask {
        let sessionId = payload.sessionId?.isEmpty == false ? payload.sessionId! : UUID().uuidString
        let turnId = payload.turnId?.isEmpty == false ? payload.turnId! : UUID().uuidString
        let cwd = payload.cwd
        
        let effectiveError: String? = {
            if let err = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines), !err.isEmpty {
                return err
            }
            if let errMsg = payload.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !errMsg.isEmpty {
                return errMsg
            }
            if let errType = payload.errorType?.trimmingCharacters(in: .whitespacesAndNewlines), !errType.isEmpty {
                return errType
            }
            if let hook = payload.hookEventName?.lowercased(), hook.contains("fail") || hook.contains("err") {
                return "Claude 执行异常 (\(payload.hookEventName!))"
            }
            return nil
        }()
        
        var rawStatus = payload.status
        if rawStatus == nil || rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            if effectiveError != nil || payload.hookEventName?.lowercased().contains("fail") == true {
                rawStatus = "error"
            }
        }
        
        let status = Self.resolveStatus(rawStatus: rawStatus, errorMessage: effectiveError)
        let defaultTitle: String = {
            switch status {
            case .error: return "Claude 执行异常"
            case .aborted: return "Claude 任务已中止"
            case .completed, .unknown: return "Claude 执行完成"
            }
        }()
        let title = payload.title?.isEmpty == false ? payload.title! : defaultTitle
        let resultSummary = payload.lastAssistantMessage
        
        var metadata = payload.metadata ?? [:]
        metadata["claude"] = "true"

        return try await ingestTask(
            source: TaskSource.claude.rawValue,
            sessionId: sessionId,
            turnId: turnId,
            title: title,
            promptSummary: nil,
            resultSummary: resultSummary,
            status: status,
            errorMessage: effectiveError,
            cwd: cwd,
            terminalApp: payload.terminalApp,
            durationMs: payload.durationMs,
            metadata: metadata
        )
    }

    /// 处理 Antigravity (agy CLI / 桌面端 / IDE) notification
    @discardableResult
    public func ingestAgyNotification(payload: AgyNotificationPayload) async throws -> AgentTask {
        let sessionId = payload.conversationId?.isEmpty == false ? payload.conversationId! : UUID().uuidString
        let turnId = payload.turnId?.isEmpty == false ? payload.turnId! : UUID().uuidString
        let cwd = (payload.cwd?.isEmpty == false ? payload.cwd : nil) ?? payload.workspacePaths?.first

        let reasonUpper = payload.terminationReason?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let explicitError: String? = {
            if let err = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines), !err.isEmpty {
                return err
            }
            if let errMsg = payload.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !errMsg.isEmpty {
                return errMsg
            }
            return nil
        }()

        let effectiveError: String? = {
            if let explicitError {
                return explicitError
            }
            if reasonUpper == "ERROR" {
                return "Antigravity 执行异常 (ERROR)"
            }
            if reasonUpper == "MAX_INVOCATIONS" || reasonUpper == "MAX_FORCED_INVOCATIONS" || reasonUpper == "MAX_TOKEN_BUDGET_EXCEEDED" {
                return "Antigravity 执行达到限制 (\(payload.terminationReason ?? reasonUpper))"
            }
            return nil
        }()

        var rawStatus = payload.status
        if rawStatus == nil || rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            if effectiveError != nil {
                rawStatus = "error"
            } else if reasonUpper == "USER_CANCELED" {
                rawStatus = "aborted"
            } else if !reasonUpper.isEmpty {
                rawStatus = "completed"
            }
        }

        let status = Self.resolveStatus(rawStatus: rawStatus, errorMessage: effectiveError)
        let defaultTitle: String = {
            switch status {
            case .error: return "Antigravity 执行异常"
            case .aborted: return "Antigravity 任务已中止"
            case .completed, .unknown: return "Antigravity 执行完成"
            }
        }()
        let title = payload.title?.isEmpty == false ? payload.title! : defaultTitle

        var metadata = payload.metadata ?? [:]
        metadata["agy"] = "true"
        if let reason = payload.terminationReason, !reason.isEmpty {
            metadata["terminationReason"] = reason
        }
        if let model = payload.modelName, !model.isEmpty {
            metadata["modelName"] = model
        }
        if let hookEvent = payload.hookEventName, !hookEvent.isEmpty {
            metadata["hookEventName"] = hookEvent
        }

        return try await ingestTask(
            source: TaskSource.agy.rawValue,
            sessionId: sessionId,
            turnId: turnId,
            title: title,
            promptSummary: payload.lastUserInput,
            resultSummary: payload.lastAssistantMessage,
            status: status,
            errorMessage: effectiveError,
            cwd: cwd,
            terminalApp: payload.terminalApp,
            durationMs: payload.durationMs,
            metadata: metadata
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
        Task {
            try? await store.markCardUndismissed(id: task.id)
            await loadTasks()
            self.onCardTaskChanged?(task)
        }
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
