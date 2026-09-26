import Foundation

struct Owner: Codable, Hashable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct Repo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let language: String?
    let htmlUrl: String
    let owner: Owner

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case htmlUrl = "html_url"
    }
}

struct Issue: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let user: Owner
}

struct SearchResponse: Codable {
    let items: [Repo]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

/// 仓库目录条目（/repos/{owner}/{repo}/contents/{path}）
struct ContentItem: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let type: String
    let size: Int?

    var id: String { path }
    var isDir: Bool { type == "dir" }
    var isMarkdown: Bool {
        let n = name.lowercased()
        return n.hasSuffix(".md") || n.hasSuffix(".markdown") || n.hasSuffix(".mdown")
    }
}
