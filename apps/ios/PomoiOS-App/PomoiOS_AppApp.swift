import SwiftUI

@main
struct PomoiOS_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timerManager = TimerManager()
    @StateObject private var statsManager = StatsManager()
    @StateObject private var photoFaceStore = PhotoFaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(statsManager)
                .environmentObject(photoFaceStore)
        }
        .onChange(of: scenePhase) { _, phase in
            timerManager.handleScenePhase(phase)
        }
    }
}
