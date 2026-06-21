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
    /// Extract YouTube/Google cookies from the named browser (nil = all detected),
    /// optionally from a specific Chromium profile (e.g. "Profile 1").
    static func cookies(fromBrowser browser: String?, profile: String?) async -> [HTTPCookie] {
        guard let bin = helperPath() else { return [] }
        var args: [String] = []
        if let browser, !browser.isEmpty { args.append(browser) }
        if let profile, !profile.isEmpty { args.append(profile) }
        guard let output = await run(bin, args) else { return [] }
        return parse(output)
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

    private static func parse(_ text: String) -> [HTTPCookie] {
        var cookies: [HTTPCookie] = []
        for rawLine in text.split(separator: "\n") {
            let fields = String(rawLine).components(separatedBy: "\t")
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
            if let expiry, expiry > 0 { props[.expires] = Date(timeIntervalSince1970: expiry) }
            if let cookie = HTTPCookie(properties: props) { cookies.append(cookie) }
        }
        return cookies
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
