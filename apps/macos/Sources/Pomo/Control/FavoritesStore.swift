import Foundation
import Observation

/// Persisted favorites cache, stored as JSON in
/// `~/Library/Application Support/Pomo/favorites.json`. Kept separate from
/// `PomoSettings` so it can grow (tags, ordering, …) without churn there.
///
/// `@Observable` so the popover's favorites list updates live. Public indices
/// are **1-based** to match the `pomoctl fav play <n>` CLI.
@MainActor
@Observable
final class FavoritesStore {
    private(set) var items: [Favorite] = []

    init() { load() }

    @discardableResult
    func add(url rawURL: String, title rawTitle: String?) -> Bool {
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return false }
        guard !items.contains(where: { $0.url == url }) else { return false } // dedupe
        let title = (rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? Self.defaultTitle(for: url)
        items.append(Favorite(title: title, url: url))
        save()
        return true
    }

    /// 1-based remove.
    func remove(at index: Int) {
        let i = index - 1
        guard items.indices.contains(i) else { return }
        items.remove(at: i)
        save()
    }

    /// 1-based lookup.
    func item(at index: Int) -> Favorite? {
        let i = index - 1
        return items.indices.contains(i) ? items[i] : nil
    }

    // MARK: - Persistence

    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pomo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("favorites.json")
    }()

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// A readable fallback title from the URL (YouTube id, or host).
    private static func defaultTitle(for url: String) -> String {
        if let id = WebAudioPlayer.youTubeID(from: url) { return "YouTube · \(id)" }
        if let host = URLComponents(string: url)?.host { return host }
        return url
    }
}
