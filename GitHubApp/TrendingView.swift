import SwiftUI

/// 趋势榜。切换筛选条件时会取消上一次未完成的请求，避免慢请求覆盖新结果。
struct TrendingView: View {
    @ObservedObject private var auth = TokenStore.shared

    @State private var days = 7
    @State private var language = "全部"
    @State private var repos: [Repo] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var loadTask: Task<Void, Never>?

    private let languages = ["全部", "Swift", "Kotlin", "JavaScript", "TypeScript",
                             "Python", "Go", "Rust", "Java", "C++", "Dart"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Picker("时间", selection: $days) {
                        Text("今日").tag(1)
                        Text("本周").tag(7)
                        Text("本月").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)

                    Spacer()

                    Menu {
                        Picker("语言", selection: $language) {
                            ForEach(languages, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        Label(language, systemImage: "chevron.down.circle")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                content
            }
            .navigationTitle("趋势")
            .task { reload() }
            .onChange(of: days) { _ in reload() }
            .onChange(of: language) { _ in reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let e = errorText, repos.isEmpty {
            ErrorStateView(message: e) { reload() }
        } else if repos.isEmpty {
            if loading {
                LoadingView()
            } else {
                EmptyStateView(systemImage: "chart.line.uptrend.xyaxis", text: "暂无数据")
            }
        } else {
            List {
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
                MoreButton(hasMore: hasMore, loading: loading) { loadMore() }
            }
            .listStyle(.plain)
            .refreshable { await load(reset: true) }
        }
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
            let r = try await GitHubAPI.shared.trending(
                language: language, days: days, page: page, token: auth.token
            )
            try Task.checkCancellation()
            hasMore = r.count >= 30
            repos = reset ? r : repos + r
        } catch is CancellationError {
            return
        } catch {
            if reset { repos = [] }
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}
