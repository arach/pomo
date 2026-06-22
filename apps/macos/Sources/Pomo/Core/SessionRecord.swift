import Foundation

/// One completed timer session, persisted to build the focus history / stats.
/// Kept deliberately small and forward-compatible — new optional fields can be
/// added without invalidating older `history.json` files.
struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID
    /// `SessionType.rawValue` of the interval that finished.
    var type: String
    var completedAt: Date
    /// The configured length of the finished session, in seconds.
    var durationSeconds: Int
    /// The focus intent in effect when the session finished, if any.
    var intent: String?

    init(
        id: UUID = UUID(),
        type: SessionType,
        completedAt: Date,
        durationSeconds: Int,
        intent: String?
    ) {
        self.id = id
        self.type = type.rawValue
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        let trimmed = intent?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.intent = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    var sessionType: SessionType? { SessionType(rawValue: type) }
    var isFocus: Bool { type == SessionType.focus.rawValue }
}
