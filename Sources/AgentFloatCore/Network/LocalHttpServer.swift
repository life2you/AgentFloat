import Foundation
import Network

public struct TestEmitPayload: Codable, Sendable {
    public var status: String?
    public var title: String?
    public var cwd: String?
    public var errorMessage: String?
    
    public init(status: String? = nil, title: String? = nil, cwd: String? = nil, errorMessage: String? = nil) {
        self.status = status
        self.title = title
        self.cwd = cwd
        self.errorMessage = errorMessage
    }
}

public struct GenericEventPayload: Codable, Sendable {
    public var source: String?
    public var sessionId: String?
    public var turnId: String?
    public var title: String?
    public var promptSummary: String?
    public var resultSummary: String?
    public var status: String?
    public var errorMessage: String?
    public var cwd: String?
    public var terminalApp: String?
    public var durationMs: Int?
    public var metadata: [String: String]?
    
    public init(
        source: String? = nil,
        sessionId: String? = nil,
        turnId: String? = nil,
        title: String? = nil,
        promptSummary: String? = nil,
        resultSummary: String? = nil,
        status: String? = nil,
        errorMessage: String? = nil,
        cwd: String? = nil,
        terminalApp: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String]? = nil
    ) {
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
        self.durationMs = durationMs
        self.metadata = metadata
    }
}

public final class LocalHttpServer: @unchecked Sendable {
    public static let defaultPort: UInt16 = 41920
    
    public static var configuredPort: UInt16 {
        if let envPortStr = ProcessInfo.processInfo.environment["AGENTFLOAT_PORT"],
           let envPort = UInt16(envPortStr) {
            return envPort
        }
        return defaultPort
    }
    
