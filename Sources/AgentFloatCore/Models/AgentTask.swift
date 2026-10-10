import Foundation

/// 任务来源标识
public enum TaskSource: String, Codable, Sendable, CaseIterable {
    case pi = "pi"
    case codex = "codex"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .pi: return "Pi Agent"
        case .codex: return "Codex"
        case .custom: return "Custom"
        }
    }
}

/// 任务执行状态
/// 注意：任务完成（completed）仅代表 Agent 进程/轮次结束，绝不代表代码已经过人工验证！
public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case completed = "completed"
    case error = "error"
    case aborted = "aborted"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .completed: return "执行完成"
        case .error: return "执行异常"
        case .aborted: return "已中止"
        case .unknown: return "状态未知"
        }
    }
    
    /// 醒目标注提示语
    public var verificationNotice: String {
        switch self {
        case .completed:
            return "任务结束 · 请人工验证代码"
        case .error:
            return "任务异常 · 请检查错误日志"
        case .aborted:
            return "任务已中止 · 请检查当前状态"
        case .unknown:
            return "任务状态未知 · 请人工核实"
        }
    }
}

/// Agent 任务核心实体
public struct AgentTask: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var source: String
    public var sessionId: String
    public var turnId: String
    public var title: String
    public var promptSummary: String?
    public var resultSummary: String?
    public var status: TaskStatus
    public var errorMessage: String?
    public var cwd: String?
    public var terminalApp: String?
    public var isResolved: Bool
    public var dismissedCard: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var durationMs: Int?
    public var metadata: [String: String]?
    
    public init(
        id: String = UUID().uuidString,
        source: String = TaskSource.custom.rawValue,
        sessionId: String = UUID().uuidString,
        turnId: String = UUID().uuidString,
        title: String,
        promptSummary: String? = nil,
        resultSummary: String? = nil,
        status: TaskStatus = .completed,
        errorMessage: String? = nil,
        cwd: String? = nil,
        terminalApp: String? = nil,
        isResolved: Bool = false,
        dismissedCard: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        durationMs: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.source = source
        self.sessionId = sessionId
        self.turnId = turnId
        self.title = title
        self.promptSummary = promptSummary
        self.resultSummary = resultSummary
        self.status = status
        self.errorMessage = errorMessage
        self.cwd = cwd
        self.terminalApp = terminalApp
        self.isResolved = isResolved
        self.dismissedCard = dismissedCard
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.durationMs = durationMs
        self.metadata = metadata
    }
    
    /// 解析 source 枚举
    public var typedSource: TaskSource {
        TaskSource(rawValue: source.lowercased()) ?? .custom
    }
    
    /// 核心警告文案：严禁将任务结束等同于代码验证通过
    public var verificationNotice: String {
        status.verificationNotice
    }
}
