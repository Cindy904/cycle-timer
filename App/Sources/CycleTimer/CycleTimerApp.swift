import SwiftUI

@main
struct CycleTimerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var timerRoute: TimerRoute?
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            HomeView(showTimer: { project in
                timerRoute = TimerRoute(project: project)
            })
                .tabItem { Label("项目", systemImage: "square.stack.3d.up.fill") }
            HistoryView()
                .tabItem { Label("记录", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(VisualStyle.oliveDark)
        .toolbarBackground(VisualStyle.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onReceive(ticker) { _ in store.refresh() }
        .fullScreenCover(item: $timerRoute) { route in
            TimerScreen(startingProject: route.project, close: {
                timerRoute = nil
            })
                .environmentObject(store)
        }
        .alert("提示", isPresented: Binding(
            get: { store.notice != nil },
            set: { if !$0 { store.notice = nil } }
        )) {
            Button("知道了", role: .cancel) { store.notice = nil }
        } message: {
            Text(store.notice ?? "")
        }
    }
}

private struct TimerRoute: Identifiable {
    let id = UUID()
    let project: TimerProject?
}

#Preview("循环计时") {
    RootView()
        .environmentObject(AppStore())
        .preferredColorScheme(.light)
}
