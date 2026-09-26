import Foundation

enum GitHubError: LocalizedError {
    case noData
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "没有收到数据"
        case .badStatus(let code):
            if code == 403 { return "API 限额已用完（匿名 60 次/小时，建议填入 Token）" }
            if code == 401 { return "Token 无效" }
            return "请求失败，HTTP \(code)"
        }
    }
}

final class GitHubAPI {
    static let shared = GitHubAPI()

    private let base = "https://api.github.com"
    private let decoder = JSONDecoder()

    private func get(_ path: String, token: String) async throws -> Data {
        guard let url = URL(string: base + path) else { throw GitHubError.noData }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GitHubError.noData }
        guard (200..<300).contains(http.statusCode) else { throw GitHubError.badStatus(http.statusCode) }
        return data
    }

    func searchRepos(query: String, token: String) async throws -> [Repo] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await get("/search/repositories?q=\(q)&per_page=30&sort=stars", token: token)
        return try decoder.decode(SearchResponse.self, from: data).items
    }

    func issues(owner: String, repo: String, token: String) async throws -> [Issue] {
        let data = try await get("/repos/\(owner)/\(repo)/issues?per_page=20&state=all", token: token)
        return try decoder.decode([Issue].self, from: data)
    }

    // MARK: - 用户

    func me(token: String) async throws -> User {
        let data = try await get("/user", token: token)
        return try decoder.decode(User.self, from: data)
    }

    func user(login: String, token: String) async throws -> User {
        let data = try await get("/users/\(login)", token: token)
        return try decoder.decode(User.self, from: data)
    }

    func userRepos(login: String, token: String) async throws -> [Repo] {
        let data = try await get("/users/\(login)/repos?per_page=50&sort=updated", token: token)
        return try decoder.decode([Repo].self, from: data)
    }

    /// 当前登录者的仓库（含私有）
    func myRepos(token: String) async throws -> [Repo] {
        let data = try await get("/user/repos?per_page=50&sort=updated", token: token)
        return try decoder.decode([Repo].self, from: data)
    }

    func starred(login: String, token: String) async throws -> [Repo] {
        let data = try await get("/users/\(login)/starred?per_page=50&sort=updated", token: token)
        return try decoder.decode([Repo].self, from: data)
    }

    func followers(login: String, token: String) async throws -> [User] {
        let data = try await get("/users/\(login)/followers?per_page=50", token: token)
        return try decoder.decode([User].self, from: data)
    }

    func following(login: String, token: String) async throws -> [User] {
        let data = try await get("/users/\(login)/following?per_page=50", token: token)
        return try decoder.decode([User].self, from: data)
    }

    func events(login: String, token: String) async throws -> [Event] {
        let data = try await get("/users/\(login)/events?per_page=30", token: token)
        return try decoder.decode([Event].self, from: data)
    }

    // MARK: - 趋势（GitHub 无官方 trending API，用 search 按创建时间+星数模拟）

    func trending(language: String?, days: Int, token: String) async throws -> [Repo] {
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        var q = "created:>\(fmt.string(from: from))"
        if let l = language, !l.isEmpty, l != "全部" { q += " language:\(l)" }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let data = try await get(
            "/search/repositories?q=\(enc)&sort=stars&order=desc&per_page=30", token: token
        )
        return try decoder.decode(SearchResponse.self, from: data).items
    }

    // MARK: - Issue 与通知

    func issueDetail(owner: String, repo: String, number: Int, token: String) async throws -> Issue {
        let data = try await get("/repos/\(owner)/\(repo)/issues/\(number)", token: token)
        return try decoder.decode(Issue.self, from: data)
    }

    func issueComments(owner: String, repo: String, number: Int, token: String) async throws -> [Comment] {
        let data = try await get("/repos/\(owner)/\(repo)/issues/\(number)/comments?per_page=50", token: token)
        return try decoder.decode([Comment].self, from: data)
    }

    func notifications(token: String) async throws -> [GHNotification] {
        let data = try await get("/notifications?per_page=50", token: token)
        return try decoder.decode([GHNotification].self, from: data)
    }

    /// 目录列表
    func contents(owner: String, repo: String, path: String, token: String) async throws -> [ContentItem] {
        let p = path.isEmpty ? "" : "/\(path)"
        let data = try await get("/repos/\(owner)/\(repo)/contents\(p)", token: token)
        return try decoder.decode([ContentItem].self, from: data)
    }

    /// 单个文件的文本内容
    func fileText(owner: String, repo: String, path: String, token: String) async throws -> String {
        let p = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(p)", token: token)
        struct File: Codable { let content: String; let encoding: String }
        let f = try decoder.decode(File.self, from: data)
        guard f.encoding == "base64" else { return f.content }
        let clean = f.content.replacingOccurrences(of: "\n", with: "")
        guard let d = Data(base64Encoded: clean) else { return f.content }
        return String(data: d, encoding: .utf8) ?? f.content
    }

    func readme(owner: String, repo: String, token: String) async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)/readme", token: token)
        struct Readme: Codable { let content: String; let encoding: String }
        let r = try decoder.decode(Readme.self, from: data)
        guard r.encoding == "base64" else { return r.content }
        let clean = r.content.replacingOccurrences(of: "\n", with: "")
        guard let d = Data(base64Encoded: clean) else { return r.content }
        return String(data: d, encoding: .utf8) ?? r.content
    }
}
