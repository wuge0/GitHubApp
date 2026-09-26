# GitHub 手机版（iOS，SwiftUI）

一个原生 iOS 的 GitHub 客户端，用 SwiftUI + GitHub REST API 写成，通过 GitHub Actions 无签名构建 IPA，供 TrollStore / 越狱设备侧载。

## 功能

五个 Tab：**搜索 / 趋势 / 动态 / 我的 / 设置**

### 搜索
- 关键词搜索仓库，按 star 排序，显示 owner 头像、描述、star / fork / 语言

### 趋势
- 用 `search` 接口按「创建时间 + star 数」模拟 Trending（GitHub 无官方 trending API）
- 可切 今日 / 本周 / 本月，可按语言筛选（Swift / Kotlin / Python / Go / Rust …）

### 动态
- **动态**：`/users/{login}/events`，按事件类型给图标与中文动词（star / fork / push / issue / PR / release）
- **通知**：`/notifications`，区分未读，Issue / PR 类可直接点进详情

### 仓库详情
- 基本信息（star / fork / open issues），点 owner 头像进用户主页
- **README 渲染**：自写块级解析器 + iOS 15 `AttributedString(markdown:)` 处理行内语法，支持标题 / 代码块 / 列表（含嵌套与任务列表）/ 引用 / 分割线 / **表格** / 图片 / HTML 标签剥离，可切「原文」
- README 里的相对路径图片（`./docs/x.png`）会自动按默认分支解析到 `raw.githubusercontent.com`
- **浏览文件**：目录递归进入，`.md` 走渲染器，其它文件显示原文
- **最近 Issue**：可点进 Issue 详情看正文（Markdown）与评论列表

### 个人中心 / 用户主页
- 未登录引导填 Token；登录后显示头像、昵称、bio、仓库 / 粉丝 / 关注数
- 四个分段：**仓库 / Star / 粉丝 / 关注**，点用户可继续下钻

### 设置
- 粘贴 GitHub Personal Access Token（可选），存在**系统钥匙串（Keychain）**里，不落 UserDefaults
  - 不填：匿名访问公开数据，限额 **60 次/小时**
  - 填上：限额 **5000 次/小时**，可访问私有仓库、读通知与动态

## 工程结构

```
GitHubApp.xcodeproj/                 Xcode 工程 + 共享 scheme
GitHubApp/
  GitHubAppApp.swift                 @main 入口
  ContentView.swift                  TabView 根容器（5 个 Tab）
  Models.swift                       Repo / Issue / User / Event / Comment / Notification
  GitHubAPI.swift                    网络层：URLComponents 拼查询、超时与响应缓存、分页
  TokenStore.swift                   Keychain 封装 + TokenStore + SessionStore（login 缓存）
  Extensions.swift                   timeAgo / parseIssueURL / orNil / compactCount
  PlaceholderView.swift              统一的加载态 / 空态 / 错误态 / 加载更多
  SearchView.swift                   搜索页 + 仓库行（分页）
  RepoDetailView.swift               仓库详情（README / 文件 / Issues）
  UserViews.swift                    个人中心 + 用户主页 + 用户行（四路并行 + 分页）
  TrendingView.swift                 趋势榜（切换筛选取消上一次请求 + 分页）
  DynamicView.swift                  动态流 + 通知
  IssueDetailView.swift              Issue 正文与评论
  MarkdownParser.swift               Markdown 块级解析器（零依赖）
  MarkdownView.swift                 Markdown 渲染器 + 相对路径图片解析
  FileViews.swift                    仓库文件浏览与查看
  SettingsView.swift                 Token 设置（钥匙串）
  Assets.xcassets/AppIcon...         应用图标（黑白猫头）
  Info.plist                         应用元信息
.github/workflows/
  build-unsigned-ipa.yml             无签名构建 IPA
```

## 构建 IPA

推到 GitHub 仓库的 `main` 分支（或手动触发 workflow），Actions 跑完在 **Artifacts** 下载 `GitHubApp-unsigned`，解压得到 `GitHubApp-unsigned.ipa`。

## 安装

- **TrollStore**：把 IPA 传到手机用 TrollStore 打开安装（支持 iOS 14.0–15.4.1，以及 15.5–16.6.1 / 17.0，视设备与安装向量）。
- **越狱 + AppSync Unified**：直接安装。

## 说明

- 部署目标 iOS 15.0；Bundle ID `com.example.githubapp`。
- 全程 `CODE_SIGNING_ALLOWED=NO`，不依赖 Apple 开发者账号 / 证书 / 描述文件。
- 零第三方依赖：Markdown 渲染用系统 `AttributedString`，网络用 `URLSession`，图片用 `AsyncImage`，Token 用 `Security` 框架存钥匙串。
- 已知限制：Markdown 不支持缩进代码块与脚注；行内链接在 `Text` 中可能不可点；超过 400KB 的文件只给提示不下载；Keychain 在个别侧载环境可能不可用，此时自动回退到 UserDefaults。
