import Foundation
import AgentFloatCore

@main
struct AgentFloatCLI {
    static var defaultBaseURL: String {
        if let envUrl = ProcessInfo.processInfo.environment["AGENTFLOAT_URL"], !envUrl.isEmpty {
            return envUrl
        }
        let port = LocalHttpServer.configuredPort
        return "http://127.0.0.1:\(port)"
    }

    static func printHelp() {
        print("""
        AgentFloat CLI - 桌面端 Agent 悬浮通知与任务追踪工具

        用法:
          agentfloat <command> [options]

        命令:
          emit               发送任务事件
            --source <name>    来源 (pi / codex / custom, 默认 custom)
            --status <status>  状态 (completed / error / aborted, 默认 completed)
            --title <title>    任务标题
            --cwd <path>       工作目录 (默认当前目录)
            --result <text>    输出摘要
            --prompt <text>    用户指令摘要
            --error <text>     错误信息
            --session <id>     Session ID
            --turn <id>        Turn ID
            --terminal <app>   终端应用 (otty / ghostty / terminal / iterm2)

          codex-notify [json] 处理 Codex CLI notify 通知 (支持参数或 stdin)
          test               发送模拟测试卡片
            --success          模拟成功任务 (绿色)
            --error            模拟报错任务 (红色)
            --cwd <path>       指定工作目录

          list               查看任务列表
            --all              显示全部任务 (包含历史记录)
            --pending          仅显示未处理任务 (默认)

          resolve <id>       标记指定任务为已处理
          setup              一键自动检测并配置本地 Codex 与 Pi Agent 联动
          autostart [on/off] 查看或设置开机自启动
          token              查看当前本地鉴权 Token
          health             检测 AgentFloat 服务健康状态
          help, -h, --help   显示本帮助信息
        """)
    }

    static func getToken() -> String {
        return AuthTokenManager.shared.getOrCreateToken()
    }

