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
    @ObservationIgnored var onChange: (() -> Void)?

    init() { load() }

    @discardableResult
    func add(url rawURL: String, title rawTitle: String?) -> Bool {
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return false }
        guard !items.contains(where: { $0.url == url }) else { return false } // dedupe
        let title = (rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? Self.defaultTitle(for: url)
        items.append(Favorite(title: title, url: url))
        saveAndNotify()
        return true
    }

    /// 1-based remove.
    func remove(at index: Int) {
        let i = index - 1
        guard items.indices.contains(i) else { return }
        items.remove(at: i)
        saveAndNotify()
    }

    @discardableResult
    func update(at index: Int, title rawTitle: String?, url rawURL: String?) -> Bool {
        let i = index - 1
        guard items.indices.contains(i) else { return false }

        var item = items[i]
        if let rawTitle {
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            item.title = title.isEmpty ? Self.defaultTitle(for: item.url) : title
        }
        if let rawURL {
            let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return false }
            guard !items.enumerated().contains(where: { $0.offset != i && $0.element.url == url }) else { return false }
            item.url = url
            if rawTitle == nil {
                item.title = Self.defaultTitle(for: url)
            }
        }

        items[i] = item
        saveAndNotify()
        return true
    }

    @discardableResult
    func move(from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        let source = sourceIndex - 1
        guard items.indices.contains(source) else { return false }
        let destination = max(0, min(destinationIndex - 1, items.count - 1))
        guard source != destination else { return true }

        let item = items.remove(at: source)
        items.insert(item, at: min(destination, items.count))
        saveAndNotify()
        return true
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let indexes = source.filter { items.indices.contains($0) }.sorted()
        guard !indexes.isEmpty else { return }
        let moving = indexes.map { items[$0] }
        for index in indexes.reversed() {
            items.remove(at: index)
        }
        let removedBeforeDestination = indexes.filter { $0 < destination }.count
        let adjustedDestination = max(0, min(destination - removedBeforeDestination, items.count))
        items.insert(contentsOf: moving, at: adjustedDestination)
        saveAndNotify()
    }

    func replace(with newItems: [Favorite]) {
        var seen = Set<String>()
        items = newItems.compactMap { item in
            let url = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty, seen.insert(url).inserted else { return nil }
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Favorite(title: title.isEmpty ? Self.defaultTitle(for: url) : title, url: url)
        }
        saveAndNotify()
    }

    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        saveAndNotify()
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

    private static let defaultItems = [
        Favorite(title: "lofi girl", url: "https://www.youtube.com/watch?v=jfKfPfyJRdk")
    ]

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else {
            items = Self.defaultItems
            save()
            return
        }
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

    private func saveAndNotify() {
        save()
        onChange?()
    }

    /// A readable fallback title from the URL (source label, or host).
    private static func defaultTitle(for url: String) -> String {
        PlaybackSource.shortLabel(for: url)
    }
}
