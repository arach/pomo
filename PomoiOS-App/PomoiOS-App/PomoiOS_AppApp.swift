import SwiftUI

@main
struct PomoiOS_AppApp: App {
    @StateObject private var timerManager = TimerManager()
    @StateObject private var statsManager = StatsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(statsManager)
        }
    }
}
