import Foundation

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: String
    let duration: TimeInterval
    let completed: Bool
    let intent: String?

    init(
        id: UUID = UUID(),
        date: Date,
        mode: String,
        duration: TimeInterval,
        completed: Bool,
        intent: String? = nil
    ) {
        self.id = id
        self.date = date
        self.mode = mode
        self.duration = duration
        self.completed = completed
        self.intent = intent
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, mode, duration, completed, intent
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try values.decode(Date.self, forKey: .date)
        mode = try values.decode(String.self, forKey: .mode)
        duration = try values.decode(TimeInterval.self, forKey: .duration)
        completed = try values.decode(Bool.self, forKey: .completed)
        intent = try values.decodeIfPresent(String.self, forKey: .intent)
    }
}

struct DailyStats: Identifiable {
    var id: Date { date }
    let date: Date
    let sessions: Int
    let focusTime: TimeInterval
    let breaks: Int
}

@MainActor
final class StatsManager: ObservableObject {
    @Published private(set) var sessions: [SessionRecord] = []
    @Published private(set) var weeklyStats: [DailyStats] = []
    @Published private(set) var streakDays = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var totalSessions = 0
    @Published private(set) var averageSessionsPerDay: Double = 0
    @Published private(set) var totalFocusTime: TimeInterval = 0

    private let defaults = UserDefaults.standard
    private let sessionsKey = "sessionRecords"
    private let calendar = Calendar.current
    private let isPreview: Bool

    init() {
        #if DEBUG
        isPreview = ProcessInfo.processInfo.arguments.contains("-appStorePreview")
        #else
        isPreview = false
        #endif

        if isPreview {
            sessions = Self.previewSessions()
        } else {
            loadSessions()
        }
        calculateStats()
    }

    func addSession(
        mode: FocusMode,
        duration: TimeInterval,
        completed: Bool,
        intent: String?
    ) {
        sessions.append(
            SessionRecord(
                date: Date(),
                mode: mode.rawValue,
                duration: duration,
                completed: completed,
                intent: intent
            )
        )
        if !isPreview { saveSessions() }
        calculateStats()
    }

    var todaySessions: Int {
        completedFocusSessions.filter { calendar.isDateInToday($0.date) }.count
    }

    var todayFocusTime: TimeInterval {
        completedFocusSessions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.duration }
    }

    var recentFocusSessions: [SessionRecord] {
        Array(completedFocusSessions.sorted { $0.date > $1.date }.prefix(8))
    }

    func activity(days: Int) -> [DailyStats] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return stats(for: date)
        }
    }

    func clearAllData() {
        sessions = []
        if !isPreview { saveSessions() }
        calculateStats()
    }

    private var completedFocusSessions: [SessionRecord] {
        sessions.filter { $0.completed && $0.mode == FocusMode.deepFocus.rawValue }
    }

    private func loadSessions() {
        guard let data = defaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else { return }
        sessions = decoded
    }

    private func saveSessions() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(encoded, forKey: sessionsKey)
    }

    private func calculateStats() {
        weeklyStats = activity(days: 7)

        let focus = completedFocusSessions
        totalSessions = focus.count
        totalFocusTime = focus.reduce(0) { $0 + $1.duration }

        let activeDays = Set(focus.map { calendar.startOfDay(for: $0.date) })
        averageSessionsPerDay = activeDays.isEmpty ? 0 : Double(totalSessions) / Double(activeDays.count)
        calculateStreaks(activeDays: activeDays)
    }

    private func stats(for date: Date) -> DailyStats {
        let daySessions = sessions.filter { $0.completed && calendar.isDate($0.date, inSameDayAs: date) }
        let focus = daySessions.filter { $0.mode == FocusMode.deepFocus.rawValue }
        return DailyStats(
            date: date,
            sessions: focus.count,
            focusTime: focus.reduce(0) { $0 + $1.duration },
            breaks: daySessions.count - focus.count
        )
    }

    private func calculateStreaks(activeDays: Set<Date>) {
        guard !activeDays.isEmpty else {
            streakDays = 0
            bestStreak = 0
            return
        }

        let sortedDays = activeDays.sorted()
        var run = 0
        var best = 0
        var previous: Date?
        for day in sortedDays {
            if let previous,
               calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        bestStreak = best

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard activeDays.contains(today) || activeDays.contains(yesterday) else {
            streakDays = 0
            return
        }

        var cursor = activeDays.contains(today) ? today : yesterday
        var current = 0
        while activeDays.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        streakDays = current
    }

    private static func previewSessions() -> [SessionRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let counts = [3, 5, 2, 4, 6, 1, 3, 4, 0, 5, 4, 2, 6, 3]
        let intents = [
            "Design the submission flow",
            "Polish the timer face",
            "Write App Store copy",
            "Fix the last build warning"
        ]
        var records: [SessionRecord] = []

        for (dayOffset, count) in counts.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: dayOffset - counts.count + 1, to: today) else { continue }
            for sessionIndex in 0..<count {
                let date = calendar.date(byAdding: .hour, value: 9 + sessionIndex, to: day) ?? day
                records.append(
                    SessionRecord(
                        date: date,
                        mode: FocusMode.deepFocus.rawValue,
                        duration: 25 * 60,
                        completed: true,
                        intent: intents[(dayOffset + sessionIndex) % intents.count]
                    )
                )
            }
        }
        return records
    }
}