    static func sendHttpRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> (Int, Data) {
        guard let url = URL(string: "\(defaultBaseURL)\(endpoint)") else {
            throw NSError(domain: "AgentFloatCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效 URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 3.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        return (statusCode, data)
    }

    static func handleHealth() async {
        do {
            let (status, data) = try await sendHttpRequest(endpoint: "/api/health")
            if status == 200, let text = String(data: data, encoding: .utf8) {
                print("🟢 AgentFloat 运行正常: \(text)")
            } else {
                print("🔴 服务响应异常 HTTP \(status)")
            }
        } catch {
            print("⚪️ AgentFloat 本地服务未运行 (端口 41920 连接失败)")
        }
    }

    static func handleToken() {
        let token = getToken()
        print("AgentFloat Token:")
        print(token)
        print("\nToken 文件位于: \(AuthTokenManager.shared.tokenPath)")
    }

    static func handleTest(args: [String]) async {
        let isError = args.contains("--error")
        let status = isError ? "error" : "completed"
        let title = isError ? "测试任务执行异常" : "测试任务执行完成"
        
        var cwd = FileManager.default.currentDirectoryPath
        if let cwdIndex = args.firstIndex(of: "--cwd"), cwdIndex + 1 < args.count {
            cwd = args[cwdIndex + 1]
        }
        
        let payload: [String: Any?] = [
            "status": status,
            "title": title,
            "cwd": cwd,
            "errorMessage": isError ? "测试模拟执行中断: 状态码 1" : nil
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }) else {
            print("❌ 构建测试载荷失败")
            return
        }
        
        do {
            let (code, respData) = try await sendHttpRequest(endpoint: "/api/test/emit", method: "POST", body: data)
            if code == 200 {
                print("✅ 模拟测试任务已发送到悬浮窗 (状态: \(status))")
            } else {
                let msg = String(data: respData, encoding: .utf8) ?? ""
                print("❌ 发送失败 HTTP \(code): \(msg)")
            }
        } catch {
            print("⚠️ 本地服务未连接，正在直接写入本地数据库...")
            do {
                let store = try SQLiteTaskStore()
                let task = AgentTask(
                    source: "test",
                    sessionId: UUID().uuidString,
                    turnId: UUID().uuidString,
                    title: title,
                    promptSummary: "CLI 本地直写模拟",
                    resultSummary: isError ? "异常退出" : "模拟执行完成",
                    status: isError ? .error : .completed,
                    errorMessage: isError ? "测试模拟中断" : nil,
                    cwd: cwd
                )
                _ = try await store.upsertTask(task)
                print("✅ 任务已存入本地数据库，启动 AgentFloat 应用时将自动呈现。")
            } catch let dbError {
                print("❌ 写入数据库失败: \(dbError)")
            }
        }
    }

    static func handleEmit(args: [String]) async {
        var source = "custom"
        var status = "completed"
        var title = "CLI 任务"
        var cwd = FileManager.default.currentDirectoryPath
        var resultSummary: String? = nil
        var promptSummary: String? = nil
        var errorMessage: String? = nil
        var sessionId = UUID().uuidString
        var turnId = UUID().uuidString
        var terminalApp: String? = nil
        
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg == "--source", i + 1 < args.count {
                source = args[i + 1]
                i += 1
            } else if arg == "--status", i + 1 < args.count {
                status = args[i + 1]
                i += 1
            } else if arg == "--title", i + 1 < args.count {
                title = args[i + 1]
                i += 1
            } else if arg == "--cwd", i + 1 < args.count {
                cwd = args[i + 1]
                i += 1
            } else if (arg == "--result" || arg == "--summary"), i + 1 < args.count {
                resultSummary = args[i + 1]
                i += 1
            } else if arg == "--prompt", i + 1 < args.count {
                promptSummary = args[i + 1]
                i += 1
            } else if arg == "--error", i + 1 < args.count {
                errorMessage = args[i + 1]
                i += 1
            } else if arg == "--session", i + 1 < args.count {
                sessionId = args[i + 1]
                i += 1
            } else if arg == "--turn", i + 1 < args.count {
                turnId = args[i + 1]
                i += 1
            } else if arg == "--terminal", i + 1 < args.count {
                terminalApp = args[i + 1]
                i += 1
            }
            i += 1
        }
        
        let payload = GenericEventPayload(
            source: source,
            sessionId: sessionId,
            turnId: turnId,
            title: title,
            promptSummary: promptSummary,
            resultSummary: resultSummary,
            status: status,
            errorMessage: errorMessage,
            cwd: cwd,
            terminalApp: terminalApp
        )
        
        guard let body = try? JSONEncoder().encode(payload) else {
            print("❌ 序列化任务数据失败")
            return
        }
        
        do {
            let (code, respData) = try await sendHttpRequest(endpoint: "/api/events", method: "POST", body: body)
            if code == 200 {
                print("✅ 任务已推送到 AgentFloat 悬浮窗")
            } else {
                let msg = String(data: respData, encoding: .utf8) ?? ""
                print("❌ 推送失败 HTTP \(code): \(msg)")
            }
        } catch {
            print("⚠️ 无法连接本地服务端，正在回退直写数据库...")
            do {
                let store = try SQLiteTaskStore()
                let taskStatus = TaskStatus(rawValue: status.lowercased()) ?? .completed
                let task = AgentTask(
                    source: source,
                    sessionId: sessionId,
                    turnId: turnId,
                    title: title,
                    promptSummary: promptSummary,
                    resultSummary: resultSummary,
                    status: taskStatus,
                    errorMessage: errorMessage,
                    cwd: cwd,
                    terminalApp: terminalApp
                )
                _ = try await store.upsertTask(task)
                print("✅ 任务已持久化到数据库。")
            } catch let dbError {
                print("❌ 写入数据库失败: \(dbError)")
            }
        }
    }

    static func handleCodexNotify(args: [String]) async {
        var rawJson: String? = nil
        
        if let firstArg = args.first, !firstArg.isEmpty {
            rawJson = firstArg
        } else {
            let stdinData = FileHandle.standardInput.readDataToEndOfFile()
            if !stdinData.isEmpty {
                rawJson = String(data: stdinData, encoding: .utf8)
            }
        }
        
        guard let jsonStr = rawJson?.trimmingCharacters(in: .whitespacesAndNewlines), !jsonStr.isEmpty else {
            print("❌ 未提供 Codex notification JSON 数据。")
            print("用法: agentfloat codex-notify '<json>' 或管道输入")
            return
        }
        
        guard let data = jsonStr.data(using: .utf8) else {
            print("❌ JSON 编码解析失败")
            return
        }
        
        do {
            let (code, respData) = try await sendHttpRequest(endpoint: "/api/codex/notify", method: "POST", body: data)
            if code == 200 {
                print("✅ Codex 通知已成功推送")
            } else {
                let msg = String(data: respData, encoding: .utf8) ?? ""
                print("❌ 推送失败 HTTP \(code): \(msg)")
            }
        } catch {
            print("⚠️ 本地服务未运行，正在直接解析写入数据库...")
            do {
                let decoder = JSONDecoder()
                let payload = try decoder.decode(CodexNotificationPayload.self, from: data)
                let store = try SQLiteTaskStore()
                let manager = await TaskManager(store: store)
                let task = try await manager.ingestCodexNotification(payload: payload)
                print("✅ Codex 任务已记录: \(task.title) (ID: \(task.id))")
            } catch {
                print("❌ 直写处理失败: \(error)")
            }
        }
    }

