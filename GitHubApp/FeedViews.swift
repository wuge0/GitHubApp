import SwiftUI

// MARK: - 趋势榜

struct TrendingView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var days = 7
    @State private var language = "全部"
    @State private var repos: [Repo] = []
    @State private var loading = false
    @State private var errorText: String?

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
            .task { await load() }
            .onChange(of: days) { _ in Task { await load() } }
            .onChange(of: language) { _ in Task { await load() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let e = errorText {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
                Text(e).multilineTextAlignment(.center).foregroundColor(.secondary)
                Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent)
            }
            .padding()
        } else if repos.isEmpty {
            VStack { Spacer(); if loading { ProgressView("加载中…") } else { Text("暂无数据").foregroundColor(.secondary) }; Spacer() }
        } else {
            List(Array(repos.enumerated()), id: \.element.id) { idx, repo in
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
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            repos = try await GitHubAPI.shared.trending(language: language, days: days, token: token)
        } catch {
            repos = []
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 动态 / 通知

struct DynamicView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var tab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("分类", selection: $tab) {
                    Text("动态").tag(0)
                    Text("通知").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if token.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bell.slash").font(.largeTitle).foregroundColor(.secondary)
                        Text("动态与通知需要登录，请先到「设置」填入 Token")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                } else if tab == 0 {
                    EventListView()
                } else {
                    NotificationsView()
                }
            }
            .navigationTitle("动态")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EventListView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var events: [Event] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && events.isEmpty {
                VStack { Spacer(); ProgressView("加载中…"); Spacer() }
            } else if let e = errorText {
                VStack(spacing: 12) {
                    Text(e).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
                .padding()
            } else if events.isEmpty {
                VStack { Spacer(); Text("暂无动态").foregroundColor(.secondary); Spacer() }
            } else {
                List(events) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: eventIcon(e.type))
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(e.actor?.login ?? "某人") \(eventVerb(e.type))")
                                .font(.subheadline)
                            if let r = e.repo?.name {
                                Text(r).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(timeAgo(e.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let me = try await GitHubAPI.shared.me(token: token)
            events = try await GitHubAPI.shared.events(login: me.login, token: token)
            errorText = nil
        } catch {
            events = []
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}

private func eventIcon(_ type: String) -> String {
    switch type {
    case "WatchEvent": return "star"
    case "ForkEvent": return "tuningfork"
    case "PushEvent": return "arrow.up.circle"
    case "IssuesEvent", "IssueCommentEvent": return "exclamationmark.circle"
    case "PullRequestEvent": return "arrow.triangle.pull"
    case "CreateEvent": return "plus.circle"
    case "ReleaseEvent": return "tag"
    default: return "circle"
    }
}

private func eventVerb(_ type: String) -> String {
    switch type {
    case "WatchEvent": return "star 了"
    case "ForkEvent": return "fork 了"
    case "PushEvent": return "推送了提交到"
    case "IssuesEvent": return "处理了 Issue"
    case "IssueCommentEvent": return "评论了 Issue"
    case "PullRequestEvent": return "操作了 PR"
    case "CreateEvent": return "创建了"
    case "ReleaseEvent": return "发布了"
    case "DeleteEvent": return "删除了"
    default: return type.replacingOccurrences(of: "Event", with: "")
    }
}

struct NotificationsView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var items: [GHNotification] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                VStack { Spacer(); ProgressView("加载中…"); Spacer() }
            } else if let e = errorText {
                VStack(spacing: 12) {
                    Text(e).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
                .padding()
            } else if items.isEmpty {
                VStack { Spacer(); Text("没有通知").foregroundColor(.secondary); Spacer() }
            } else {
                List(items) { n in
                    if let t = parseIssueURL(n.subject.url) {
                        NavigationLink(
                            destination: IssueDetailView(owner: t.owner, repo: t.repo, number: t.number)
                        ) {
                            notificationRow(n)
                        }
                    } else {
                        notificationRow(n)
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .task { await load() }
    }

    private func notificationRow(_ n: GHNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: n.unread ? "envelope.badge" : "envelope.open")
                .foregroundColor(n.unread ? .blue : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(n.subject.title)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(n.subject.type)
                    if let r = n.repository?.fullName { Text("· \(r)") }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text(timeAgo(n.updatedAt)).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            items = try await GitHubAPI.shared.notifications(token: token)
            errorText = nil
        } catch {
            items = []
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}
