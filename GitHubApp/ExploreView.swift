import SwiftUI

/// 探索页：参考 ExistOrLive/GithubClient 的 ZLExploreViewController
/// 顶部表头 = 指南针图标 + 分段控件(仓库/开发者) + 搜索按钮；
/// 下方按「今日/本周/本月 + 语言」筛选的趋势列表（repos 走 trending，developers 走 search/users）。
struct ExploreView: View {
    @ObservedObject private var auth = TokenStore.shared

    private enum Segment: Int, CaseIterable, Hashable {
        case repos, users
        var title: String {
            switch self {
            case .repos: return "仓库"
            case .users: return "开发者"
            }
        }
    }

    @State private var segment: Segment = .repos
    @State private var days = 7
    @State private var language = "全部"

    @State private var repos: [Repo] = []
    @State private var users: [User] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var loadTask: Task<Void, Never>?
    @State private var showSearch = false

    private let languages = ["全部", "Swift", "Kotlin", "JavaScript", "TypeScript",
                             "Python", "Go", "Rust", "Java", "C++", "Dart"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                filters
                content
            }
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.inline)
            .task { reload() }
            .onChange(of: segment) { _ in reload() }
            .onChange(of: days) { _ in reload() }
            .onChange(of: language) { _ in reload() }
        }
        .fullScreenCover(isPresented: $showSearch) { SearchView() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundColor(.accentColor)
            Spacer()
            Picker("类型", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { s in
                    Text(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            Spacer()
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filters: some View {
        HStack {
            Picker("时间", selection: $days) {
                Text("今日").tag(1)
                Text("本周").tag(7)
                Text("本月").tag(30)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            Spacer()

            if segment == .repos {
                Menu {
                    Picker("语言", selection: $language) {
                        ForEach(languages, id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    Label(language, systemImage: "chevron.down.circle")
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let e = errorText, isDataEmpty {
            ErrorStateView(message: e) { reload() }
        } else if isDataEmpty {
            if loading {
                LoadingView()
            } else {
                EmptyStateView(
                    systemImage: "sparkles",
                    text: segment == .repos ? "暂无热门仓库" : "暂无热门开发者"
                )
            }
        } else {
            List {
                if segment == .repos {
                    ForEach(Array(repos.enumerated()), id: \.element.id) { idx, repo in
                        NavigationLink(destination: RepoDetailView(repo: repo)) {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                                RepoRow(repo: repo)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    ForEach(users) { user in
                        NavigationLink(destination: UserPageView(login: user.login)) {
                            UserRow(user: user)
                        }
                    }
                }
                MoreButton(hasMore: hasMore, loading: loading) { loadMore() }
            }
            .listStyle(.plain)
            .refreshable { await load(reset: true) }
        }
    }

    private var isDataEmpty: Bool {
        segment == .repos ? repos.isEmpty : users.isEmpty
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await load(reset: true) }
    }

    private func loadMore() {
        guard hasMore, !loading else { return }
        page += 1
        Task { await load(reset: false) }
    }

    @MainActor
    private func load(reset: Bool) async {
        if reset { page = 1 }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            if segment == .repos {
                let r = try await GitHubAPI.shared.trending(
                    language: language == "全部" ? nil : language,
                    days: days, page: page, token: auth.token
                )
                try Task.checkCancellation()
                hasMore = r.count >= 30
                repos = reset ? r : repos + r
            } else {
                let u = try await GitHubAPI.shared.searchUsers(
                    query: "followers:>1000",
                    page: page, token: auth.token
                )
                try Task.checkCancellation()
                hasMore = u.count >= 30
                users = reset ? u : users + u
            }
        } catch is CancellationError {
            return
        } catch {
            if reset {
                if segment == .repos { repos = [] } else { users = [] }
            }
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}
