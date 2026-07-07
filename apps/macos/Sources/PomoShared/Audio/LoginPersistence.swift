import WebKit

/// On-disk backup of signed-in web-player cookies (YouTube/Google, SoundCloud).
///
/// WKWebView's default data store *does* persist cookies, but it keys storage by
/// the app's bundle id (so a dev build and the signed release don't share a
/// login) and it drops session-only cookies between launches. We sidestep both
/// by writing auth cookies to `~/Library/Application Support/Pomo/` and
/// re-injecting them on launch. Each service keeps its own jar so importing
/// YouTube does not wipe SoundCloud (and vice versa).
enum CookieJar {
    private static let supportDirectory: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pomo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
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

    private static func fileURL(for service: AuthService) -> URL {
        supportDirectory.appendingPathComponent(service.cookieFileName)
    }

    /// Persist the given cookies for one service. Written owner-only since these
    /// are login credentials.
    static func save(_ cookies: [HTTPCookie], for service: AuthService) {
        let stored = cookies.filter { service.matches(domain: $0.domain) }.map {
            Stored(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path,
                   expires: $0.expiresDate?.timeIntervalSince1970, secure: $0.isSecure,
                   httpOnly: $0.isHTTPOnly)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(stored) else { return }
        let url = fileURL(for: service)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Rebuild saved cookies for one service. Expired ones are dropped.
    static func load(for service: AuthService) -> [HTTPCookie] {
        if let cookies = load(from: fileURL(for: service)), !cookies.isEmpty {
            return cookies
        }
        if let legacy = service.legacyCookieFileName {
            return load(from: supportDirectory.appendingPathComponent(legacy)) ?? []
        }
        return []
    }

    static func loadAll() -> [HTTPCookie] {
        AuthService.allCases.flatMap { load(for: $0) }
    }

    private static func load(from url: URL) -> [HTTPCookie]? {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([Stored].self, from: data)
        else { return nil }
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

    static func service(for cookie: HTTPCookie) -> AuthService? {
        AuthService.allCases.first { $0.matches(domain: cookie.domain) }
    }
}

/// Thin `WKHTTPCookieStoreObserver` that forwards change notifications to a
/// closure (callbacks arrive on the main thread).
final class CookieStoreObserver: NSObject, WKHTTPCookieStoreObserver {
    private let onChange: () -> Void
    init(_ onChange: @escaping () -> Void) { self.onChange = onChange }
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) { onChange() }
}