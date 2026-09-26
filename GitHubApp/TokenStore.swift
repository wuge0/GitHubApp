import Foundation
import Security
import SwiftUI

// MARK: - Keychain

/// 极简 Keychain 封装（零依赖）。
/// 侧载 / TrollStore 环境若缺少 keychain-access-group  entitlement，写入会失败，
/// 上层 TokenStore 会自动回退到 UserDefaults，保证功能不中断。
enum KeychainStore {
    private static let service = "com.example.githubapp.token"
    private static let account = "github_pat"

    private static func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read() -> String? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ref: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &ref) == errSecSuccess else { return nil }
        guard let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String) -> Bool {
        delete()
        var q = query()
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete() -> Bool {
        SecItemDelete(query() as CFDictionary) == errSecSuccess
    }
}

// MARK: - Token

/// Token 的唯一来源。优先 Keychain，失败回退 UserDefaults；
/// 首次启动会把旧版本明文存在 UserDefaults 的 Token 迁移进来并清除。
final class TokenStore: ObservableObject {
    static let shared = TokenStore()

    @Published private(set) var token: String = ""

    private let legacyKey = "gh_token"          // 旧版本明文键（迁移用）
    private let fallbackKey = "gh_token_kc"     // Keychain 不可用时的回退键

    private init() {
        migrateLegacyIfNeeded()
        token = (KeychainStore.read() ?? UserDefaults.standard.string(forKey: fallbackKey)) ?? ""
    }

    var isEmpty: Bool { token.isEmpty }

    func save(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty {
            clear()
            return
        }
        if KeychainStore.write(v) {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
        } else {
            UserDefaults.standard.set(v, forKey: fallbackKey)
        }
        token = v
    }

    func clear() {
        KeychainStore.delete()
        UserDefaults.standard.removeObject(forKey: fallbackKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        SessionStore.shared.clear()
        token = ""
    }

    private func migrateLegacyIfNeeded() {
        guard let old = UserDefaults.standard.string(forKey: legacyKey), !old.isEmpty else { return }
        if KeychainStore.write(old) {
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }
}

// MARK: - 登录态缓存

/// 缓存当前登录者的 login，避免每个页面都重复打一次 /user（匿名配额只有 60 次/小时）
final class SessionStore {
    static let shared = SessionStore()

    private let loginKey = "gh_login"
    private var cached: String?

    func currentLogin(token: String) async throws -> String {
        if let c = cached, !c.isEmpty { return c }
        if let c = UserDefaults.standard.string(forKey: loginKey), !c.isEmpty {
            cached = c
            return c
        }
        let u = try await GitHubAPI.shared.me(token: token)
        UserDefaults.standard.set(u.login, forKey: loginKey)
        cached = u.login
        return u.login
    }

    func clear() {
        cached = nil
        UserDefaults.standard.removeObject(forKey: loginKey)
    }
}
