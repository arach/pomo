import SwiftUI

private enum AppTab: Int {
    case timer, stats, settings

    static var previewSelection: AppTab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-previewTab"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "stats": return .stats
            case "settings": return .settings
            default: break
            }
        }
        #endif
        return .timer
    }
}

struct ContentView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var statsManager: StatsManager
    @State private var selectedTab = AppTab.previewSelection

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(AppTab.timer)

            StatsView()
                .tabItem { Label("Activity", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.stats)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        .tint(PomoPalette.accent)
        .toolbarBackground(PomoPalette.elevated, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            timerManager.onSessionEnded = statsManager.addSession
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(StatsManager())
}
