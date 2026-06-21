import Foundation

/// Clock formatting helpers shared by watchfaces and the menu-bar title.
enum TimeFormat {
    /// `MM:SS`, or `H:MM:SS` once the duration crosses an hour.
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let secs = total % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
