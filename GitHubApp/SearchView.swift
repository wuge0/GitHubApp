import SwiftUI

struct SearchView: View {
    @ObservedObject private var auth = TokenStore.shared

    @State private var query = "swift"
    @State private var repos: [Repo] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            content
                .navigationTitle("GitHub")
                .searchable(text: $query, prompt: "搜索仓库")
                .onSubmit(of: .search) { Task { await load(reset: true) } }
        }
        // token 变化后自动重搜（比如刚在设置里填完 Token）
        .task(id: auth.token) { await load(reset: true) }
    }

    @ViewBuilder
    private var content: some View {
        if let err = errorText, repos.isEmpty {
            ErrorStateView(message: err) { Task { await load(reset: true) } }
        } else if repos.isEmpty {
            if loading {
                LoadingView()
            } else {
                EmptyStateView(systemImage: "magnifyingglass", text: "输入关键词搜索 GitHub 仓库")
            }
        } else {
            List {
                ForEach(repos) { repo in
                    NavigationLink(destination: RepoDetailView(repo: repo)) {
                        RepoRow(repo: repo)
                    }
                }
                MoreButton(hasMore: hasMore, loading: loading) { loadMore() }
            }
            .listStyle(.plain)
            .refreshable { await load(reset: true) }
        }
    }

    private func loadMore() {
        guard hasMore, !loading else { return }
        page += 1
        Task { await load(reset: false) }
    }

    @MainActor
    private func load(reset: Bool) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        if reset { page = 1 }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let r = try await GitHubAPI.shared.searchRepos(query: q, page: page, token: auth.token)
            hasMore = r.count >= 30
            repos = reset ? r : repos + r
        } catch {
            if reset { repos = [] }
            errorText = "加载失败：\(error.localizedDescription)"
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
                    Label(compactCount(repo.stargazersCount), systemImage: "star")
                    Label(compactCount(repo.forksCount), systemImage: "tuningfork")
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
