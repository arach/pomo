import SwiftUI

@main
struct PomoiOS_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timerManager: TimerManager
    @StateObject private var watchSessionController: WatchSessionController
    @StateObject private var statsManager = StatsManager()
    @StateObject private var photoFaceStore = PhotoFaceStore()

    init() {
        let timerManager = TimerManager()
        _timerManager = StateObject(wrappedValue: timerManager)
        _watchSessionController = StateObject(
            wrappedValue: WatchSessionController(timerManager: timerManager)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(statsManager)
                .environmentObject(photoFaceStore)
        }
        .onChange(of: scenePhase) { _, phase in
            timerManager.handleScenePhase(phase)
            if phase == .active {
                watchSessionController.publishCurrentState()
            }
        }
    }
}
