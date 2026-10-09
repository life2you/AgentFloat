import Foundation
import Testing
@testable import AgentFloatCore

@Suite("LocalHttpServer Tests")
struct LocalHttpServerTests {
    
    @Test("Token 生成与 POSIX 0600 权限验证")
    func tokenGenerationAndPermission() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempTokenPath = tempDir.appendingPathComponent("test_token_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tempTokenPath) }
        
        let tokenManager = AuthTokenManager(customPath: tempTokenPath)
        let token = tokenManager.getOrCreateToken()
        #expect(!token.isEmpty)
        #expect(token.count == 64)
        #expect(tokenManager.isValid(token: token))
        #expect(!tokenManager.isValid(token: "invalid-token"))
        
        // 验证文件权限 0600
        let attrs = try FileManager.default.attributesOfItem(atPath: tempTokenPath)
        let posix = attrs[.posixPermissions] as? NSNumber
        #expect(posix?.intValue == 0o600)
    }
    
    @Test("HTTP 服务全链路端点测试")
    func httpServerEndpoints() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDbPath = tempDir.appendingPathComponent("test_http_\(UUID().uuidString).sqlite3").path
        let tempTokenPath = tempDir.appendingPathComponent("test_token_\(UUID().uuidString)").path
        defer {
            try? FileManager.default.removeItem(atPath: tempDbPath)
            try? FileManager.default.removeItem(atPath: tempTokenPath)
        }
        
        let tokenManager = AuthTokenManager(customPath: tempTokenPath)
        let store = try SQLiteTaskStore(dbPath: tempDbPath)
        let manager = await TaskManager(store: store)
        let testPort: UInt16 = 41925
        let server = LocalHttpServer(port: testPort, taskManager: manager, tokenManager: tokenManager)
        
        try server.start()
        defer { server.stop() }
        
        // 等待服务监听
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // 1. GET /api/health
        let healthUrl = URL(string: "http://127.0.0.1:\(testPort)/api/health")!
        let (healthData, healthResp) = try await URLSession.shared.data(from: healthUrl)
        let httpResp = healthResp as! HTTPURLResponse
        #expect(httpResp.statusCode == 200)
        let healthJson = try JSONSerialization.jsonObject(with: healthData) as? [String: Any]
        #expect(healthJson?["status"] as? String == "ok")
        
        // 2. 鉴权保护验证 (未带 token 应返回 401)
        let eventsUrl = URL(string: "http://127.0.0.1:\(testPort)/api/events")!
        var unauthReq = URLRequest(url: eventsUrl)
        unauthReq.httpMethod = "POST"
        unauthReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        unauthReq.httpBody = "{}".data(using: .utf8)
        let (_, resp401) = try await URLSession.shared.data(for: unauthReq)
        #expect((resp401 as? HTTPURLResponse)?.statusCode == 401)
        
        // 3. 携带合法 token 发送测试任务
        let token = tokenManager.getOrCreateToken()
        let emitUrl = URL(string: "http://127.0.0.1:\(testPort)/api/test/emit")!
        var emitReq = URLRequest(url: emitUrl)
        emitReq.httpMethod = "POST"
        emitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        emitReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        emitReq.httpBody = "{\"status\":\"completed\",\"title\":\"Unit Task\"}".data(using: .utf8)
        let (emitData, emitResp) = try await URLSession.shared.data(for: emitReq)
        #expect((emitResp as? HTTPURLResponse)?.statusCode == 200)
        let emitJson = try JSONSerialization.jsonObject(with: emitData) as? [String: Any]
        let taskId = emitJson?["taskId"] as? String
        #expect(taskId != nil)
        
        // 4. 查询任务列表 GET /api/tasks
        let listUrl = URL(string: "http://127.0.0.1:\(testPort)/api/tasks")!
        var listReq = URLRequest(url: listUrl)
        listReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (listData, listResp) = try await URLSession.shared.data(for: listReq)
        #expect((listResp as? HTTPURLResponse)?.statusCode == 200)
        let listJson = try JSONSerialization.jsonObject(with: listData) as? [String: Any]
        let tasks = listJson?["tasks"] as? [[String: Any]]
        #expect(tasks?.count == 1)
        
        // 5. 标记处理 POST /api/tasks/{id}/resolve
        let resolveUrl = URL(string: "http://127.0.0.1:\(testPort)/api/tasks/\(taskId!)/resolve")!
        var resReq = URLRequest(url: resolveUrl)
        resReq.httpMethod = "POST"
        resReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, resResp) = try await URLSession.shared.data(for: resReq)
        #expect((resResp as? HTTPURLResponse)?.statusCode == 200)
    }
}
