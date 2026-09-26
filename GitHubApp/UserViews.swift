import SwiftUI

/// 用户主页的四个列表，用于分页状态
private enum UserTab: Int {
    case repos, stars, fans, follows
}

/// 用户主页 / 个人中心。login == nil 表示"我"（走 /user 与 /user/repos）
struct UserPageView: View {
    let login: String?

    @ObservedObject private var auth = TokenStore.shared

    @State private var user: User?
    @State private var repos: [Repo] = []
    @State private var stars: [Repo] = []
    @State private var fans: [User] = []
    @State private var follows: [User] = []
    @State private var tab = 0

    @State private var repoPage = 1
    @State private var starPage = 1
    @State private var fanPage = 1
    @State private var followPage = 1
    @State private var repoMore = false
    @State private var starMore = false
    @State private var fanMore = false
    @State private var followMore = false

    @State private var loading = true
    @State private var appending = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            if let u = user {
                ProfileHeader(user: u)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
            }
            Picker("分类", selection: $tab) {
                Text("仓库").tag(0)
                Text("Star").tag(1)
                Text("粉丝").tag(2)
                Text("关注").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)

            content
        }
        .navigationTitle(login ?? "我的")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
    }

    @ViewBuilder
    private var content: some View {
        if loading && user == nil {
            LoadingView()
        } else if let e = errorText, user == nil {
            ErrorStateView(message: e) { Task { await load(reset: true) } }
        } else {
            switch UserTab(rawValue: tab) ?? .repos {
            case .stars:
                repoList(stars, empty: "还没有 Star 的仓库", more: starMore) { loadMore(.stars) }
            case .fans:
                userList(fans, empty: "还没有粉丝", more: fanMore) { loadMore(.fans) }
            case .follows:
                userList(follows, empty: "还没有关注的人", more: followMore) { loadMore(.follows) }
            case .repos:
                repoList(repos, empty: "还没有仓库", more: repoMore) { loadMore(.repos) }
            }
        }
    }

    private func repoList(_ list: [Repo], empty: String, more: Bool, moreAction: @escaping () -> Void) -> some View {
        Group {
            if list.isEmpty {
                EmptyStateView(systemImage: "book.closed", text: empty)
            } else {
                List {
                    ForEach(list) { repo in
                        NavigationLink(destination: RepoDetailView(repo: repo)) {
                            RepoRow(repo: repo)
                        }
                    }
                    MoreButton(hasMore: more, loading: appending, load: moreAction)
                }
                .listStyle(.plain)
            }
        }
    }

    private func userList(_ list: [User], empty: String, more: Bool, moreAction: @escaping () -> Void) -> some View {
        Group {
            if list.isEmpty {
                EmptyStateView(systemImage: "person.2", text: empty)
            } else {
                List {
                    ForEach(list) { u in
                        NavigationLink(destination: UserPageView(login: u.login)) {
                            UserRow(user: u)
                        }
                    }
                    MoreButton(hasMore: more, loading: appending, load: moreAction)
                }
                .listStyle(.plain)
            }
        }
    }

    private func loadMore(_ t: UserTab) {
        guard !appending, !loading else { return }
        switch t {
        case .repos: guard repoMore else { return }; repoPage += 1
        case .stars: guard starMore else { return }; starPage += 1
        case .fans: guard fanMore else { return }; fanPage += 1
        case .follows: guard followMore else { return }; followPage += 1
        }
        Task { await load(reset: false, only: t) }
    }

    // MARK: 并行拉取：四路同时发，单路失败（比如私有仓库 403）不影响其它

    @MainActor
    private func load(reset: Bool, only: UserTab? = nil) async {
        let t = auth.token
        loading = true
        defer { loading = false }

        if reset {
            errorText = nil
            repoPage = 1; starPage = 1; fanPage = 1; followPage = 1
        }

        do {
            let u: User
            if let l = login {
                u = try await GitHubAPI.shared.user(login: l, token: t)
            } else {
                u = try await GitHubAPI.shared.me(token: t)
            }
            user = u
            errorText = nil

            let name = u.login
            let isMe = (login == nil)

            if let only = only {
                appending = true
                defer { appending = false }
                await appendOne(only, isMe: isMe, name: name, token: t)
                return
            }

            async let rp = reposPage(isMe: isMe, name: name, page: repoPage, token: t)
            async let sp = orNil { try await GitHubAPI.shared.starred(login: name, page: starPage, token: t) }
            async let fp = orNil { try await GitHubAPI.shared.followers(login: name, page: fanPage, token: t) }
            async let gp = orNil { try await GitHubAPI.shared.following(login: name, page: followPage, token: t) }

            repos = await rp ?? []
            stars = await sp ?? []
            fans = await fp ?? []
            follows = await gp ?? []
            repoMore = repos.count >= 50
            starMore = stars.count >= 50
            fanMore = fans.count >= 50
            followMore = follows.count >= 50
        } catch {
            errorText = "加载失败：\(error.localizedDescription)"
        }
    }

    /// 仓库这一路要区分"我的"（含私有）与"别人的"，抽成方法避免 async let 三元表达式
    private func reposPage(isMe: Bool, name: String, page: Int, token: String) async -> [Repo]? {
        if isMe {
            return await orNil { try await GitHubAPI.shared.myRepos(page: page, token: token) }
        }
        return await orNil { try await GitHubAPI.shared.userRepos(login: name, page: page, token: token) }
    }

    @MainActor
    private func appendOne(_ tab: UserTab, isMe: Bool, name: String, token: String) async {
        switch tab {
        case .repos:
            let v = await reposPage(isMe: isMe, name: name, page: repoPage, token: token) ?? []
            repos += v
            repoMore = v.count >= 50
        case .stars:
            let v = await orNil { try await GitHubAPI.shared.starred(login: name, page: starPage, token: token) } ?? []
            stars += v
            starMore = v.count >= 50
        case .fans:
            let v = await orNil { try await GitHubAPI.shared.followers(login: name, page: fanPage, token: token) } ?? []
            fans += v
            fanMore = v.count >= 50
        case .follows:
            let v = await orNil { try await GitHubAPI.shared.following(login: name, page: followPage, token: token) } ?? []
            follows += v
            followMore = v.count >= 50
        }
    }
}

struct ProfileHeader: View {
    let user: User

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name ?? user.login)
                    .font(.headline)
                Text("@\(user.login)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 14) {
                    if let r = user.publicRepos { Label("\(r)", systemImage: "book.closed") }
                    if let f = user.followers { Label("\(f)", systemImage: "person.2") }
                    if let g = user.following { Label("\(g)", systemImage: "person.badge.plus") }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? user.login).font(.subheadline)
                Text("@\(user.login)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// "我的" Tab 根视图：没填 Token 时引导去设置
struct MeView: View {
    @ObservedObject private var auth = TokenStore.shared

    var body: some View {
        NavigationView {
            Group {
                if auth.token.isEmpty {
                    EmptyStateView(
                        systemImage: "person.crop.circle.badge.questionmark",
                        text: "需要在「设置」里填入 GitHub Token，只需 repo 与 read:user 权限"
                    )
                } else {
                    UserPageView(login: nil)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
