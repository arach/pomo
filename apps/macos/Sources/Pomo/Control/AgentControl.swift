import Foundation

/// Commands an external agent can send via the `pomo://` URL scheme, e.g.
/// `open "pomo://start"`, `open "pomo://face/neon"`,
/// `open "pomo://audio?url=https://youtu.be/jfKfPfyJRdk"`.
enum PomoCommand {
    case start, pause, toggle, reset, skip
    case showHUD, hideHUD, toggleHUD
    case session(SessionType)
    case face(Watchface)
    case duration(Int)
    case audioPlay(String?)     // url to load, or nil to resume stored
    case audioPause
    case audioStop
    case audioVolume(Int)       // 0–100
    case audioNext
    case audioPrev
    case login
    case importCookies(browser: String?, profile: String?)
    case logout
    case selectAccount(Int)
    case videoShow
    case videoHide
    case videoToggle
    case videoBrowser           // open the current video in the default browser
    case favoriteAdd(url: String, title: String?)
    case favoritePlay(Int)      // 1-based
    case favoriteRemove(Int)    // 1-based
    case favoritesList
    case openMenu
    case openSettings
    case quit

    init?(url: URL) {
        guard url.scheme?.lowercased() == "pomo" else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = (comps?.host ?? url.host ?? "").lowercased()
        let path = (comps?.path ?? url.path)
            .split(separator: "/")
            .map { String($0).lowercased() }
        let arg = path.first
        let query = comps?.queryItems

        switch host {
        case "start":      self = .start
        case "pause":      self = .pause
        case "toggle":     self = .toggle
        case "reset":      self = .reset
        case "skip":       self = .skip
        case "show":       self = .showHUD
        case "hide":       self = .hideHUD
        case "toggle-hud", "togglehud", "hud": self = .toggleHUD
        case "menu":       self = .openMenu
        case "login":
            switch arg {
            case "import":
                self = .importCookies(
                    browser: query?.first(where: { $0.name == "browser" })?.value,
                    profile: query?.first(where: { $0.name == "profile" })?.value
                )
            case "account":
                guard path.count > 1, let index = Int(path[1]) else { return nil }
                self = .selectAccount(index)
            default:
                self = .login
            }
        case "logout":     self = .logout
        case "settings":   self = .openSettings
        case "quit":       self = .quit

        case "video":
            switch arg {
            case "show":   self = .videoShow
            case "hide":   self = .videoHide
            case "browser", "open": self = .videoBrowser
            case "toggle", nil: self = .videoToggle
            default: return nil
            }

        case "session":
            guard let arg, let type = SessionType(command: arg) else { return nil }
            self = .session(type)

        case "face":
            guard let arg, let face = Watchface(command: arg) else { return nil }
            self = .face(face)

        case "duration":
            guard let arg, let minutes = Int(arg) else { return nil }
            self = .duration(minutes)

        case "audio":
            if let urlValue = query?.first(where: { $0.name == "url" })?.value, !urlValue.isEmpty {
                self = .audioPlay(urlValue)
            } else {
                switch arg {
                case "play":  self = .audioPlay(nil)
                case "pause": self = .audioPause
                case "stop":  self = .audioStop
                case "next":  self = .audioNext
                case "prev", "previous": self = .audioPrev
                case "volume":
                    guard path.count > 1, let v = Int(path[1]) else { return nil }
                    self = .audioVolume(v)
                default: return nil
                }
            }

        case "volume":
            guard let arg, let v = Int(arg) else { return nil }
            self = .audioVolume(v)

        case "favorites":
            self = .favoritesList

        case "favorite":
            switch arg {
            case "add":
                guard let value = query?.first(where: { $0.name == "url" })?.value, !value.isEmpty else { return nil }
                let title = query?.first(where: { $0.name == "title" })?.value
                self = .favoriteAdd(url: value, title: title)
            case "play":
                guard path.count > 1, let index = Int(path[1]) else { return nil }
                self = .favoritePlay(index)
            case "remove":
                guard path.count > 1, let index = Int(path[1]) else { return nil }
                self = .favoriteRemove(index)
            default:
                return nil
            }

        default:
            return nil
        }
    }
}

extension SessionType {
    /// Lenient parse for agent commands ("focus", "short", "break", "long", …).
    init?(command: String) {
        switch command.lowercased() {
        case "focus", "work":               self = .focus
        case "short", "shortbreak", "break": self = .shortBreak
        case "long", "longbreak":           self = .longBreak
        default: return nil
        }
    }
}

extension Watchface {
    /// Lenient parse for agent commands (accepts "retro", "chrono", etc.).
    init?(command: String) {
        switch command.lowercased() {
        case "minimal", "min":                      self = .minimal
        case "terminal", "term":                    self = .terminal
        case "neon":                                self = .neon
        case "retro", "retrodigital", "retro-digital", "digital": self = .retroDigital
        case "rolodex", "flip":                     self = .rolodex
        case "chronograph", "chrono", "analog":     self = .chronograph
        case "blueprint", "blue", "draft", "engineering": self = .blueprint
        default:
            if let face = Watchface(rawValue: command) { self = face } else { return nil }
        }
    }
}

/// A snapshot of timer + audio state written to disk so agents can read status
/// (the URL scheme is fire-and-forget; this is the read-back channel).
struct PomoState: Codable {
    var phase: String
    var sessionType: String
    var remainingSeconds: Int
    var totalSeconds: Int
    var clock: String
    var progress: Double
    var completedFocusCount: Int
    var watchface: String
    var hudVisible: Bool
    var audioPlaying: Bool
    var audioURL: String
    var audioEngine: String   // "web" | "none"
    var favorites: [Favorite]

    static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Pomo/state.json")
    }()

    func write() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
