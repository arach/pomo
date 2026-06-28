import WebKit

/// On-disk backup of the YouTube/Google login cookies.
///
/// WKWebView's default data store *does* persist cookies, but it keys storage by
/// the app's bundle id (so a dev build and the signed release don't share a
/// login) and it drops session-only cookies between launches. We sidestep both
/// by writing the auth cookies to `~/Library/Application Support/Pomo/cookies.json`
/// — a path shared by every build — and re-injecting them on launch. Login is
/// left on the drive and reloaded next time, exactly once per change.
enum CookieJar {
    /// Shared across bundle ids (the "Pomo" support dir is not id-scoped), so a
    /// login made in any build is visible to the others.
    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pomo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cookies.json")
    }()

    /// The subset of an `HTTPCookie` we need to rebuild it on the next launch.
    private struct Stored: Codable {
        let name: String
        let value: String
        let domain: String
        let path: String
        let expires: Double?   // seconds since 1970; nil = session cookie
        let secure: Bool
        let httpOnly: Bool
    }

    /// Persist the given cookies (caller filters to the auth domains). Written
    /// owner-only since these are login credentials.
    static func save(_ cookies: [HTTPCookie]) {
        let stored = cookies.filter { isAllowedDomain($0.domain) }.map {
            Stored(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path,
                   expires: $0.expiresDate?.timeIntervalSince1970, secure: $0.isSecure,
                   httpOnly: $0.isHTTPOnly)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// Rebuild the saved cookies for re-injection. Expired ones are dropped.
    static func load() -> [HTTPCookie] {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([Stored].self, from: data)
        else { return [] }
        let now = Date()
        return stored.compactMap { s in
            if let e = s.expires, Date(timeIntervalSince1970: e) < now { return nil }
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: s.name, .value: s.value, .domain: s.domain, .path: s.path,
            ]
            if let e = s.expires { props[.expires] = Date(timeIntervalSince1970: e) }
            if s.secure { props[.secure] = "TRUE" }
            if s.httpOnly { props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            return HTTPCookie(properties: props)
        }
    }

    private static func isAllowedDomain(_ domain: String) -> Bool {
        let d = domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return d == "youtube.com" || d.hasSuffix(".youtube.com")
            || d == "google.com" || d.hasSuffix(".google.com")
    }
}

/// Thin `WKHTTPCookieStoreObserver` that forwards change notifications to a
/// closure (callbacks arrive on the main thread).
final class CookieStoreObserver: NSObject, WKHTTPCookieStoreObserver {
    private let onChange: () -> Void
    init(_ onChange: @escaping () -> Void) { self.onChange = onChange }
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) { onChange() }
}