    public let port: UInt16
    public let taskManager: TaskManager
    public let tokenManager: AuthTokenManager
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.agentfloat.httpserver", qos: .userInitiated)
    private var isRunningState = false
    private let stateLock = NSLock()
    
    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isRunningState
    }
    
    public init(
        port: UInt16 = LocalHttpServer.defaultPort,
        taskManager: TaskManager,
        tokenManager: AuthTokenManager = .shared
    ) {
        self.port = port
        self.taskManager = taskManager
        self.tokenManager = tokenManager
    }
    
    public func start() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard !isRunningState else { return }
        
        // 确保 Token 已就绪
        _ = tokenManager.getOrCreateToken()
        
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "LocalHttpServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效端口: \(port)"])
        }
        
        let newListener = try NWListener(using: parameters, on: endpointPort)
        self.listener = newListener
        
        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        newListener.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("[LocalHttpServer] 监听于 127.0.0.1:\(self?.port ?? 0)")
            case .failed(let error):
                print("[LocalHttpServer] 监听错误: \(error)")
                self?.stop()
            case .cancelled:
                print("[LocalHttpServer] 监听停止")
            default:
                break
            }
        }
        
        newListener.start(queue: queue)
        self.isRunningState = true
    }
    
    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        listener?.cancel()
        listener = nil
        isRunningState = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNextChunk(connection: connection, buffer: Data())
    }
    
    private func receiveNextChunk(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if error != nil {
                connection.cancel()
                return
            }
            
            var accumulated = buffer
            if let data = data, !data.isEmpty {
                accumulated.append(data)
            }
            
            let delimiter = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
            if let headerEndRange = accumulated.range(of: delimiter) {
                let headerData = accumulated.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = accumulated.subdata(in: headerEndRange.upperBound..<accumulated.count)
                
                guard let headerString = String(data: headerData, encoding: .utf8) else {
                    self.sendError(connection: connection, status: 400, message: "Invalid HTTP Header Encoding")
                    return
                }
                
                let lines = headerString.components(separatedBy: "\r\n")
                guard let requestLine = lines.first else {
                    self.sendError(connection: connection, status: 400, message: "Missing HTTP Request Line")
                    return
                }
                
                let reqParts = requestLine.components(separatedBy: " ")
                guard reqParts.count >= 2 else {
                    self.sendError(connection: connection, status: 400, message: "Malformed HTTP Request Line")
                    return
                }
                
                let method = reqParts[0].uppercased()
                let uri = reqParts[1]
                
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                        let val = parts[1].trimmingCharacters(in: .whitespaces)
                        headers[key] = val
                    }
                }
                
                let contentLength = headers["content-length"].flatMap { Int($0) } ?? 0
                if bodyData.count < contentLength {
                    // 尚未收全 Body，继续接收
                    self.receiveNextChunk(connection: connection, buffer: accumulated)
                    return
                }
                
                let finalBody = bodyData.prefix(contentLength)
                self.processRequest(connection: connection, method: method, uri: uri, headers: headers, body: Data(finalBody))
            } else {
                if isComplete {
                    connection.cancel()
                } else {
                    self.receiveNextChunk(connection: connection, buffer: accumulated)
                }
            }
        }
    }
    
    private func processRequest(
        connection: NWConnection,
        method: String,
        uri: String,
        headers: [String: String],
        body: Data
    ) {
        // CORS OPTIONS 支持
        if method == "OPTIONS" {
            sendResponse(connection: connection, status: 200, statusText: "OK", headers: [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, X-AgentFloat-Token"
            ], bodyData: Data())
            return
        }
        
        let urlComponents = URLComponents(string: uri)
        let path = urlComponents?.path ?? uri
        let queryItems = urlComponents?.queryItems ?? []
        
        // GET /api/health 免鉴权
        if method == "GET" && path == "/api/health" {
            let json = """
            {"status":"ok","version":"1.0.0","port":\(port)}
            """
            sendJson(connection: connection, status: 200, json: json)
            return
        }
        
        // 校验鉴权 Token
        let tokenHeader = headers["authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
            ?? headers["x-agentfloat-token"]
        
        guard let token = tokenHeader, tokenManager.isValid(token: token) else {
            sendJson(connection: connection, status: 401, json: """
            {"error":"Unauthorized: valid auth token required"}
            """)
            return
        }
        
        // 路由分发
        Task { [weak self] in
            guard let self = self else { return }
            await self.routeRequest(connection: connection, method: method, path: path, queryItems: queryItems, body: body)
        }
    }
    
    private func routeRequest(
        connection: NWConnection,
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data
    ) async {
        let decoder = JSONDecoder()
        
        // POST /api/events
        if method == "POST" && path == "/api/events" {
            do {
                let payload = try decoder.decode(GenericEventPayload.self, from: body)
                let status = TaskStatus(rawValue: payload.status?.lowercased() ?? "") ?? .completed
                
                let task = try await taskManager.ingestTask(
                    source: payload.source ?? TaskSource.custom.rawValue,
                    sessionId: payload.sessionId ?? UUID().uuidString,
                    turnId: payload.turnId ?? UUID().uuidString,
                    title: payload.title ?? "Agent 任务完成",
                    promptSummary: payload.promptSummary,
                    resultSummary: payload.resultSummary,
                    status: status,
                    errorMessage: payload.errorMessage,
                    cwd: payload.cwd,
                    terminalApp: payload.terminalApp,
                    durationMs: payload.durationMs,
                    metadata: payload.metadata
                )
                
                let resData = try JSONEncoder().encode(["status": "ok", "taskId": task.id])
                sendResponse(connection: connection, status: 200, statusText: "OK", bodyData: resData)
            } catch {
                sendError(connection: connection, status: 400, message: "Invalid payload: \(error.localizedDescription)")
            }
            return
        }
        
        // POST /api/codex/notify
        if method == "POST" && path == "/api/codex/notify" {
            do {
                let payload = try decoder.decode(CodexNotificationPayload.self, from: body)
                let task = try await taskManager.ingestCodexNotification(payload: payload)
                let resData = try JSONEncoder().encode(["status": "ok", "taskId": task.id])
                sendResponse(connection: connection, status: 200, statusText: "OK", bodyData: resData)
            } catch {
                sendError(connection: connection, status: 400, message: "Invalid codex payload: \(error.localizedDescription)")
            }
            return
        }
        
        // POST /api/test/emit
        if method == "POST" && path == "/api/test/emit" {
            do {
                let payload = (try? decoder.decode(TestEmitPayload.self, from: body)) ?? TestEmitPayload()
                let status = TaskStatus(rawValue: payload.status?.lowercased() ?? "completed") ?? .completed
                let task = try await taskManager.ingestTask(
                    source: "test",
                    sessionId: UUID().uuidString,
                    turnId: UUID().uuidString,
                    title: payload.title ?? "测试模拟任务",
                    promptSummary: "测试模拟触发",
                    resultSummary: status == .completed ? "模拟指令成功执行完毕" : "模拟执行过程中发生错误",
                    status: status,
                    errorMessage: payload.errorMessage ?? (status == .error ? "测试模拟异常" : nil),
                    cwd: payload.cwd ?? FileManager.default.currentDirectoryPath,
                    terminalApp: nil,
                    durationMs: 420
                )
                let resData = try JSONEncoder().encode(["status": "ok", "taskId": task.id])
                sendResponse(connection: connection, status: 200, statusText: "OK", bodyData: resData)
            } catch {
                sendError(connection: connection, status: 500, message: error.localizedDescription)
            }
            return
        }
        
        // GET /api/tasks
        if method == "GET" && path == "/api/tasks" {
            let filter = queryItems.first(where: { $0.name == "filter" })?.value ?? "pending"
            do {
                let tasks: [AgentTask]
                if filter == "all" || filter == "history" {
                    tasks = try await taskManager.store.getHistory(limit: 50)
                } else {
                    tasks = try await taskManager.store.getPendingTasks()
                }
                let data = try JSONEncoder().encode(["tasks": tasks])
                sendResponse(connection: connection, status: 200, statusText: "OK", bodyData: data)
            } catch {
                sendError(connection: connection, status: 500, message: error.localizedDescription)
            }
            return
        }
        
        // POST /api/tasks/{id}/resolve
        if method == "POST" && path.hasPrefix("/api/tasks/") && path.hasSuffix("/resolve") {
            let segments = path.split(separator: "/")
            if segments.count == 4 {
                let id = String(segments[2])
                do {
                    try await taskManager.resolveTask(id: id)
                    sendJson(connection: connection, status: 200, json: "{\"status\":\"ok\",\"resolved\":true}")
                } catch {
                    sendError(connection: connection, status: 500, message: error.localizedDescription)
                }
                return
            }
        }
        
        // POST /api/tasks/{id}/dismiss
        if method == "POST" && path.hasPrefix("/api/tasks/") && path.hasSuffix("/dismiss") {
            let segments = path.split(separator: "/")
            if segments.count == 4 {
                let id = String(segments[2])
                do {
                    try await taskManager.dismissCard(id: id)
                    sendJson(connection: connection, status: 200, json: "{\"status\":\"ok\",\"dismissed\":true}")
                } catch {
                    sendError(connection: connection, status: 500, message: error.localizedDescription)
                }
                return
            }
        }
        
        // 404
        sendError(connection: connection, status: 404, message: "Route Not Found: \(method) \(path)")
    }
    
    private func sendJson(connection: NWConnection, status: Int, json: String) {
        let bodyData = json.data(using: .utf8) ?? Data()
        sendResponse(connection: connection, status: status, statusText: status == 200 ? "OK" : "Error", bodyData: bodyData)
    }
    
    private func sendError(connection: NWConnection, status: Int, message: String) {
        struct ErrorEnvelope: Codable {
            let error: String
        }
        let bodyData = (try? JSONEncoder().encode(ErrorEnvelope(error: message)))
            ?? Data("{\"error\":\"Internal Error\"}".utf8)
        let statusText = status == 400 ? "Bad Request" : (status == 401 ? "Unauthorized" : (status == 404 ? "Not Found" : "Internal Server Error"))
        sendResponse(connection: connection, status: status, statusText: statusText, headers: ["Content-Type": "application/json"], bodyData: bodyData)
    }
    
    private func sendResponse(
        connection: NWConnection,
        status: Int,
        statusText: String,
        headers: [String: String] = [:],
        bodyData: Data
    ) {
        var headerLines = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "Access-Control-Allow-Origin: *"
        ]
        
        for (k, v) in headers {
            headerLines.append("\(k): \(v)")
        }
        
        let headerText = headerLines.joined(separator: "\r\n") + "\r\n\r\n"
        var fullData = headerText.data(using: .utf8) ?? Data()
        fullData.append(bodyData)
        
        connection.send(content: fullData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
