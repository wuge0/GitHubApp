import SwiftUI

/// README / 文件里的相对路径图片要拼成 raw.githubusercontent.com 才能加载，
/// base 就是这个上下文（owner / repo / 分支）。
struct MDBase {
    let owner: String
    let repo: String
    let branch: String

    func resolve(_ raw: String) -> URL? {
        if let u = URL(string: raw), u.scheme != nil { return u }
        var p = raw
        if p.hasPrefix("./") { p = String(p.dropFirst(2)) }
        if p.hasPrefix("/") { p = String(p.dropFirst()) }
        guard !p.isEmpty else { return nil }
        let enc = p.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? p
        return URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(enc)")
    }
}

/// 极简 Markdown 渲染器（零依赖）
/// 块级结构自己解析；行内语法交给 iOS 15 的 AttributedString(markdown:)
///
/// 解析只在 init 做一次——此前是计算属性，body 每求值一次就全量重解析，
/// 长 README 加几十条评论时会明显掉帧。
struct MarkdownView: View {
    let base: MDBase?
    private let blocks: [MDBlock]

    init(text: String, base: MDBase? = nil) {
        self.base = base
        self.blocks = MDParser.parse(text)
    }

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
            Text(MDInline.attr(MDInline.plain(t)))
                .font(.system(size: MDInline.headingSize(level), weight: .bold))
                .padding(.top, level <= 2 ? 6 : 2)

        case .paragraph(let t):
            Text(MDInline.attr(MDInline.plain(t)))
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
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        if let checked = item.checked {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .font(.caption)
                                .foregroundColor(checked ? .green : .secondary)
                        } else {
                            Text(item.depth == 0 ? "•" : "◦")
                                .foregroundColor(.secondary)
                        }
                        Text(MDInline.attr(MDInline.plain(item.text)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, CGFloat(min(item.depth, 4)) * 14)
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).").monospacedDigit().foregroundColor(.secondary)
                        Text(MDInline.attr(MDInline.plain(item.text)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, CGFloat(min(item.depth, 4)) * 14)
                }
            }

        case .quote(let t):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 3)
                Text(MDInline.attr(MDInline.plain(t)))
                    .italic()
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .rule:
            Divider().padding(.vertical, 2)

        case .table(let header, let rows):
            table(header: header, rows: rows)

        case .image(let alt, let url):
            imageView(alt: alt, url: url)
        }
    }

    // MARK: 表格（GitHub README 里最常见的缺失项）

    private func table(header: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<header.count, id: \.self) { c in
                        Text(MDInline.attr(MDInline.plain(header[c])))
                            .font(.caption.bold())
                            .frame(minWidth: 90, maxWidth: 260, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                Divider()
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<header.count, id: \.self) { c in
                            Text(MDInline.attr(MDInline.plain(c < rows[r].count ? rows[r][c] : "")))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 90, maxWidth: 260, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                        }
                    }
                    Divider()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: 图片

    private func imageView(alt: String, url: String) -> some View {
        let absolute = URL(string: url).flatMap { $0.scheme == nil ? nil : $0 }
        let resolved = base.flatMap { $0.resolve(url) } ?? absolute
        return Group {
            if let u = resolved {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().cornerRadius(6)
                    case .failure:
                        Text("🖼 \(alt)").font(.caption).foregroundColor(.secondary)
                    case .empty:
                        HStack { Spacer(); ProgressView(); Spacer() }
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
