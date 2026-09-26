import SwiftUI

/// 用户主页 / 个人中心。login == nil 表示"我"（走 /user 与 /user/repos）
struct UserPageView: View {
    let login: String?

    @AppStorage("gh_token") private var token: String = ""
    @State private var user: User?
    @State private var repos: [Repo] = []
    @State private var stars: [Repo] = []
    @State private var fans: [User] = []
    @State private var follows: [User] = []
    @State private var tab = 0
    @State private var loading = true
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
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if loading && user == nil {
            VStack { Spacer(); ProgressView("加载中…"); Spacer() }
        } else if let e = errorText, user == nil {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
                Text(e).multilineTextAlignment(.center).foregroundColor(.secondary)
                Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            switch tab {
            case 1:
                repoList(stars, empty: "还没有 Star 的仓库")
            case 2:
                userList(fans, empty: "还没有粉丝")
            case 3:
                userList(follows, empty: "还没有关注的人")
            default:
                repoList(repos, empty: "还没有仓库")
            }
        }
    }

    private func repoList(_ list: [Repo], empty: String) -> some View {
        Group {
            if list.isEmpty {
                VStack { Spacer(); Text(empty).foregroundColor(.secondary); Spacer() }
            } else {
                List(list) { repo in
                    NavigationLink(destination: RepoDetailView(repo: repo)) {
                        RepoRow(repo: repo)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func userList(_ list: [User], empty: String) -> some View {
        Group {
            if list.isEmpty {
                VStack { Spacer(); Text(empty).foregroundColor(.secondary); Spacer() }
            } else {
                List(list) { u in
                    NavigationLink(destination: UserPageView(login: u.login)) {
                        UserRow(user: u)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let me: User
            if let l = login {
                me = try await GitHubAPI.shared.user(login: l, token: token)
            } else {
                me = try await GitHubAPI.shared.me(token: token)
            }
            user = me
            let name = me.login
            errorText = nil

            // 逐个加载，单项失败不影响其它（比如没开 repo 权限时私有仓库会 403）
            do {
                repos = login == nil
                    ? try await GitHubAPI.shared.myRepos(token: token)
                    : try await GitHubAPI.shared.userRepos(login: name, token: token)
            } catch { repos = [] }

            do { stars = try await GitHubAPI.shared.starred(login: name, token: token) }
            catch { stars = [] }

            do { fans = try await GitHubAPI.shared.followers(login: name, token: token) }
            catch { fans = [] }

            do { follows = try await GitHubAPI.shared.following(login: name, token: token) }
            catch { follows = [] }
        } catch {
            errorText = "加载失败：\(error.localizedDescription)"
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
    @AppStorage("gh_token") private var token: String = ""

    var body: some View {
        NavigationView {
            Group {
                if token.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("需要在「设置」里填入 GitHub Token")
                            .foregroundColor(.secondary)
                        Text("Token 只需 repo 与 read:user 权限，用于读取你的仓库、Star 和通知")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    UserPageView(login: nil)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
