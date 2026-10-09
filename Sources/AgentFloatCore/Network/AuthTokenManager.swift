import Foundation
import Security

public final class AuthTokenManager: @unchecked Sendable {
    public static let shared = AuthTokenManager()
    
    public let tokenPath: String
    private var cachedToken: String?
    private let lock = NSLock()
    
    public init(customPath: String? = nil) {
        if let customPath = customPath {
            self.tokenPath = customPath
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".agentfloat", isDirectory: true)
            self.tokenPath = dir.appendingPathComponent("auth_token").path
        }
    }
    
    /// 获取当前有效 Token，若不存在则生成
    public func getOrCreateToken() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cachedToken {
            return cached
        }
        
        if FileManager.default.fileExists(atPath: tokenPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: tokenPath)),
           let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            self.cachedToken = token
            return token
        }
        
        let newToken = generateSecureToken()
        saveToken(newToken)
        self.cachedToken = newToken
        return newToken
    }
    
    /// 校验 Token 是否合法
    public func isValid(token: String) -> Bool {
        let current = getOrCreateToken()
        return current == token.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateSecureToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if result == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "") +
               UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    private func saveToken(_ token: String) {
        let fileURL = URL(fileURLWithPath: tokenPath)
        let parentDir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        
        let data = Data(token.utf8)
        FileManager.default.createFile(atPath: tokenPath, contents: data, attributes: [
            .posixPermissions: 0o600
        ])
    }
}
