import SwiftUI

struct SettingsView: View {
    @ObservedObject private var auth = TokenStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("粘贴 Personal Access Token", text: $draft)
                    Button("保存到钥匙串") {
                        auth.save(draft)
                        draft = ""
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("访问令牌")
                } footer: {
                    Text("Token 存在系统钥匙串里（Keychain），不写进 UserDefaults。填了可把 API 限额从 60 次/小时提到 5000 次/小时，并能看私有仓库；不填也能搜公开仓库。")
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(version).foregroundColor(.secondary)
                    }
                    Link("创建 Token", destination: URL(string: "https://github.com/settings/tokens")!)
                }

                Section {
                    Button(role: .destructive) {
                        auth.clear()
                        dismiss()
                    } label: {
                        HStack { Spacer(); Text("退出登录"); Spacer() }
                    }
                    .disabled(auth.token.isEmpty)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { draft = "" }
        }
    }
}
