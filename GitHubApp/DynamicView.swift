import SwiftUI

// MARK: - 动态 / 通知

struct DynamicView: View {
    @ObservedObject private var auth = TokenStore.shared
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

                if auth.token.isEmpty {
                    EmptyStateView(
                        systemImage: "bell.slash",
                        text: "动态与通知需要登录，请先到「设置」填入 Token"
                    )
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

// MARK: - 动态流

struct EventListView: View {
    @ObservedObject private var auth = TokenStore.shared

    @State private var events: [Event] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && events.isEmpty {
                LoadingView()
            } else if let e = errorText, events.isEmpty {
                ErrorStateView(message: e) { Task { await load(reset: true) } }
            } else if events.isEmpty {
                EmptyStateView(systemImage: "waveform.path.ecg", text: "暂无动态")
            } else {
                List {
                    ForEach(events) { e in
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
                    MoreButton(hasMore: hasMore, loading: loading) { loadMore() }
                }
                .listStyle(.plain)
                .refreshable { await load(reset: true) }
            }
        }
        .task { await load(reset: true) }
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
        defer { loading = false }
        do {
            // login 走缓存，避免每次进页面都多打一次 /user
            let me = try await SessionStore.shared.currentLogin(token: auth.token)
            let list = try await GitHubAPI.shared.events(login: me, page: page, token: auth.token)
            hasMore = list.count >= 30
            events = reset ? list : events + list
            errorText = nil
        } catch {
            if reset { events = [] }
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

// MARK: - 通知

struct NotificationsView: View {
    @ObservedObject private var auth = TokenStore.shared

    @State private var items: [GHNotification] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                LoadingView()
            } else if let e = errorText {
                ErrorStateView(message: e) { Task { await load() } }
            } else if items.isEmpty {
                EmptyStateView(systemImage: "bell", text: "没有通知")
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

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            items = try await GitHubAPI.shared.notifications(token: auth.token)
            errorText = nil
        } catch {
            items = []
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }
}
