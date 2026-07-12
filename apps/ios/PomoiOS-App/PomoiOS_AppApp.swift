import SwiftUI

@main
struct PomoiOS_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timerManager = TimerManager()
    @StateObject private var statsManager = StatsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(statsManager)
        }
        .onChange(of: scenePhase) { _, phase in
            timerManager.handleScenePhase(phase)
        }
    }
}
