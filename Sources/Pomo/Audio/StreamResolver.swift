import Foundation

/// Resolves a direct, playable audio stream URL from a page URL (YouTube, etc.)
/// by shelling out to the `yt-dlp` binary — `-f bestaudio/best -g`. This is what
/// lets us play ad-free, headless audio through AVPlayer instead of an embed.
///
/// Resolved googlevideo URLs are time-limited (~hours), so callers resolve on
/// each play rather than caching the URL.
final class StreamResolver {
    let binaryPath: String?

    init() { binaryPath = Self.find() }

    var isAvailable: Bool { binaryPath != nil }

    /// Returns the first stream URL `yt-dlp` prints, or nil on any failure.
    func resolve(_ url: String) async -> String? {
        guard let bin = binaryPath else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: bin)
                process.arguments = ["-q", "--no-warnings", "--no-playlist", "-f", "bestaudio/best", "-g", url]
                // Apps launched via LaunchServices get a bare PATH; yt-dlp's
                // `env python3` shebang + ffmpeg need the usual bin dirs.
                var env = ProcessInfo.processInfo.environment
                let home = NSHomeDirectory()
                let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
                             "\(home)/.local/bin"]
                env["PATH"] = (extra + [env["PATH"] ?? ""]).joined(separator: ":")
                process.environment = env
                let out = Pipe()
                process.standardOutput = out
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0,
                      let text = String(data: data, encoding: .utf8)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let first = text.split(separator: "\n").first
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (first?.isEmpty == false) ? first : nil)
            }
        }
    }

    // MARK: - Locating yt-dlp

    private static func find() -> String? {
        let fm = FileManager.default
        var candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/yt-dlp").path,
        ]
        // ~/Library/Python/<ver>/bin/yt-dlp (pip --user installs)
        let pyBase = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Python")
        if let versions = try? fm.contentsOfDirectory(atPath: pyBase.path) {
            for version in versions {
                candidates.append(pyBase.appendingPathComponent("\(version)/bin/yt-dlp").path)
            }
        }
        for path in candidates where fm.isExecutableFile(atPath: path) { return path }
        return whichViaLoginShell()
    }

    /// Last resort: ask a login shell (so the user's PATH is honoured).
    private static func whichViaLoginShell() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v yt-dlp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) { return path }
        return nil
    }
}
