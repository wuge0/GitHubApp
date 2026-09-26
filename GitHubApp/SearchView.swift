import SwiftUI

struct SearchView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var query = "swift"
    @State private var repos: [Repo] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            content
                .navigationTitle("GitHub")
                .searchable(text: $query, prompt: "搜索仓库")
                .onSubmit(of: .search) { Task { await search() } }
        }
        .task { await search() }
    }

    @ViewBuilder
    private var content: some View {
        if let err = errorMessage {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(err)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") { Task { await search() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if repos.isEmpty {
            VStack(spacing: 12) {
                if loading {
                    ProgressView("加载中…")
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("输入关键词搜索 GitHub 仓库")
                        .foregroundColor(.secondary)
                }
            }
        } else {
            List(repos) { repo in
                NavigationLink(destination: RepoDetailView(repo: repo)) {
                    RepoRow(repo: repo)
                }
            }
            .listStyle(.plain)
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            repos = try await GitHubAPI.shared.searchRepos(query: q, token: token)
        } catch {
            repos = []
            errorMessage = error.localizedDescription
        }
    }
}

struct RepoRow: View {
    let repo: Repo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: repo.owner.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(repo.fullName)
                    .font(.headline)
                    .lineLimit(1)
                if let d = repo.description, !d.isEmpty {
                    Text(d)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 14) {
                    Label("\(repo.stargazersCount)", systemImage: "star")
                    Label("\(repo.forksCount)", systemImage: "tuningfork")
                    if let lang = repo.language {
                        Text(lang)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
