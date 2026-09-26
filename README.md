# GitHub 手机版（iOS，SwiftUI）

一个原生 iOS 的 GitHub 客户端，用 SwiftUI + GitHub REST API 写成，通过 GitHub Actions 无签名构建 IPA，供 TrollStore / 越狱设备侧载。

## 功能

- **搜索仓库**：关键词搜索，按 star 排序，显示 owner 头像、描述、star / fork / 语言
- **仓库详情**：基本信息（star / fork / open issues）、README 全文（base64 解码）、可在 Safari 打开
- **最近 Issue**：列出该仓库最近 20 条 issue / PR，区分 open（绿）与 closed（紫）
- **设置**：粘贴 GitHub Personal Access Token（可选）
  - 不填：匿名访问公开数据，限额 **60 次/小时**
  - 填上：限额 **5000 次/小时**，且可访问私有仓库

## 工程结构

```
GitHubApp.xcodeproj/                 Xcode 工程 + 共享 scheme
GitHubApp/
  GitHubAppApp.swift                 @main 入口
  ContentView.swift                  TabView 根容器（仓库 / 设置）
  Models.swift                       Repo / Issue / Owner 等 Codable 模型
  GitHubAPI.swift                    网络层：搜索、issues、readme
  SearchView.swift                   搜索页 + 仓库行
  RepoDetailView.swift               仓库详情（README + Issues）
  SettingsView.swift                 Token 设置
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
- README 以等宽字体原样展示（未做 Markdown 富文本渲染）。
- 应用未配置图标（无 Assets.xcassets），装上后是默认空白图标。
