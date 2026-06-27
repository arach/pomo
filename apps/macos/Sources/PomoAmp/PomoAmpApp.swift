import SwiftUI
import PomoShared

/// Pomo Amp — a tiny native YouTube music deck with swappable faces.
@main
struct PomoAmpApp: App {
    @NSApplicationDelegateAdaptor(PomoAmpAppDelegate.self) private var delegate

    init() {
        PomoAmpSkinStore.warmDefaultSkin()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
