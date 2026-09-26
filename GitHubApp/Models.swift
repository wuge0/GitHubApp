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
    let body: String?
    let comments: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, state, user, body, comments
        case createdAt = "created_at"
    }
}

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: String
    let name: String?
    let bio: String?
    let publicRepos: Int?
    let followers: Int?
    let following: Int?
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login, name, bio, followers, following
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
        case htmlUrl = "html_url"
    }
}

struct EventActor: Codable, Hashable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct EventRepo: Codable, Hashable {
    let name: String
}

struct Event: Codable, Identifiable {
    let id: String
    let type: String
    let actor: EventActor?
    let repo: EventRepo?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, actor, repo
        case createdAt = "created_at"
    }
}

struct Comment: Codable, Identifiable, Hashable {
    let id: Int
    let user: Owner
    let body: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case createdAt = "created_at"
    }
}

struct NotificationSubject: Codable {
    let title: String
    let type: String
    let url: String?
}

struct NotificationRepo: Codable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

struct GHNotification: Codable, Identifiable {
    let id: String
    let unread: Bool
    let subject: NotificationSubject
    let repository: NotificationRepo?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, unread, subject, repository
        case updatedAt = "updated_at"
    }
}

struct SearchResponse: Codable {
    let items: [Repo]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

/// ISO8601 时间 → "3 天前" 这类相对描述
func timeAgo(_ iso: String?) -> String {
    guard let iso = iso, !iso.isEmpty else { return "" }
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    let date = withFractional.date(from: iso) ?? plain.date(from: iso)
    guard let d = date else { return String(iso.prefix(10)) }
    let s = Date().timeIntervalSince(d)
    if s < 60 { return "刚刚" }
    if s < 3600 { return "\(Int(s / 60)) 分钟前" }
    if s < 86_400 { return "\(Int(s / 3600)) 小时前" }
    if s < 2_592_000 { return "\(Int(s / 86_400)) 天前" }
    if s < 31_536_000 { return "\(Int(s / 2_592_000)) 个月前" }
    return "\(Int(s / 31_536_000)) 年前"
}

/// 从 https://api.github.com/repos/{o}/{r}/issues/{n} 解析出三元组
func parseIssueURL(_ s: String?) -> (owner: String, repo: String, number: Int)? {
    guard let s = s, let u = URL(string: s) else { return nil }
    let c = u.pathComponents
    guard c.count >= 6, c[1] == "repos", c[4] == "issues", let n = Int(c[5]) else { return nil }
    return (c[2], c[3], n)
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
