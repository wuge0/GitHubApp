import SwiftUI

struct SettingsView: View {
    @AppStorage("gh_token") private var token: String = ""
    @State private var draft: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("粘贴 Personal Access Token", text: $draft)
                    Button("保存") {
                        token = draft
                    }
                    .disabled(draft.isEmpty)
                    if !token.isEmpty {
                        Button("清除已保存的 Token", role: .destructive) {
                            token = ""
                            draft = ""
                        }
                    }
                } header: {
                    Text("访问令牌")
                } footer: {
                    Text("填 Token 可把 API 限额从 60 次/小时提到 5000 次/小时，并能看私有仓库。不填也能搜公开仓库。")
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0").foregroundColor(.secondary)
                    }
                    Link("创建 Token", destination: URL(string: "https://github.com/settings/tokens")!)
                }
            }
            .navigationTitle("设置")
            .onAppear { draft = token }
        }
    }
}
