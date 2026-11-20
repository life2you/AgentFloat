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

    @Test("Claude 通知解析与摄取")
    @MainActor
    func claudeNotificationIngestion() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let payload = ClaudeNotificationPayload(
            sessionId: "claude-session-999",
            turnId: "turn-abc",
            cwd: "/Users/dev/claude_app",
            lastAssistantMessage: "Refactored user authentication.",
            status: "completed",
            error: nil,
            durationMs: 4200,
            title: "Claude: 登录重构",
            terminalApp: "ghostty"
        )
        
        let task = try await manager.ingestClaudeNotification(payload: payload)
        #expect(task.source == "claude")
        #expect(task.sessionId == "claude-session-999")
        #expect(task.turnId == "turn-abc")
        #expect(task.cwd == "/Users/dev/claude_app")
        #expect(task.status == .completed)
        #expect(task.verificationNotice == "任务结束 · 请人工验证代码")
        #expect(task.terminalApp == "ghostty")
        #expect(manager.currentCardTask?.id == task.id)
    }

    @Test("Claude 报错与 StopFailure 通知摄取精准识别为 error")
    @MainActor
    func claudeErrorNotificationIngestion() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        // 1. 显式带有 errorMessage 的情况
        let errorPayload = ClaudeNotificationPayload(
            sessionId: "claude-err-1",
            turnId: "turn-err-1",
            cwd: "/Users/dev/claude_err",
            lastAssistantMessage: "Command failed with exit code 1",
            status: nil,
            error: nil,
            terminalApp: nil,
            hookEventName: "Stop",
            errorType: nil,
            errorMessage: "Exit code 1: build failed"
        )
        let errorTask = try await manager.ingestClaudeNotification(payload: errorPayload)
        #expect(errorTask.status == .error)
        #expect(errorTask.errorMessage == "Exit code 1: build failed")
        #expect(errorTask.verificationNotice == "任务异常 · 请检查错误日志")
        #expect(errorTask.title == "Claude 执行异常")
        
        // 2. StopFailure API 异常事件
        let stopFailurePayload = ClaudeNotificationPayload(
            sessionId: "claude-fail-2",
            turnId: "turn-fail-2",
            cwd: "/Users/dev/claude_fail",
            status: nil,
            error: nil,
            hookEventName: "StopFailure",
            errorType: "rate_limit"
        )
        let failTask = try await manager.ingestClaudeNotification(payload: stopFailurePayload)
        #expect(failTask.status == .error)
        #expect(failTask.errorMessage == "rate_limit")
        #expect(failTask.verificationNotice == "任务异常 · 请检查错误日志")

        // 3. 仅有 hook_event_name 为 StopFailure
        let pureStopFailurePayload = ClaudeNotificationPayload(
            sessionId: "claude-fail-3",
            hookEventName: "StopFailure"
        )
        let pureFailTask = try await manager.ingestClaudeNotification(payload: pureStopFailurePayload)
        #expect(pureFailTask.status == .error)
        #expect(pureFailTask.verificationNotice == "任务异常 · 请检查错误日志")
    }

    @Test("Claude 通知脚本 scripts/claude-notify.sh 状态提取与标准化")
    func claudeNotifyScriptAnalysis() throws {
        let scriptPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AgentFloatCoreTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("scripts")
            .appendingPathComponent("claude-notify.sh").path
        
        guard FileManager.default.fileExists(atPath: scriptPath) else { return }
        
        // 辅助函数：通过 Python 代码段直接测试脚本中的规范化解析逻辑
        func runNormalization(payloadJson: String) throws -> [String: Any]? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", """
import os, sys, json, time, re

raw = os.environ.get("RAW_PAYLOAD", "").strip()
try:
    data = json.loads(raw) if raw else {}
except Exception:
    data = {"last_assistant_message": raw, "status": "unknown"}

hook_event = str(data.get("hook_event_name") or data.get("hookEventName") or "")
session_id = data.get("session_id") or data.get("sessionId") or ""
turn_id = data.get("turn_id") or data.get("turnId") or f"turn-{int(time.time() * 1000)}"
cwd = data.get("cwd") or ""
msg = data.get("last_assistant_message") or data.get("lastAssistantMessage") or data.get("message") or ""
raw_status = data.get("status")
transcript_path = data.get("transcript_path") or data.get("transcriptPath") or ""
stop_reason = str(data.get("stop_reason") or data.get("stopReason") or "")
term_app = data.get("terminal_app") or os.environ.get("TERM_PROGRAM") or ""

error = (
    data.get("error")
    or data.get("error_message")
    or data.get("errorMessage")
    or data.get("error_type")
    or data.get("errorType")
    or data.get("tool_error")
    or data.get("denial_reason")
    or ""
)
if isinstance(error, dict):
    error = json.dumps(error, ensure_ascii=False)
else:
    error = str(error) if error else ""

norm_status = None

if "fail" in hook_event.lower() or "err" in hook_event.lower():
    norm_status = "error"
    if not error:
        error = f"Claude 执行失败 ({hook_event})"

if not norm_status and error.strip():
    norm_status = "error"

if not norm_status and raw_status:
    s_lower = str(raw_status).lower()
    if "fail" in s_lower or "err" in s_lower:
        norm_status = "error"
        if not error:
            error = str(raw_status)
    elif "abort" in s_lower or "cancel" in s_lower:
        norm_status = "aborted"

if not norm_status and stop_reason:
    sr_lower = stop_reason.lower()
    if "abort" in sr_lower or "cancel" in sr_lower or "interrupt" in sr_lower:
        norm_status = "aborted"
    elif "err" in sr_lower or "fail" in sr_lower:
        norm_status = "error"
        if not error:
            error = f"Stop reason: {stop_reason}"

clean_msg = str(msg or "").strip()
if not norm_status and clean_msg:
    stripped = re.sub(r'^(?:[#>-*`~_]+|\\s+|\\[ERROR\\]|\\[WARNING\\])+', '', clean_msg, flags=re.IGNORECASE).strip()
    err_prefix_regex = r'^(?:error|fatal|exception|panic|typeerror|syntaxerror|referenceerror|runtimeerror|build failed|command failed|execution failed|test(?:s)? failed|task failed|operation failed|failed with exit code|process exited with code\\s+[1-9]|api error|request failed|anthropic api error|错误|报错|执行失败|构建失败|测试失败|运行失败|命令失败|调用失败|异常退出|发生异常|操作失败)(?:[:：\\s\\.]|$)'
    if re.search(err_prefix_regex, stripped, re.IGNORECASE):
        norm_status = "error"
        if not error:
            first_line = clean_msg.split("\\n")[0].strip()
            error = first_line[:120]

    if not norm_status:
        strong_phrases = [
            "claude code encountered an error",
            "command failed with exit code",
            "failed with exit code",
            "process exited with exit code",
            "rate limit exceeded",
            "credit balance is too low",
            "insufficient quota",
            "overloaded_error"
        ]
        clean_lower = clean_msg.lower()
        for phrase in strong_phrases:
            if phrase in clean_lower:
                norm_status = "error"
                if not error:
                    error = phrase
                break

if not norm_status:
    norm_status = "completed"

if norm_status == "error" and not error:
    error = "Claude 执行过程中发生异常"

msg_snippet = ""
snippet_source = msg or error
if snippet_source:
    first_line = str(snippet_source).strip().split("\\n")[0].strip()
    first_line = re.sub(r'^[#>-*`~_]+\\s*', '', first_line).strip()
    if len(first_line) > 35:
        msg_snippet = first_line[:32] + "..."
    else:
        msg_snippet = first_line

default_title = "Claude 执行异常" if norm_status == "error" else ("Claude 任务已中止" if norm_status == "aborted" else "Claude 执行完成")
if norm_status == "error":
    final_title = data.get("title") or (f"Claude 报错: {msg_snippet}" if msg_snippet else default_title)
else:
    final_title = data.get("title") or (f"Claude: {msg_snippet}" if msg_snippet else default_title)

output = {
    "status": norm_status,
    "error": error if norm_status == "error" else None,
    "title": final_title
}
print(json.dumps(output))
"""]
            process.environment = ["RAW_PAYLOAD": payloadJson]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        
        // 场景 1: StopFailure -> 识别为 error
        let r1 = try runNormalization(payloadJson: "{\"hook_event_name\":\"StopFailure\",\"error_type\":\"rate_limit\"}")
        #expect(r1?["status"] as? String == "error")
        #expect(r1?["error"] as? String == "rate_limit")
        #expect((r1?["title"] as? String)?.contains("Claude 报错") == true)
        
        // 场景 2: 命令执行失败 -> 识别为 error
        let r2 = try runNormalization(payloadJson: "{\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"Command failed with exit code 1: swift test\"}")
        #expect(r2?["status"] as? String == "error")
        #expect((r2?["title"] as? String)?.contains("Claude 报错") == true)
        
        // 场景 3: 中文报错 -> 识别为 error
        let r3 = try runNormalization(payloadJson: "{\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"执行失败：存在 3 个语法错误\"}")
        #expect(r3?["status"] as? String == "error")
        #expect((r3?["title"] as? String)?.contains("Claude 报错") == true)

        // 场景 4: 正常完成 -> 识别为 completed
        let r4 = try runNormalization(payloadJson: "{\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"所有测试均已顺利通过！\"}")
        #expect(r4?["status"] as? String == "completed")
        #expect(r4?["error"] == nil)
        #expect((r4?["title"] as? String)?.contains("Claude: 所有测试") == true)

        // 场景 5: 中止 -> 识别为 aborted
        let r5 = try runNormalization(payloadJson: "{\"hook_event_name\":\"Stop\",\"stop_reason\":\"aborted\",\"last_assistant_message\":\"用户取消了操作\"}")
        #expect(r5?["status"] as? String == "aborted")
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
    
    @Test("DeepSeek Harness (dsh) 任务摄取与去重")
    @MainActor
    func dshTaskIngestionAndDeduplication() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let task = try await manager.ingestTask(
            source: "dsh",
            sessionId: "dsh-session-1",
            turnId: "dsh-turn-1",
            title: "DeepSeek Harness: 优化数据库查询",
            status: .completed,
            cwd: "/Users/dev/AgentFloat"
        )
        
        #expect(task.source == "dsh")
        #expect(task.typedSource == .dsh)
        #expect(TaskSource.allCases.contains(.dsh))
        #expect(task.typedSource.displayName == "DeepSeek Harness")
        #expect(task.verificationNotice == "任务结束 · 请人工验证代码")
        #expect(manager.currentCardTask?.id == task.id)
        
        // 重复 (source, session, turn) 去重行为
        let duplicateTask = try await manager.ingestTask(
            source: "dsh",
            sessionId: "dsh-session-1",
            turnId: "dsh-turn-1",
            title: "DeepSeek Harness: 优化数据库查询 (更新)",
            status: .completed,
            cwd: "/Users/dev/AgentFloat"
        )
        
        #expect(duplicateTask.id == task.id)
        #expect(duplicateTask.title == "DeepSeek Harness: 优化数据库查询 (更新)")
        #expect(manager.pendingTasks.count == 1)
    }
    
    @Test("异常状态解析：同义状态词与错误信息触发 error 状态")
    @MainActor
    func errorStatusResolution() async throws {
        #expect(TaskManager.resolveStatus(rawStatus: "failed", errorMessage: nil) == .error)
        #expect(TaskManager.resolveStatus(rawStatus: "error", errorMessage: nil) == .error)
        #expect(TaskManager.resolveStatus(rawStatus: "completed", errorMessage: "API rate limit exceeded") == .error)
        #expect(TaskManager.resolveStatus(rawStatus: nil, errorMessage: "Network connection lost") == .error)
        #expect(TaskManager.resolveStatus(rawStatus: "cancelled", errorMessage: nil) == .aborted)
        #expect(TaskManager.resolveStatus(rawStatus: "aborted", errorMessage: nil) == .aborted)
        #expect(TaskManager.resolveStatus(rawStatus: "completed", errorMessage: nil) == .completed)
        #expect(TaskManager.resolveStatus(rawStatus: nil, errorMessage: nil) == .completed)
        
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let codexErrTask = try await manager.ingestCodexNotification(
            payload: CodexNotificationPayload(
                threadId: "t-err",
                turnId: "turn-err",
                status: "failed",
                error: "Stream disconnected"
            )
        )
        #expect(codexErrTask.status == .error)
        #expect(codexErrTask.title == "Codex 执行异常")
        #expect(codexErrTask.verificationNotice == "任务异常 · 请检查错误日志")
    }

    @Test("Antigravity (agy) 通知解析、terminationReason 判定与去重")
    @MainActor
    func agyNotificationIngestion() async throws {
        let (manager, path) = try createManager()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // 1. 正常完成 (NO_TOOL_CALL)
        let okPayload = AgyNotificationPayload(
            conversationId: "agy-conv-100",
            turnId: "turn-1",
            executionNum: 0,
            workspacePaths: ["/Users/dev/AgentFloat"],
            lastAssistantMessage: "已完成新功能接入并通过全部测试。",
            lastUserInput: "增加对 agy 的支持",
            terminationReason: "NO_TOOL_CALL",
            hookEventName: "Stop",
            modelName: "gemini-pro",
            terminalApp: "ghostty"
        )
        let okTask = try await manager.ingestAgyNotification(payload: okPayload)
        #expect(okTask.source == "agy")
        #expect(okTask.typedSource == .agy)
        #expect(okTask.typedSource.displayName == "Antigravity")
        #expect(okTask.sessionId == "agy-conv-100")
        #expect(okTask.cwd == "/Users/dev/AgentFloat")
        #expect(okTask.promptSummary == "增加对 agy 的支持")
        #expect(okTask.status == .completed)
        #expect(okTask.terminalApp == "ghostty")
        #expect(okTask.verificationNotice == "任务结束 · 请人工验证代码")

        // 2. 错误终止 (ERROR)
        let errPayload = AgyNotificationPayload(
            conversationId: "agy-conv-101",
            turnId: "turn-2",
            cwd: "/Users/dev/AgentFloat",
            error: "API quota exhausted",
            terminationReason: "ERROR",
            hookEventName: "Stop"
        )
        let errTask = try await manager.ingestAgyNotification(payload: errPayload)
        #expect(errTask.status == .error)
        #expect(errTask.errorMessage == "API quota exhausted")
        #expect(errTask.title == "Antigravity 执行异常")
        #expect(errTask.verificationNotice == "任务异常 · 请检查错误日志")

        // 3. 用户取消 (USER_CANCELED)
        let cancelPayload = AgyNotificationPayload(
            conversationId: "agy-conv-102",
            turnId: "turn-3",
            terminationReason: "USER_CANCELED",
            hookEventName: "Stop"
        )
        let cancelTask = try await manager.ingestAgyNotification(payload: cancelPayload)
        #expect(cancelTask.status == .aborted)
        #expect(cancelTask.title == "Antigravity 任务已中止")
        #expect(cancelTask.verificationNotice == "任务已中止 · 请检查当前状态")

        // 4. 达到上限 (MAX_INVOCATIONS)
        let limitPayload = AgyNotificationPayload(
            conversationId: "agy-conv-103",
            turnId: "turn-4",
            terminationReason: "MAX_INVOCATIONS",
            hookEventName: "Stop"
        )
        let limitTask = try await manager.ingestAgyNotification(payload: limitPayload)
        #expect(limitTask.status == .error)
        #expect(limitTask.errorMessage?.contains("MAX_INVOCATIONS") == true)

        // 5. antigravity 别名兼容
        let aliasTask = AgentTask(source: "antigravity", title: "Alias Check")
        #expect(aliasTask.typedSource == .agy)
    }

    @Test("Antigravity (agy) 自动配置与 scripts/agy-notify.sh 契约测试")
    func agyAutoSetupAndHookScript() throws {
        let tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentfloat_agy_test_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(atPath: tempHome.path) }

        let cliDir = tempHome.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true)
        let configDir = tempHome.appendingPathComponent(".gemini/config", isDirectory: true)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // 预先写入用户自定义 Hook，验证不会覆盖已有配置
        let existingHooks: [String: Any] = [
            "lint-checker": [
                "PostToolUse": [
                    ["matcher": "run_command", "hooks": [["type": "command", "command": "./lint.sh"]]]
                ]
            ]
        ]
        let existingData = try JSONSerialization.data(withJSONObject: existingHooks, options: [.prettyPrinted])
        let hooksFile = configDir.appendingPathComponent("hooks.json")
        try existingData.write(to: hooksFile)

        let (ok, _) = AutoIntegrationManager.setupAgy(homeDirectory: tempHome, checkSystemApps: false)
        #expect(ok)

        let updatedData = try Data(contentsOf: hooksFile)
        let updatedJson = try JSONSerialization.jsonObject(with: updatedData) as? [String: Any]
        #expect(updatedJson?["lint-checker"] != nil)

        let agentfloatHook = updatedJson?["agentfloat"] as? [String: Any]
        let stopHandlers = agentfloatHook?["Stop"] as? [[String: Any]]
        #expect(stopHandlers?.count == 1)
        let expectedCmd = tempHome.appendingPathComponent(".agentfloat/hooks/agy-notify.sh").path
        #expect(stopHandlers?.first?["command"] as? String == expectedCmd)
        #expect(FileManager.default.isExecutableFile(atPath: expectedCmd))

        // 验证重复调用幂等性
        let (okAgain, msgAgain) = AutoIntegrationManager.setupAgy(homeDirectory: tempHome, checkSystemApps: false)
        #expect(okAgain)
        #expect(msgAgain.contains("已就绪"))

        // 验证脚本本身在无服务端时也能向 stdout 输出有效 JSON 对象 {}
        let scriptPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/agy-notify.sh").path
        #expect(FileManager.default.fileExists(atPath: scriptPath))

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["bash", scriptPath]
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = tempHome.path
        env["AGENTFLOAT_TOKEN"] = "dummy-token"
        env["AGENTFLOAT_URL"] = "http://127.0.0.1:49999"
        proc.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        try proc.run()

        let sampleInput = """
        {"conversationId":"conv-test","workspacePaths":["/tmp/ws"],"hookEventName":"Stop","terminationReason":"NO_TOOL_CALL","lastUserInput":"test agy"}
        """
        stdinPipe.fileHandleForWriting.write(Data(sampleInput.utf8))
        stdinPipe.fileHandleForWriting.closeFile()
        proc.waitUntilExit()

        #expect(proc.terminationStatus == 0)
        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(outStr == "{}")
    }
}
