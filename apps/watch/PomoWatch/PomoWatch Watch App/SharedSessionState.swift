import Foundation

struct SharedSessionState: Codable, Equatable {
    let mode: String
    let intent: String
    let duration: TimeInterval
    let remaining: TimeInterval
    let endDate: Date?
    let isRunning: Bool
    let completedFocusBlocks: Int
    let updatedAt: Date
    let outcome: SharedSessionOutcome?
}

struct SharedSessionOutcome: Codable, Equatable {
    let mode: String
    let duration: TimeInterval
    let intent: String?
    let completedAt: Date
    let nextMode: String
    let nextDuration: TimeInterval
    let cadenceFilled: Int
    let closedCadenceSet: Bool
    let autoStartedNext: Bool
}

enum SharedSessionCommand: String {
    case start
    case pause
    case reset
    case skip
    case continueNext
    case dismissOutcome
    case requestState
}
