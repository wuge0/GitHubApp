import SwiftUI

/// 极简 Markdown 渲染器（零依赖）
/// 块级结构自己解析；行内语法交给 iOS 15 的 AttributedString(markdown:)
struct MarkdownView: View {
    let text: String

    private var blocks: [MDBlock] { MDParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MDBlock) -> some View {
        switch block {
        case .heading(let level, let t):
            Text(MDInline.attr(t))
                .font(.system(size: MDInline.headingSize(level), weight: .bold))
                .padding(.top, level <= 2 ? 6 : 2)

        case .paragraph(let t):
            Text(MDInline.attr(t))
                .fixedSize(horizontal: false, vertical: true)

        case .code(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(MDInline.attr(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).").monospacedDigit()
                        Text(MDInline.attr(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .quote(let t):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 3)
                Text(MDInline.attr(t))
                    .italic()
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .rule:
            Divider().padding(.vertical, 2)

        case .image(let alt, let url):
            if let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().cornerRadius(6)
                    case .failure:
                        Text("🖼 \(alt)").font(.caption).foregroundColor(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 320)
            } else {
                Text("🖼 \(alt)").font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 行内渲染

enum MDInline {
    static func attr(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let a = try? AttributedString(markdown: s, options: opts) { return a }
        return AttributedString(s)
    }

    static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 18
        default: return 16
        }
    }
}

// MARK: - 块级解析

enum MDBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(lang: String, text: String)
    case bullet([String])
    case ordered([String])
    case quote(String)
    case rule
    case image(alt: String, url: String)
}

enum MDParser {
    static func parse(_ src: String) -> [MDBlock] {
        let lines = src
            .replacingOccurrences(of: "\r\n", with: "\n")
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

            // 代码块
            if t.hasPrefix("```") {
                flushPara()
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
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

            // 无序列表
            if isBullet(t) {
                flushPara()
                var items: [String] = []
                while i < lines.count, isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(lt.dropFirst(2)))
                    i += 1
                }
                blocks.append(.bullet(items))
                continue
            }

            // 有序列表
            if let rest = orderedBody(t) {
                flushPara()
                var items: [String] = []
                while i < lines.count,
                      let r = orderedBody(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(r)
                    i += 1
                }
                blocks.append(.ordered(items))
                continue
            }

            // 独占一行的图片
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
        return (set == ["-"] || set == ["*"] || set == ["_"])
    }

    private static func isBullet(_ s: String) -> Bool {
        s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ")
    }

    private static func orderedBody(_ s: String) -> String? {
        // 形如 "1. xxx"
        guard let dot = s.range(of: ".") else { return nil }
        let num = String(s[s.startIndex..<dot.lowerBound])
        guard !num.isEmpty, num.allSatisfy({ $0.isNumber }) else { return nil }
        let after = s.index(after: dot.lowerBound)
        guard after < s.endIndex, s[after] == " " else { return nil }
        return String(s[s.index(after: after)...])
    }

    private static func imageParts(_ s: String) -> (String, String)? {
        guard s.hasPrefix("![") else { return nil }
        guard let close = s.range(of: "]("), s.hasSuffix(")") else { return nil }
        let alt = String(s[s.index(s.startIndex, offsetBy: 2)..<close.lowerBound])
        let url = String(s[close.upperBound..<s.index(before: s.endIndex)])
        return (alt, url)
    }
}
