import SwiftUI

struct RepoDetailView: View {
    let repo: Repo

    @AppStorage("gh_token") private var token: String = ""
    @State private var readme = ""
    @State private var issues: [Issue] = []
    @State private var loading = true
    @State private var note: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(repo.fullName)
                        .font(.title3.bold())
                    if let d = repo.description, !d.isEmpty {
                        Text(d).font(.subheadline)
                    }
                    HStack(spacing: 16) {
                        Label("\(repo.stargazersCount)", systemImage: "star")
                        Label("\(repo.forksCount)", systemImage: "tuningfork")
                        Label("\(repo.openIssuesCount)", systemImage: "exclamationmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    if let url = URL(string: repo.htmlUrl) {
                        Link("在 Safari 中打开", destination: url)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("README") {
                if loading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("加载中…").foregroundColor(.secondary)
                    }
                } else {
                    Text(readme.isEmpty ? "（该仓库没有 README）" : readme)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section("最近 Issue") {
                if loading {
                    ProgressView()
                } else if issues.isEmpty {
                    Text("（没有 Issue）").foregroundColor(.secondary)
                } else {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: issue.state == "open" ? "circlebadge" : "checkmark.circle.fill")
                                .foregroundColor(issue.state == "open" ? .green : .purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text("#\(issue.number) · \(issue.user.login)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            if let note = note {
                Section {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            readme = try await GitHubAPI.shared.readme(owner: repo.owner.login, repo: repo.name, token: token)
        } catch {
            readme = ""
            note = "README 加载失败：\(error.localizedDescription)"
        }
        do {
            issues = try await GitHubAPI.shared.issues(owner: repo.owner.login, repo: repo.name, token: token)
        } catch {
            issues = []
        }
    }
}
