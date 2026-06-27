import SwiftUI
import PomoShared

/// Pomo — a native macOS HUD Pomodoro timer.
///
/// Runs as a menu-bar accessory app; all UI (status item, floating HUD panel,
/// settings window) is managed by `AppDelegate` via AppKit. The `Settings` scene
/// is an empty placeholder so the app launches without opening a window.
@main
struct PomoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
