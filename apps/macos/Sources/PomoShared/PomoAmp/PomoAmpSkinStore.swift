import Foundation

public enum PomoAmpSkinStore {
    static var skinsDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Skins", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func warmDefaultSkin() {
        installExampleSkinIfNeeded()
    }

    static func installedSkins() -> [PomoAmpSkin] {
        installExampleSkinIfNeeded()
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: skinsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return dirs.compactMap { directory in
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true
            else { return nil }
            return loadSkin(at: directory)
        }
        .filter { $0.manifest.supportsHTML }
        .sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    static func firstInstalledSkin() -> PomoAmpSkin? {
        installedSkins().first
    }

    private static func loadSkin(at directory: URL) -> PomoAmpSkin? {
        let manifestURL = directory.appendingPathComponent("skin.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PomoAmpSkinManifest.self, from: data),
              !manifest.id.isEmpty,
              !manifest.entry.isEmpty,
              FileManager.default.fileExists(atPath: directory.appendingPathComponent(manifest.entry).path)
        else { return nil }
        return PomoAmpSkin(manifest: manifest, directory: directory)
    }

    private static func installExampleSkinIfNeeded() {
        let directory = skinsDirectory.appendingPathComponent("hello-pomo-amp", isDirectory: true)
        let manifestURL = directory.appendingPathComponent("skin.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PomoAmpSkinManifest.self, from: data),
                  manifest.id == "hello-pomo-amp",
                  ["PomoAmp SDK", "Pomo Amp SDK"].contains(manifest.author),
                  manifest.version != exampleVersion
            else { return }
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? exampleManifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        installBundledDefaultSkin(to: directory)
    }

    private static func installBundledDefaultSkin(to directory: URL) {
        guard let sourceURL = Bundle.module.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "PomoAmpDefaultSkin"
        ) else {
            PomoAmpDebugLog.write("bundled default skin index.html missing")
            return
        }

        let targetURL = directory.appendingPathComponent("index.html")
        try? FileManager.default.removeItem(at: targetURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        } catch {
            PomoAmpDebugLog.write("failed to install bundled default skin: \(error)")
        }
    }

    private static let exampleVersion = "1.2.1"

    private static let exampleManifest = """
    {
      "id": "hello-pomo-amp",
      "name": "Pomo Amp Studio",
      "version": "\(exampleVersion)",
      "engine": "html@1",
      "entry": "index.html",
      "author": "Pomo Amp SDK",
      "size": { "width": 386, "height": 198 }
    }
    """

}
