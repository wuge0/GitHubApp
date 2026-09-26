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
