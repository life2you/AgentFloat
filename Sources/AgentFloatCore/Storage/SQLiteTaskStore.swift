import Foundation
import SQLite3

public enum TaskStoreError: Error, LocalizedError, Sendable {
    case databaseOpenFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case queryFailed(String)
    case recordNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let msg): return "SQLite 打开失败: \(msg)"
        case .executionFailed(let msg): return "SQLite 执行失败: \(msg)"
        case .prepareFailed(let msg): return "SQLite 预编译失败: \(msg)"
        case .bindFailed(let msg): return "SQLite 参数绑定失败: \(msg)"
        case .queryFailed(let msg): return "SQLite 查询失败: \(msg)"
        case .recordNotFound(let id): return "未找到任务记录: \(id)"
        }
    }
}

private final class DatabaseHandle: @unchecked Sendable {
    var raw: OpaquePointer?
    
    init(pointer: OpaquePointer) {
        self.raw = pointer
    }
    
    deinit {
        if let raw = raw {
            sqlite3_close(raw)
        }
    }
}

public actor SQLiteTaskStore {
    private let handle: DatabaseHandle
    public let dbPath: String
    
    public init(dbPath: String? = nil) throws {
        let path: String
        if let customPath = dbPath {
            path = customPath
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let baseDir = homeDir.appendingPathComponent(".agentfloat", isDirectory: true)
            try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
            path = baseDir.appendingPathComponent("tasks.sqlite3").path
        }
        self.dbPath = path
        
        let dbPointer = try Self.openDatabase(at: path)
        try Self.configurePragmas(on: dbPointer)
        try Self.createTables(on: dbPointer)
        self.handle = DatabaseHandle(pointer: dbPointer)
    }
    
    private var db: OpaquePointer? {
        handle.raw
    }
    
    private static func openDatabase(at path: String) throws -> OpaquePointer {
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &dbPointer, flags, nil) != SQLITE_OK {
            let errorMsg = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            if let dbPointer = dbPointer {
                sqlite3_close(dbPointer)
            }
            throw TaskStoreError.databaseOpenFailed(errorMsg)
        }
        guard let validDb = dbPointer else {
            throw TaskStoreError.databaseOpenFailed("未能获取有效的 SQLite 指针")
        }
        return validDb
    }
    
    private static func configurePragmas(on db: OpaquePointer) throws {
        try executeStatic(sql: "PRAGMA journal_mode = WAL;", on: db)
        try executeStatic(sql: "PRAGMA synchronous = NORMAL;", on: db)
        try executeStatic(sql: "PRAGMA foreign_keys = ON;", on: db)
    }
    
    private static func createTables(on db: OpaquePointer) throws {
        let createTasksTable = """
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            session_id TEXT NOT NULL,
            turn_id TEXT NOT NULL,
            title TEXT NOT NULL,
            prompt_summary TEXT,
            result_summary TEXT,
            status TEXT NOT NULL,
            error_message TEXT,
            cwd TEXT,
            terminal_app TEXT,
            is_resolved INTEGER NOT NULL DEFAULT 0,
            dismissed_card INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            duration_ms INTEGER,
            metadata TEXT
        );
        """
        try executeStatic(sql: createTasksTable, on: db)
        
        let createUniqueIndex = """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_source_session_turn
        ON tasks(source, session_id, turn_id);
        """
        try executeStatic(sql: createUniqueIndex, on: db)
        
        let createPendingIndex = """
        CREATE INDEX IF NOT EXISTS idx_tasks_pending
        ON tasks(is_resolved, dismissed_card, updated_at DESC);
        """
        try executeStatic(sql: createPendingIndex, on: db)
        
        let createHistoryIndex = """
        CREATE INDEX IF NOT EXISTS idx_tasks_updated
        ON tasks(updated_at DESC);
        """
        try executeStatic(sql: createHistoryIndex, on: db)
    }
    
    private static func executeStatic(sql: String, on db: OpaquePointer) throws {
        var errorMsg: UnsafeMutablePointer<CChar>?
        defer {
            if let errorMsg = errorMsg {
                sqlite3_free(errorMsg)
            }
        }
        if sqlite3_exec(db, sql, nil, nil, &errorMsg) != SQLITE_OK {
            let message = errorMsg.flatMap { String(cString: $0) } ?? "SQL 执行失败"
            throw TaskStoreError.executionFailed(message)
        }
    }
    
    private func execute(sql: String) throws {
        guard let db = db else {
            throw TaskStoreError.databaseOpenFailed("数据库未连接")
        }
        var errorMsg: UnsafeMutablePointer<CChar>?
        defer {
            if let errorMsg = errorMsg {
                sqlite3_free(errorMsg)
            }
        }
        if sqlite3_exec(db, sql, nil, nil, &errorMsg) != SQLITE_OK {
            let message = errorMsg.flatMap { String(cString: $0) } ?? "SQL 执行失败"
            throw TaskStoreError.executionFailed(message)
        }
    }
    
    /// 插入或基于 (source, session_id, turn_id) 进行去重更新
    @discardableResult
    public func upsertTask(_ task: AgentTask) throws -> AgentTask {
        guard let db = db else {
            throw TaskStoreError.databaseOpenFailed("数据库未连接")
        }
        
        // 检查是否已存在具有相同 (source, session_id, turn_id) 的记录
        let existing = try getTaskByNaturalKey(source: task.source, sessionId: task.sessionId, turnId: task.turnId)
        
        let targetId = existing?.id ?? task.id
        let createdAt = existing?.createdAt ?? task.createdAt
        let updatedAt = task.updatedAt
        let metadataJson: String? = {
            guard let metadata = task.metadata, !metadata.isEmpty else { return nil }
            return try? String(data: JSONEncoder().encode(metadata), encoding: .utf8)
        }()
        
        let sql = """
        INSERT INTO tasks (
            id, source, session_id, turn_id, title, prompt_summary, result_summary,
            status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
            created_at, updated_at, duration_ms, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(source, session_id, turn_id) DO UPDATE SET
            title = excluded.title,
            prompt_summary = COALESCE(excluded.prompt_summary, tasks.prompt_summary),
            result_summary = COALESCE(excluded.result_summary, tasks.result_summary),
            status = excluded.status,
            error_message = COALESCE(excluded.error_message, tasks.error_message),
            cwd = COALESCE(excluded.cwd, tasks.cwd),
            terminal_app = COALESCE(excluded.terminal_app, tasks.terminal_app),
            is_resolved = excluded.is_resolved,
            dismissed_card = excluded.dismissed_card,
            updated_at = excluded.updated_at,
            duration_ms = COALESCE(excluded.duration_ms, tasks.duration_ms),
            metadata = COALESCE(excluded.metadata, tasks.metadata);
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TaskStoreError.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(stmt, 1, (targetId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (task.source as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, (task.sessionId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, (task.turnId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, (task.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        if let prompt = task.promptSummary {
            sqlite3_bind_text(stmt, 6, (prompt as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        
        if let result = task.resultSummary {
            sqlite3_bind_text(stmt, 7, (result as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        
        sqlite3_bind_text(stmt, 8, (task.status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        if let error = task.errorMessage {
            sqlite3_bind_text(stmt, 9, (error as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        
        if let cwd = task.cwd {
            sqlite3_bind_text(stmt, 10, (cwd as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        
        if let terminal = task.terminalApp {
            sqlite3_bind_text(stmt, 11, (terminal as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        
        sqlite3_bind_int(stmt, 12, task.isResolved ? 1 : 0)
        sqlite3_bind_int(stmt, 13, task.dismissedCard ? 1 : 0)
        sqlite3_bind_double(stmt, 14, createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 15, updatedAt.timeIntervalSince1970)
        
        if let duration = task.durationMs {
            sqlite3_bind_int64(stmt, 16, Int64(duration))
        } else {
            sqlite3_bind_null(stmt, 16)
        }
        
        if let meta = metadataJson {
            sqlite3_bind_text(stmt, 17, (meta as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 17)
        }
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw TaskStoreError.executionFailed("Upsert 失败: \(msg)")
        }
        
        guard let saved = try getTask(id: targetId) else {
            throw TaskStoreError.recordNotFound(targetId)
        }
        return saved
    }
    
    /// 获取未处理的任务列表 (is_resolved == 0)
    public func getPendingTasks() throws -> [AgentTask] {
        let sql = """
        SELECT id, source, session_id, turn_id, title, prompt_summary, result_summary,
               status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
               created_at, updated_at, duration_ms, metadata
        FROM tasks
        WHERE is_resolved = 0
        ORDER BY updated_at DESC;
        """
        return try queryTasks(sql: sql)
    }
    
    /// 获取未处理且卡片尚未隐藏的任务 (is_resolved == 0 AND dismissed_card == 0)
    public func getUndismissedTasks() throws -> [AgentTask] {
        let sql = """
        SELECT id, source, session_id, turn_id, title, prompt_summary, result_summary,
               status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
               created_at, updated_at, duration_ms, metadata
        FROM tasks
        WHERE is_resolved = 0 AND dismissed_card = 0
        ORDER BY updated_at DESC;
        """
        return try queryTasks(sql: sql)
    }
    
    /// 标记任务为已处理
    public func markResolved(id: String) throws {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        let sql = "UPDATE tasks SET is_resolved = 1, dismissed_card = 1, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TaskStoreError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// 标记当前卡片隐藏，但不将任务标为已处理
    public func markCardDismissed(id: String) throws {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        let sql = "UPDATE tasks SET dismissed_card = 1, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TaskStoreError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// 隐藏所有未处理任务的悬浮卡片 (仅关闭弹窗，不标记为已处理)
    public func markAllCardsDismissed() throws {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        let sql = "UPDATE tasks SET dismissed_card = 1, updated_at = ? WHERE is_resolved = 0 AND dismissed_card = 0;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TaskStoreError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// 标记所有待处理任务为已处理
    public func markAllResolved() throws {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        let sql = "UPDATE tasks SET is_resolved = 1, dismissed_card = 1, updated_at = ? WHERE is_resolved = 0;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TaskStoreError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// 根据主键获取任务
    public func getTask(id: String) throws -> AgentTask? {
        let sql = """
        SELECT id, source, session_id, turn_id, title, prompt_summary, result_summary,
               status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
               created_at, updated_at, duration_ms, metadata
        FROM tasks
        WHERE id = ? LIMIT 1;
        """
        let list = try queryTasks(sql: sql, bindings: [id])
        return list.first
    }
    
    /// 根据自然键 (source, session_id, turn_id) 查询
    public func getTaskByNaturalKey(source: String, sessionId: String, turnId: String) throws -> AgentTask? {
        let sql = """
        SELECT id, source, session_id, turn_id, title, prompt_summary, result_summary,
               status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
               created_at, updated_at, duration_ms, metadata
        FROM tasks
        WHERE source = ? AND session_id = ? AND turn_id = ? LIMIT 1;
        """
        let list = try queryTasks(sql: sql, bindings: [source, sessionId, turnId])
        return list.first
    }
    
    /// 获取历史任务
    public func getHistory(limit: Int = 50, offset: Int = 0) throws -> [AgentTask] {
        let sql = """
        SELECT id, source, session_id, turn_id, title, prompt_summary, result_summary,
               status, error_message, cwd, terminal_app, is_resolved, dismissed_card,
               created_at, updated_at, duration_ms, metadata
        FROM tasks
        ORDER BY updated_at DESC
        LIMIT \(limit) OFFSET \(offset);
        """
        return try queryTasks(sql: sql)
    }
    
    /// 删除指定任务
    public func deleteTask(id: String) throws {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        let sql = "DELETE FROM tasks WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TaskStoreError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// 清空所有已处理任务
    public func clearResolvedTasks() throws {
        let sql = "DELETE FROM tasks WHERE is_resolved = 1;"
        try execute(sql: sql)
    }
    
    /// 清空全部任务
    public func clearAllTasks() throws {
        let sql = "DELETE FROM tasks;"
        try execute(sql: sql)
    }
    
    private func queryTasks(sql: String, bindings: [String] = []) throws -> [AgentTask] {
        guard let db = db else { throw TaskStoreError.databaseOpenFailed("数据库未连接") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TaskStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, val) in bindings.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), (val as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        
        var results: [AgentTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let source = String(cString: sqlite3_column_text(stmt, 1))
            let sessionId = String(cString: sqlite3_column_text(stmt, 2))
            let turnId = String(cString: sqlite3_column_text(stmt, 3))
            let title = String(cString: sqlite3_column_text(stmt, 4))
            
            let promptSummary = sqlite3_column_type(stmt, 5) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(stmt, 5)) : nil
            
            let resultSummary = sqlite3_column_type(stmt, 6) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(stmt, 6)) : nil
            
            let statusRaw = String(cString: sqlite3_column_text(stmt, 7))
            let status = TaskStatus(rawValue: statusRaw) ?? .unknown
            
            let errorMessage = sqlite3_column_type(stmt, 8) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(stmt, 8)) : nil
            
            let cwd = sqlite3_column_type(stmt, 9) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(stmt, 9)) : nil
            
            let terminalApp = sqlite3_column_type(stmt, 10) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(stmt, 10)) : nil
            
            let isResolved = sqlite3_column_int(stmt, 11) != 0
            let dismissedCard = sqlite3_column_int(stmt, 12) != 0
            
            let createdAtEpoch = sqlite3_column_double(stmt, 13)
            let updatedAtEpoch = sqlite3_column_double(stmt, 14)
            
            let durationMs: Int? = sqlite3_column_type(stmt, 15) != SQLITE_NULL ?
                Int(sqlite3_column_int64(stmt, 15)) : nil
            
            var metadata: [String: String]? = nil
            if sqlite3_column_type(stmt, 16) != SQLITE_NULL,
               let metaStr = String(cString: sqlite3_column_text(stmt, 16)).data(using: .utf8) {
                metadata = try? JSONDecoder().decode([String: String].self, from: metaStr)
            }
            
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
                isResolved: isResolved,
                dismissedCard: dismissedCard,
                createdAt: Date(timeIntervalSince1970: createdAtEpoch),
                updatedAt: Date(timeIntervalSince1970: updatedAtEpoch),
                durationMs: durationMs,
                metadata: metadata
            )
            results.append(task)
        }
        
        return results
    }
}
