import Foundation

enum GitHubError: LocalizedError {
    case noData
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "没有收到数据"
        case .badStatus(let code):
            if code == 403 {
                return "API 限额已用完或没有权限（匿名 60 次/小时，建议填入 Token）"
            }
            if code == 401 { return "Token 无效" }
            if code == 404 { return "资源不存在，或 Token 权限不足" }
            if code == 422 { return "查询条件不合法" }
            return "请求失败，HTTP \(code)"
        }
    }
}

final class GitHubAPI {
    static let shared = GitHubAPI()

    private let base = "https://api.github.com"
    private let decoder = JSONDecoder()

    /// 自建 session：带超时 + 磁盘缓存。
    /// GitHub 返回 ETag/Cache-Control，命中缓存走 304，不消耗配额。
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            diskPath: "githubapi"
        )
        cfg.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        ]
        return URLSession(configuration: cfg)
    }()

    // MARK: - 底层

    /// 用 URLComponents 拼查询串——此前用 addingPercentEncoding(.urlQueryAllowed)，
    /// 它不转义 + 和 &，导致搜 "c++" 变成搜 "c  "、含 & 的关键词被切成两个参数。
    private func get(_ path: String, query: [String: String] = [:], token: String) async throws -> Data {
        var comp = URLComponents(string: base + path)
        if !query.isEmpty {
            comp?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comp?.url else { throw GitHubError.noData }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GitHubError.noData }
        guard (200..<300).contains(http.statusCode) else { throw GitHubError.badStatus(http.statusCode) }
        return data
    }

    /// 路径逐段转义（文件名里可能有空格、#、?）
    private func percentPath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    // MARK: - 搜索

    func searchRepos(query: String, page: Int = 1, token: String) async throws -> [Repo] {
        let data = try await get(
            "/search/repositories",
            query: ["q": query, "per_page": "30", "sort": "stars", "page": "\(page)"],
            token: token
        )
        return try decoder.decode(SearchResponse.self, from: data).items
    }

    // MARK: - 仓库

    func issues(owner: String, repo: String, page: Int = 1, token: String) async throws -> [Issue] {
        let data = try await get(
            "/repos/\(owner)/\(repo)/issues",
            query: ["per_page": "20", "state": "all", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([Issue].self, from: data)
    }

    /// 目录列表
    func contents(owner: String, repo: String, path: String, token: String) async throws -> [ContentItem] {
        let p = path.isEmpty ? "" : "/" + percentPath(path)
        let data = try await get("/repos/\(owner)/\(repo)/contents\(p)", token: token)
        return try decoder.decode([ContentItem].self, from: data)
    }

    /// 单个文件的文本内容
    func fileText(owner: String, repo: String, path: String, token: String) async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(percentPath(path))", token: token)
        return try decodeBase64Text(data)
    }

    func readme(owner: String, repo: String, token: String) async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)/readme", token: token)
        return try decodeBase64Text(data)
    }

    private func decodeBase64Text(_ data: Data) throws -> String {
        struct Encoded: Codable { let content: String; let encoding: String }
        let f = try decoder.decode(Encoded.self, from: data)
        guard f.encoding == "base64" else { return f.content }
        let clean = f.content.replacingOccurrences(of: "\n", with: "")
        guard let d = Data(base64Encoded: clean) else { return f.content }
        return String(data: d, encoding: .utf8) ?? f.content
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

    func userRepos(login: String, page: Int = 1, token: String) async throws -> [Repo] {
        let data = try await get(
            "/users/\(login)/repos",
            query: ["per_page": "50", "sort": "updated", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([Repo].self, from: data)
    }

    /// 当前登录者的仓库（含私有）
    func myRepos(page: Int = 1, token: String) async throws -> [Repo] {
        let data = try await get(
            "/user/repos",
            query: ["per_page": "50", "sort": "updated", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([Repo].self, from: data)
    }

    func starred(login: String, page: Int = 1, token: String) async throws -> [Repo] {
        let data = try await get(
            "/users/\(login)/starred",
            query: ["per_page": "50", "sort": "updated", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([Repo].self, from: data)
    }

    func followers(login: String, page: Int = 1, token: String) async throws -> [User] {
        let data = try await get(
            "/users/\(login)/followers",
            query: ["per_page": "50", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([User].self, from: data)
    }

    func following(login: String, page: Int = 1, token: String) async throws -> [User] {
        let data = try await get(
            "/users/\(login)/following",
            query: ["per_page": "50", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([User].self, from: data)
    }

    func events(login: String, page: Int = 1, token: String) async throws -> [Event] {
        let data = try await get(
            "/users/\(login)/events",
            query: ["per_page": "30", "page": "\(page)"],
            token: token
        )
        return try decoder.decode([Event].self, from: data)
    }

    // MARK: - 趋势（GitHub 无官方 trending API，用 search 按创建时间+星数模拟）

    func trending(language: String?, days: Int, page: Int = 1, token: String) async throws -> [Repo] {
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        var q = "created:>\(fmt.string(from: from))"
        if let l = language, !l.isEmpty, l != "全部" { q += " language:\(l)" }
        let data = try await get(
            "/search/repositories",
            query: ["q": q, "sort": "stars", "order": "desc", "per_page": "30", "page": "\(page)"],
            token: token
        )
        return try decoder.decode(SearchResponse.self, from: data).items
    }

    // MARK: - Issue 与通知

    func issueDetail(owner: String, repo: String, number: Int, token: String) async throws -> Issue {
        let data = try await get("/repos/\(owner)/\(repo)/issues/\(number)", token: token)
        return try decoder.decode(Issue.self, from: data)
    }

    func issueComments(owner: String, repo: String, number: Int, token: String) async throws -> [Comment] {
        let data = try await get(
            "/repos/\(owner)/\(repo)/issues/\(number)/comments",
            query: ["per_page": "50"],
            token: token
        )
        return try decoder.decode([Comment].self, from: data)
    }

    func notifications(token: String) async throws -> [GHNotification] {
        let data = try await get("/notifications", query: ["per_page": "50"], token: token)
        return try decoder.decode([GHNotification].self, from: data)
    }
}
