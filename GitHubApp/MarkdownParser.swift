import Foundation

/// 列表项：depth 支持嵌套，checked 非 nil 表示任务列表（GitHub 的 - [ ] / - [x]）
struct MDListItem {
    let depth: Int
    let text: String
    let checked: Bool?
}

enum MDBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(lang: String, text: String)
    case bullet([MDListItem])
    case ordered([MDListItem])
    case quote(String)
    case rule
    case image(alt: String, url: String)
    case table(header: [String], rows: [[String]])
}

// MARK: - 行内与文本清洗

enum MDInline {
    static func attr(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let a = try? AttributedString(markdown: s, options: opts) { return a }
        return AttributedString(s)
    }

    /// 渲染前先剥掉 HTML 标签，保留文本；<br> / </p> 换行；解常见实体
    static func plain(_ s: String) -> String {
        var out = replace(s, #"(?i)<br\s*/?>"#, "\n")
        out = replace(out, #"(?i)</p\s*>"#, "\n")
        out = replace(out, #"(?i)<li\s*/?>"#, "\n")
        out = replace(out, "<[^>]+>", "")
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&lt;", with: "<")
        out = out.replacingOccurrences(of: "&gt;", with: ">")
        out = out.replacingOccurrences(of: "&quot;", with: "\"")
        out = out.replacingOccurrences(of: "&#39;", with: "'")
        return out
    }

    static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 18
        default: return 16
        }
    }

    private static func replace(_ s: String, _ pattern: String, _ template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return s }
        let r = NSRange(s.startIndex..., in: s)
        return re.stringByReplacingMatches(in: s, options: [], range: r, withTemplate: template)
    }
}

// MARK: - 块级解析

enum MDParser {
    static func parse(_ src: String) -> [MDBlock] {
        let lines = src
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var blocks: [MDBlock] = []
        var para: [String] = []
        var i = 0

        func flushPara() {
            if !para.isEmpty {
                blocks.append(.paragraph(para.joined(separator: "\n")))
                para = []
            }
        }

        while i < lines.count {
            let line = lines[i]
            let t = line.trimmingCharacters(in: .whitespaces)

            // 代码块（``` 或 ~~~）
            if t.hasPrefix("```") || t.hasPrefix("~~~") {
                flushPara()
                let mark = String(t.prefix(3))
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(mark) {
                    code.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(.code(lang: lang, text: code.joined(separator: "\n")))
                continue
            }

            // 空行
            if t.isEmpty {
                flushPara()
                i += 1
                continue
            }

            // 表格：| a | b | 紧跟 | --- | --- |
            if t.hasPrefix("|"), i + 1 < lines.count,
               isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                flushPara()
                let header = splitRow(t)
                i += 2
                var rows: [[String]] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    guard lt.hasPrefix("|") else { break }
                    rows.append(splitRow(lt))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // 标题
            if let level = headingLevel(t) {
                flushPara()
                let body = String(t.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: level, text: body))
                i += 1
                continue
            }

            // 分割线
            if isRule(t) {
                flushPara()
                blocks.append(.rule)
                i += 1
                continue
            }

            // 引用
            if t.hasPrefix(">") {
                flushPara()
                var q: [String] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    guard lt.hasPrefix(">") else { break }
                    q.append(String(lt.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.quote(q.joined(separator: "\n")))
                continue
            }

            // 无序列表（含 - [ ] / - [x] 任务项）
            if bulletItem(t) != nil {
                flushPara()
                var items: [MDListItem] = []
                while i < lines.count, let it = bulletItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(it)
                    i += 1
                }
                blocks.append(.bullet(items))
                continue
            }

            // 有序列表
            if orderedItem(t) != nil {
                flushPara()
                var items: [MDListItem] = []
                while i < lines.count, let it = orderedItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(it)
                    i += 1
                }
                blocks.append(.ordered(items))
                continue
            }

            // 独占一行的图片（![alt](url) 或 <img src="...">）
            if let img = imageParts(t) {
                flushPara()
                blocks.append(.image(alt: img.0, url: img.1))
                i += 1
                continue
            }

            para.append(line)
            i += 1
        }
        flushPara()
        return blocks
    }

    // MARK: 判定辅助

    private static func headingLevel(_ s: String) -> Int? {
        var n = 0
        for ch in s {
            if ch == "#" { n += 1 } else { break }
        }
        guard n >= 1, n <= 6, s.count > n else { return nil }
        let idx = s.index(s.startIndex, offsetBy: n)
        return s[idx] == " " ? n : nil
    }

    private static func isRule(_ s: String) -> Bool {
        let t = s.replacingOccurrences(of: " ", with: "")
        guard t.count >= 3 else { return false }
        let set = Set(t)
        return set == ["-"] || set == ["*"] || set == ["_"]
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        guard s.hasPrefix("|") else { return false }
        let body = s.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return false }
        return body.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }

    private static func splitRow(_ s: String) -> [String] {
        var t = s
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func bulletItem(_ s: String) -> MDListItem? {
        let indent = s.prefix { $0 == " " || $0 == "\t" }
        let depth = indent.count / 2
        let t = String(s.dropFirst(indent.count))
        guard t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") else { return nil }
        var body = String(t.dropFirst(2))
        if body.hasPrefix("[ ] ") {
            return MDListItem(depth: depth, text: String(body.dropFirst(4)), checked: false)
        }
        if body.hasPrefix("[x] ") || body.hasPrefix("[X] ") {
            return MDListItem(depth: depth, text: String(body.dropFirst(4)), checked: true)
        }
        return MDListItem(depth: depth, text: body, checked: nil)
    }

    private static func orderedItem(_ s: String) -> MDListItem? {
        let indent = s.prefix { $0 == " " || $0 == "\t" }
        let depth = indent.count / 3
        let t = String(s.dropFirst(indent.count))
        guard let dot = t.range(of: ".") else { return nil }
        let num = String(t[t.startIndex..<dot.lowerBound])
        guard !num.isEmpty, num.allSatisfy({ $0.isNumber }) else { return nil }
        let after = t.index(after: dot.lowerBound)
        guard after < t.endIndex, t[after] == " " else { return nil }
        return MDListItem(depth: depth, text: String(t[t.index(after: after)...]), checked: nil)
    }

    private static func imageParts(_ s: String) -> (String, String)? {
        if s.hasPrefix("![") {
            guard let close = s.range(of: "]("), s.hasSuffix(")") else { return nil }
            let alt = String(s[s.index(s.startIndex, offsetBy: 2)..<close.lowerBound])
            let url = String(s[close.upperBound..<s.index(before: s.endIndex)])
            return (alt, url)
        }
        if let u = capture(s, #"<img[^>]*src\s*=\s*["']([^"']+)["']"#) {
            let alt = capture(s, #"<img[^>]*alt\s*=\s*["']([^"']*)["']"#) ?? "图片"
            return (alt, u)
        }
        return nil
    }

    private static func capture(_ s: String, _ pattern: String, group: Int = 1) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let r = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, options: [], range: r), m.numberOfRanges > group else { return nil }
        guard let g = Range(m.range(at: group), in: s) else { return nil }
        return String(s[g])
    }
}
