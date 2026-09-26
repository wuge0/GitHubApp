import Foundation

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

/// 并发执行但吞掉单个错误：任务组里某一路 403 不影响其它路
func orNil<T>(_ body: @escaping () async throws -> T) async -> T? {
    do { return try await body() } catch { return nil }
}

/// 星数 / 粉丝数等大数字的紧凑写法
func compactCount(_ n: Int) -> String {
    if n < 1000 { return "\(n)" }
    if n < 1_000_000 { return String(format: "%.1fk", Double(n) / 1000.0) }
    return String(format: "%.1fm", Double(n) / 1_000_000.0)
}
