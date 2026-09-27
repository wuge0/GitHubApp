import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ExploreView()
                .tabItem {
                    Label("探索", systemImage: "safari")
                }
            DynamicView()
                .tabItem {
                    Label("动态", systemImage: "bell")
                }
            MeView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}
