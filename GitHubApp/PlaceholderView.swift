import SwiftUI

/// 统一的加载态 / 空态 / 错误态，替换掉此前散落在 6 个页面里的重复写法
struct LoadingView: View {
    var text: String = "加载中…"

    var body: some View {
        VStack { Spacer(); ProgressView(text); Spacer() }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

/// 列表底部的"加载更多"
struct MoreButton: View {
    let hasMore: Bool
    let loading: Bool
    let load: () -> Void

    var body: some View {
        Group {
            if hasMore {
                HStack {
                    Spacer()
                    if loading {
                        ProgressView()
                    } else {
                        Button("加载更多", action: load)
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }
}
