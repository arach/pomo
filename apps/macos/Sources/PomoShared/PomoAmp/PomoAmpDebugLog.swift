import Foundation

enum PomoAmpDebugLog {
    static func write(_ message: String) {
        let line = "[\(timestamp())] \(message)\n"
        print(line, terminator: "")
        guard let data = line.data(using: .utf8) else { return }

        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
        let url = directory.appendingPathComponent("pomo-amp-debug.log")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            print("[PomoAmpLog] failed to append debug log: \(error)")
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
