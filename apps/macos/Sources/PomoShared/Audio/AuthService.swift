import Foundation

/// A web login surface whose cookies we back up and re-inject across launches.
enum AuthService: String, CaseIterable {
    case youTube
    case soundCloud

    var displayName: String {
        switch self {
        case .youTube: return "YouTube"
        case .soundCloud: return "SoundCloud"
        }
    }

    /// On-disk filename under `~/Library/Application Support/Pomo/`.
    var cookieFileName: String {
        switch self {
        case .youTube: return "cookies-youtube.json"
        case .soundCloud: return "cookies-soundcloud.json"
        }
    }

    /// Legacy YouTube path written before service-specific jars existed.
    var legacyCookieFileName: String? {
        self == .youTube ? "cookies.json" : nil
    }

    var rootDomains: [String] {
        switch self {
        case .youTube: ["youtube.com", "google.com"]
        case .soundCloud: ["soundcloud.com"]
        }
    }

    var defaultContinueURL: URL {
        switch self {
        case .youTube: URL(string: "https://www.youtube.com/")!
        case .soundCloud: URL(string: "https://soundcloud.com/")!
        }
    }

    func matches(domain: String) -> Bool {
        let normalized = domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return rootDomains.contains { root in
            normalized == root || normalized.hasSuffix(".\(root)")
        }
    }

    var cookieHelperFlag: String? {
        self == .soundCloud ? "--soundcloud" : nil
    }
}