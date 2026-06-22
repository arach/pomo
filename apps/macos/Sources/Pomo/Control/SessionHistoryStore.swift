import Foundation
import Observation

/// One day in the focus heatmap: a calendar day plus the number of focus
/// sessions that landed on it.
struct DayCount: Identifiable, Equatable {
    let date: Date      // start of day
    let count: Int
    var id: Date { date }
}

/// Persisted log of completed sessions, stored as JSON in
/// `~/Library/Application Support/Pomo/history.json`. Mirrors `FavoritesStore`'s
/// simple file-backed pattern, kept separate from `PomoSettings` so the log can
/// grow without churn there. `@Observable` so the Stats window updates live.
///
/// All derived stats consider **focus** sessions only — breaks aren't "score".
@MainActor
@Observable
final class SessionHistoryStore {
    private(set) var records: [SessionRecord] = []

    init() { load() }

    /// Append a completed session and persist.
    func record(_ record: SessionRecord) {
        records.append(record)
        save()
    }

    /// Forget everything (a "Clear history" affordance in the Stats window).
    func clear() {
        records.removeAll()
        save()
    }

    // MARK: - Derived stats (focus sessions only)

    private var focusRecords: [SessionRecord] { records.filter(\.isFocus) }

    var totalFocusCount: Int { focusRecords.count }

    /// Focus sessions completed today.
    func focusCountToday(calendar: Calendar = .current, now: Date = Date()) -> Int {
        focusRecords.filter { calendar.isDate($0.completedAt, inSameDayAs: now) }.count
    }

    /// Focus sessions completed in the current calendar week.
    func focusCountThisWeek(calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return focusRecords.filter { week.contains($0.completedAt) }.count
    }

    /// Seconds of focus time logged in the current calendar week.
    func focusSecondsThisWeek(calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return focusRecords
            .filter { week.contains($0.completedAt) }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    /// Consecutive days (ending today, or yesterday if today is still empty) on
    /// which at least one focus session was completed.
    func currentStreak(calendar: Calendar = .current, now: Date = Date()) -> Int {
        let days = Set(focusRecords.map { calendar.startOfDay(for: $0.completedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        // An empty "today so far" shouldn't break a streak built through yesterday.
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// A `weeks`-column heatmap (each column 7 days, Sun→Sat top to bottom)
    /// ending on the week that contains `now`. Newest week is last; the final
    /// populated cell is today.
    func heatmap(weeks: Int = 17, calendar: Calendar = .current, now: Date = Date()) -> [[DayCount]] {
        let counts = countsByDay(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        guard
            let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
            let firstColumnStart = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: weekStart)
        else { return [] }

        var columns: [[DayCount]] = []
        for w in 0..<weeks {
            var column: [DayCount] = []
            for d in 0..<7 {
                let offset = w * 7 + d
                guard let date = calendar.date(byAdding: .day, value: offset, to: firstColumnStart) else { continue }
                column.append(DayCount(date: date, count: counts[date] ?? 0))
            }
            columns.append(column)
        }
        return columns
    }

    private func countsByDay(calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for record in focusRecords {
            let day = calendar.startOfDay(for: record.completedAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    // MARK: - Persistence

    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pomo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([SessionRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
