import Foundation

/// Imports the user's existing YouTube login from a browser (with their
/// permission) so the web player is signed-in — Premium → ad-free — without a
/// fresh login.
///
/// Uses the bundled `pomo-cookies` helper (the Rust `rookie` crate), which reads
/// and decrypts the browser's cookie store. Chrome/Chromium triggers a Keychain
/// prompt ("… wants to use Chrome Safe Storage"); Safari needs Full Disk Access.
/// No yt-dlp, no playback-path dependency — invoked only on demand.
enum CookieImporter {
    struct BrowserProfile: Identifiable, Hashable {
        let browser: String
        let browserName: String
        let profile: String
        let profileName: String
        let note: String?

        var id: String { "\(browser):\(profile)" }
        var title: String { profileName.isEmpty ? profile : profileName }
        var subtitle: String { "\(browserName) · \(profile)" }
    }

    /// Extract auth cookies for the given service from the named browser
    /// (nil = all detected), optionally from a specific Chromium profile.
    static func cookies(
        fromBrowser browser: String?,
        profile: String?,
        service: AuthService = .youTube
    ) async -> [HTTPCookie] {
        guard let bin = helperPath() else { return [] }
        var args: [String] = []
        if let flag = service.cookieHelperFlag { args.append(flag) }
        if let browser, !browser.isEmpty { args.append(browser) }
        if let profile, !profile.isEmpty { args.append(profile) }
        guard let output = await run(bin, args) else { return [] }
        return parse(output, service: service)
    }

    /// Detected Chromium-family browser profiles, matching the CLI's picker.
    static func detectedProfiles() -> [BrowserProfile] {
        struct Source {
            let browser: String
            let name: String
            let base: String
            let note: String?
            let order: Int
        }

        let sources = [
            Source(browser: "chrome", name: "Chrome", base: "Google/Chrome", note: "Keychain prompt", order: 0),
            Source(browser: "edge", name: "Edge", base: "Microsoft Edge", note: nil, order: 1),
            Source(browser: "brave", name: "Brave", base: "BraveSoftware/Brave-Browser", note: "Keychain prompt", order: 2),
            Source(browser: "chromium", name: "Chromium", base: "Chromium", note: nil, order: 3),
        ]

        let home = FileManager.default.homeDirectoryForCurrentUser
        var profiles: [(source: Source, profile: BrowserProfile)] = []

        for source in sources {
            let localState = home
                .appendingPathComponent("Library/Application Support")
                .appendingPathComponent(source.base)
                .appendingPathComponent("Local State")
            guard let data = try? Data(contentsOf: localState),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profileRoot = json["profile"] as? [String: Any],
                  let cache = profileRoot["info_cache"] as? [String: Any]
            else { continue }

            for (dir, rawInfo) in cache {
                let info = rawInfo as? [String: Any]
                let name = (info?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                profiles.append((
                    source,
                    BrowserProfile(
                        browser: source.browser,
                        browserName: source.name,
                        profile: dir,
                        profileName: (name?.isEmpty == false) ? name! : dir,
                        note: source.note
                    )
                ))
            }
        }

        return profiles
            .sorted { lhs, rhs in
                if lhs.source.order != rhs.source.order { return lhs.source.order < rhs.source.order }
                return profileOrder(lhs.profile.profile) < profileOrder(rhs.profile.profile)
            }
            .map(\.profile)
    }

    /// The helper ships inside the app bundle (Contents/MacOS/pomo-cookies).
    private static func helperPath() -> String? {
        if let url = Bundle.main.url(forAuxiliaryExecutable: "pomo-cookies"),
           FileManager.default.isExecutableFile(atPath: url.path) {
            return url.path
        }
        return nil
    }

    // MARK: - Parse helper output (Netscape cookies.txt rows)

    private static func parse(_ text: String, service: AuthService) -> [HTTPCookie] {
        var cookies: [HTTPCookie] = []
        for rawLine in text.split(separator: "\n") {
            var line = String(rawLine)
            guard !line.isEmpty else { continue }
            var httpOnly = false
            if line.hasPrefix("#HttpOnly_") {
                httpOnly = true
                line.removeFirst("#HttpOnly_".count)
            } else if line.hasPrefix("#") {
                continue
            }

            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 7 else { continue }
            let domain = fields[0]
            let path = fields[2].isEmpty ? "/" : fields[2]
            let secure = fields[3].uppercased() == "TRUE"
            let expiry = Double(fields[4])
            let name = fields[5]
            let value = fields[6]
            guard !name.isEmpty else { continue }

            var props: [HTTPCookiePropertyKey: Any] = [
                .domain: domain, .path: path, .name: name, .value: value,
            ]
            if secure { props[.secure] = "TRUE" }
            if httpOnly { props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            if let expiry, expiry > 0 { props[.expires] = Date(timeIntervalSince1970: expiry) }
            if let cookie = HTTPCookie(properties: props),
               service.matches(domain: cookie.domain) {
                cookies.append(cookie)
            }
        }
        return cookies
    }

    private static func profileOrder(_ dir: String) -> (Int, Int, String) {
        if dir == "Default" { return (0, 0, dir) }
        if dir.hasPrefix("Profile ") {
            let suffix = dir.dropFirst("Profile ".count)
            if let number = Int(suffix) { return (1, number, dir) }
        }
        return (2, 0, dir)
    }

    // MARK: - Process

    private static func run(_ bin: String, _ args: [String]) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: bin)
                process.arguments = args
                let out = Pipe()
                process.standardOutput = out
                process.standardError = Pipe()
                do { try process.run() } catch { continuation.resume(returning: nil); return }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(data: data, encoding: .utf8)
                continuation.resume(returning: process.terminationStatus == 0 ? text : nil)
            }
        }
    }
}
