import SwiftUI

/// 仓库文件浏览：目录可递归进入，Markdown 文件渲染，其他文件显示原文
struct FileBrowserView: View {
    let owner: String
    let repo: String
    let path: String

    @AppStorage("gh_token") private var token: String = ""
    @State private var items: [ContentItem] = []
    @State private var loading = true
    @State private var errorText: String?

    private var sorted: [ContentItem] {
        items.sorted { a, b in
            if a.isDir != b.isDir { return a.isDir }
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    private var title: String {
        path.isEmpty ? "文件" : (path as NSString).lastPathComponent
    }

    var body: some View {
        List {
            if loading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("加载中…").foregroundColor(.secondary)
                }
            } else if let e = errorText {
                Text(e).font(.caption).foregroundColor(.secondary)
            } else if sorted.isEmpty {
                Text("（空目录）").foregroundColor(.secondary)
            } else {
                ForEach(sorted) { item in
                    if item.isDir {
                        NavigationLink(
                            destination: FileBrowserView(owner: owner, repo: repo, path: item.path)
                        ) {
                            Label(item.name, systemImage: "folder")
                        }
                    } else {
                        NavigationLink(
                            destination: FileTextView(owner: owner, repo: repo, item: item)
                        ) {
                            Label(item.name, systemImage: item.isMarkdown ? "doc.richtext" : "doc")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            items = try await GitHubAPI.shared.contents(
                owner: owner, repo: repo, path: path, token: token
            )
        } catch {
            items = []
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}

/// 单文件内容：Markdown 走渲染器，其余显示原文
struct FileTextView: View {
    let owner: String
    let repo: String
    let item: ContentItem

    @AppStorage("gh_token") private var token: String = ""
    @State private var text = ""
    @State private var loading = true
    @State private var showRaw = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if let e = errorText {
                Text(e).font(.caption).foregroundColor(.secondary)
            } else if item.isMarkdown && !showRaw {
                ScrollView {
                    MarkdownView(text: text).padding()
                }
            } else {
                ScrollView {
                    Text(text.isEmpty ? "（空文件）" : text)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if item.isMarkdown {
                    Button(showRaw ? "渲染" : "原文") { showRaw.toggle() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let size = item.size, size > 400_000 {
            text = "（文件 \(size / 1024) KB，超过 GitHub Contents API 的 1MB/400KB 文本限制，请到 Safari 查看）"
            return
        }
        do {
            text = try await GitHubAPI.shared.fileText(
                owner: owner, repo: repo, path: item.path, token: token
            )
        } catch {
            text = ""
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}
