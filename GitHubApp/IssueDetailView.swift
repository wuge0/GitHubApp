import SwiftUI

struct IssueDetailView: View {
    let owner: String
    let repo: String
    let number: Int

    @AppStorage("gh_token") private var token: String = ""
    @State private var issue: Issue?
    @State private var comments: [Comment] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && issue == nil {
                VStack { Spacer(); ProgressView("加载中…"); Spacer() }
            } else if let e = errorText, issue == nil {
                VStack(spacing: 12) {
                    Text(e).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let i = issue {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 标题与状态
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: i.state == "open" ? "circlebadge" : "checkmark.circle.fill")
                                .foregroundColor(i.state == "open" ? .green : .purple)
                            Text(i.title)
                                .font(.headline)
                        }
                        Text("\(i.user.login) · \(timeAgo(i.createdAt)) · #\(i.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        // 正文
                        if let body = i.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            MarkdownView(text: body)
                        } else {
                            Text("（该 Issue 没有正文）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 评论
                        if !comments.isEmpty {
                            Divider()
                            Text("评论 \(comments.count)")
                                .font(.subheadline.bold())
                            ForEach(comments) { c in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        AsyncImage(url: URL(string: c.user.avatarUrl)) { im in
                                            im.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.secondary.opacity(0.15)
                                        }
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                        Text(c.user.login).font(.caption.bold())
                                        Text(timeAgo(c.createdAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if let b = c.body, !b.isEmpty {
                                        MarkdownView(text: b)
                                    }
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("#\(number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            issue = try await GitHubAPI.shared.issueDetail(
                owner: owner, repo: repo, number: number, token: token
            )
            errorText = nil
        } catch {
            errorText = "加载失败：\(error.localizedDescription)"
        }
        do {
            comments = try await GitHubAPI.shared.issueComments(
                owner: owner, repo: repo, number: number, token: token
            )
        } catch {
            comments = []
        }
    }
}
