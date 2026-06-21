import Foundation

/// The available watchfaces. v1 ships three distinctive looks; new faces slot
/// in here and in `WatchfaceView`'s switch.
enum Watchface: String, CaseIterable, Codable, Identifiable {
    case minimal
    case terminal
    case neon
    case retroDigital
    case rolodex
    case chronograph
    case blueprint

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal:      return "Minimal"
        case .terminal:     return "Terminal"
        case .neon:         return "Neon"
        case .retroDigital: return "Retro Digital"
        case .rolodex:      return "Rolodex"
        case .chronograph:  return "Chronograph"
        case .blueprint:    return "Blueprint"
        }
    }

    /// Next face in the cycle (for the `T` keyboard shortcut).
    var next: Watchface {
        let all = Watchface.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}
