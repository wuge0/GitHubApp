import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
            TrendingView()
                .tabItem {
                    Label("趋势", systemImage: "chart.line.uptrend.xyaxis")
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
