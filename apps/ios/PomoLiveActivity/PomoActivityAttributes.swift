import ActivityKit
import Foundation

struct PomoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endDate: Date
        let remainingSeconds: Int
        let isPaused: Bool
        let intent: String
    }

    let modeName: String
    let totalSeconds: Int
    let accentHex: UInt32
}