    static func handleList(args: [String]) async {
        let showAll = args.contains("--all")
        let filter = showAll ? "all" : "pending"
        
        do {
            let (code, data) = try await sendHttpRequest(endpoint: "/api/tasks?filter=\(filter)")
            if code == 200 {
                struct TaskListResp: Codable {
                    let tasks: [AgentTask]
                }
                let resp = try JSONDecoder().decode(TaskListResp.self, from: data)
                printTaskList(tasks: resp.tasks, filter: filter)
                return
            }
        } catch {
            // Fallback to SQLite direct read
        }
        
        do {
            let store = try SQLiteTaskStore()
            let tasks = showAll ? try await store.getHistory(limit: 50) : try await store.getPendingTasks()
            printTaskList(tasks: tasks, filter: filter)
        } catch {
            print("❌ 查询任务失败: \(error)")
        }
    }

    static func printTaskList(tasks: [AgentTask], filter: String) {
        if tasks.isEmpty {
            print("当前没有 \(filter == "all" ? "任何" : "待处理") 任务。")
            return
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(String(format: "%-36@  %-8@  %-12@  %@", "ID", "来源", "状态", "标题"))
        print("─────────────────────────────────────────────────────────────────────────")
        for task in tasks {
            let resolvedTag = task.isResolved ? "[已处理]" : "[待核对]"
            let statusTag = "\(task.status.displayName) \(resolvedTag)"
            let titleTrunc = task.title.count > 25 ? String(task.title.prefix(22)) + "..." : task.title
            print(String(format: "%-36@  %-8@  %-14@  %@", task.id, task.source, statusTag, titleTrunc))
            if let cwd = task.cwd {
                print("   ↳ 目录: \(cwd)")
            }
            if let notice = task.verificationNotice as String? {
                print("   ↳ 提示: \(notice)")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("总计: \(tasks.count) 个任务")
    }

    static func handleResolve(args: [String]) async {
        guard let id = args.first, !id.isEmpty else {
            print("❌ 请指定任务 ID: agentfloat resolve <task-id>")
            return
        }
        
        do {
            let (code, data) = try await sendHttpRequest(endpoint: "/api/tasks/\(id)/resolve", method: "POST")
            if code == 200 {
                print("✅ 任务 \(id) 已标记为已处理")
                return
            } else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("⚠️ 接口返回 HTTP \(code): \(msg)，尝试直接操作数据库...")
            }
        } catch {
            // Fallback
        }
        
        do {
            let store = try SQLiteTaskStore()
            try await store.markResolved(id: id)
            print("✅ 任务 \(id) 已在本地数据库标记为已处理")
        } catch {
            print("❌ 标记失败: \(error)")
        }
    }

    static func handleSetup(args: [String]) {
        print("🔍 正在自动检测并配置本地 Agent 生态...")
        let status = AutoIntegrationManager.autoSetupAll()
        for msg in status.messages {
            print("  • \(msg)")
        }
        print("")
        if status.codexConfigured || status.piConfigured {
            print("✨ 配置完成！Codex 与 Pi Agent 轮次结束时将自动向 AgentFloat 悬浮窗上报任务。")
        } else {
            print("💡 未检测到本地已安装的 Codex (~/.codex) 或 Pi Agent (~/.pi/agent)。后续安装后启动 AgentFloat 即可自动连接。")
        }
    }

    @MainActor
    static func handleAutostart(args: [String]) async {
        let manager = LaunchAtLoginManager.shared
        if let action = args.first?.lowercased() {
            switch action {
            case "enable", "on", "true", "1":
                manager.set(enabled: true)
                print("✅ 已开启开机自启动 (当前状态: \(manager.statusDescription))")
            case "disable", "off", "false", "0":
                manager.set(enabled: false)
                print("✅ 已关闭开机自启动 (当前状态: \(manager.statusDescription))")
            default:
                print("用法: agentfloat autostart [on|off]")
            }
        } else {
            print("开机自启动状态: \(manager.statusDescription) (\(manager.isEnabled ? "已开启" : "未开启"))")
        }
    }

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first else {
            printHelp()
            exit(0)
        }

        let subArgs = Array(args.dropFirst())

        switch command {
        case "emit":
            await handleEmit(args: subArgs)
        case "codex-notify":
            await handleCodexNotify(args: subArgs)
        case "test":
            await handleTest(args: subArgs)
        case "list":
            await handleList(args: subArgs)
        case "resolve":
            await handleResolve(args: subArgs)
        case "setup":
            handleSetup(args: subArgs)
        case "autostart":
            await handleAutostart(args: subArgs)
        case "token":
            handleToken()
        case "health":
            await handleHealth()
        case "help", "-h", "--help":
            printHelp()
        default:
            print("未知命令: \(command)")
            printHelp()
        }
        exit(0)
    }
}
