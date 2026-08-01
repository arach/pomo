import Foundation
import os

/// Commands an external agent can send via the `pomo://` URL scheme, e.g.
/// `open "pomo://start"`, `open "pomo://face/neon"`,
/// `open "pomo://audio?url=https://youtu.be/jfKfPfyJRdk"`.
enum PomoCommand {
    case start, pause, toggle, reset, skip
    case showHUD, hideHUD, toggleHUD
    case hudTiny(Bool?)        // nil toggles tiny/full; true = tiny; false = full
    case session(SessionType)
    case face(Watchface)
    case duration(Int)
    case audioPlay(String?)     // url to load, or nil to resume stored
    case audioPause
    case audioStop
    case audioVolume(Int)       // 0–100
    case audioNext
    case audioPrev
    case sessionAudio(SessionType, String?)
    case login
    case importCookies(browser: String?, profile: String?, accountIndex: Int)
    case logout
    case selectAccount(Int)
    case videoShow
    case videoHide
    case videoToggle
    case videoPage              // show the original YouTube page in the drawer
    case videoPlayer            // return to the stripped player view
    case videoBrowser           // open the current video in the default browser
    case favoriteAdd(url: String, title: String?)
    case favoriteUpdate(index: Int, title: String?, url: String?)
    case favoriteMove(from: Int, to: Int)
    case favoriteSet([Favorite])
    case favoriteClear
    case favoritePlay(Int)      // 1-based
    case favoriteRemove(Int)    // 1-based
    case favoritesList
    case setIntent(String)      // set the current session's focus intent ("" clears)
    case shortcuts(Bool?)       // keyboard cheat sheet: nil = toggle, true/false = show/hide
    case openStats
    case openMenu
    case openSettings
    case quit

    init?(url: URL, allowedSchemes: Set<String> = ["pomo"]) {
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme)
        else { return nil }
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
        case "tiny", "tiny-hud", "mini", "mini-hud": self = .hudTiny(true)
        case "full", "full-hud", "big-hud": self = .hudTiny(false)
        case "toggle-hud", "togglehud": self = .toggleHUD
        case "hud":
            switch arg {
            case "tiny", "mini", "small": self = .hudTiny(true)
            case "full", "normal", "large": self = .hudTiny(false)
            case "mode", "size": self = .hudTiny(nil)
            case "toggle", nil: self = .toggleHUD
            default: return nil
            }
        case "menu":       self = .openMenu
        case "shortcuts", "help", "keys":
            switch arg {
            case "show":            self = .shortcuts(true)
            case "hide":            self = .shortcuts(false)
            case "toggle", nil:     self = .shortcuts(nil)
            default:                return nil
            }
        case "login":
            switch arg {
            case "import":
                let accountValue = query?.first(where: { ["account", "authuser", "authUser"].contains($0.name) })?.value
                self = .importCookies(
                    browser: query?.first(where: { $0.name == "browser" })?.value,
                    profile: query?.first(where: { $0.name == "profile" })?.value,
                    accountIndex: max(0, Int(accountValue ?? "") ?? 0)
                )
            case "account":
                guard path.count > 1, let index = Int(path[1]) else { return nil }
                self = .selectAccount(index)
            default:
                self = .login
            }
        case "logout":     self = .logout
        case "settings":   self = .openSettings
        case "stats":      self = .openStats
        case "quit":       self = .quit

        case "intent":
            if let text = query?.first(where: { $0.name == "text" })?.value {
                self = .setIntent(text)
            } else if arg == "clear" {
                self = .setIntent("")
            } else {
                return nil
            }

        case "video":
            switch arg {
            case "show":   self = .videoShow
            case "hide":   self = .videoHide
            case "page", "full", "original", "expand": self = .videoPage
            case "player", "bare", "screen", "collapse": self = .videoPlayer
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
            if arg == "session" {
                guard path.count > 1, let type = SessionType(command: path[1]) else { return nil }
                if path.dropFirst(2).contains("clear") {
                    self = .sessionAudio(type, nil)
                } else {
                    let urlValue = query?.first(where: { $0.name == "url" })?.value?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    self = .sessionAudio(type, (urlValue?.isEmpty == false) ? urlValue : nil)
                }
            } else if let urlValue = query?.first(where: { $0.name == "url" })?.value, !urlValue.isEmpty {
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
            case "update", "edit", "rename":
                guard path.count > 1, let index = Int(path[1]) else { return nil }
                let title = query?.first(where: { $0.name == "title" })?.value
                let url = query?.first(where: { $0.name == "url" })?.value
                guard title != nil || url != nil else { return nil }
                self = .favoriteUpdate(index: index, title: title, url: url)
            case "move":
                guard path.count > 2, let from = Int(path[1]), let to = Int(path[2]) else { return nil }
                self = .favoriteMove(from: from, to: to)
            case "set", "replace":
                guard let value = query?.first(where: { $0.name == "items" })?.value,
                      let data = value.data(using: .utf8),
                      let items = try? JSONDecoder().decode([Favorite].self, from: data)
                else { return nil }
                self = .favoriteSet(items)
            case "clear":
                self = .favoriteClear
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

extension Date {
    /// UTC ISO8601 with fractional seconds **and** the `Z` designator.
    ///
    /// `ISO8601Format(.iso8601(timeZone: .gmt, …))` emits UTC but omits the
    /// designator, leaving a bare timestamp that most parsers read as *local*
    /// time — hours off, which would silently break the freshness checks these
    /// timestamps exist for.
    var pomoAgentTimestamp: String { Self.pomoAgentFormatter.string(from: self) }

    private static let pomoAgentFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

/// Identity of the process that wrote a state snapshot.
///
/// Every Pomo bundle shares one `state.json` — `dev.pomo.hud.dev` (dev build),
/// `dev.pomo.hud` (release), legacy ids, and Pomo Amp — and the last writer wins.
/// Without this an agent cannot know *which* app it just observed, so nothing read
/// from the file is attributable while more than one instance is alive.
///
/// `bundlePath` and `launchId` are here because a bundle id is not an installation
/// identity: `/Applications/Pomo.app`, a mounted DMG, and a cached build can all
/// claim the same id. See `docs/agentic-play.md` (G1, G8).
struct PomoStateWriter: Codable {
    var bundleId: String
    var bundlePath: String      // canonical path of the running .app
    var appName: String
    var pid: Int32
    var launchId: String        // unique to this process lifetime
    var version: String

    /// Resolved once per process, so `launchId` *is* the launch identity.
    static let current: PomoStateWriter = {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return PomoStateWriter(
            bundleId: bundle.bundleIdentifier ?? "unknown",
            bundlePath: bundle.bundleURL.resolvingSymlinksInPath().path,
            appName: (info["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName,
            pid: ProcessInfo.processInfo.processIdentifier,
            launchId: UUID().uuidString,
            version: "\(short) (\(build))"
        )
    }()
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
    var intent: String
    var watchface: String
    var hudVisible: Bool
    var hudMode: String
    var audioPlaying: Bool
    var audioURL: String
    var audioEngine: String   // "web" | "none"
    /// Position last **reported by the player**, and when that report arrived
    /// (ISO8601; empty while the player has reported nothing for this track).
    ///
    /// `audioPlaying` alone cannot prove playback began — it stays true for a page
    /// that loads and then buffers forever. Proof is `audioPositionSeconds`
    /// strictly advancing across two samples *with* `audioPositionReportedAt`
    /// advancing too; a stalled player leaves the timestamp frozen. This is
    /// deliberately not the extrapolated `estimatedMediaTime(at:)`.
    var audioPositionSeconds: Double
    var audioPositionReportedAt: String
    /// The player's own paused flag, distinct from `audioPlaying` (Pomo's intent).
    /// A live stream reports `duration: Infinity` (written here as 0) and a
    /// position pinned near 0, so for live media the honest liveness signal is
    /// `audioPlayerPaused == false` with `audioPositionReportedAt` advancing.
    var audioPlayerPaused: Bool
    var audioDurationSeconds: Double
    var audioTitle: String
    var audioAccountStatus: String   // signedIn | signedOut | unknown
    var sessionAudioURLs: [String: String]
    var favorites: [Favorite]
    // Focus history (see SessionHistoryStore).
    var focusToday: Int
    var focusTotal: Int
    var streakDays: Int

    // Stamped by `write()`, never by callers — a snapshot that claims to be fresh
    // must be fresh. `seq` disambiguates writes that land in the same instant.
    var writer = PomoStateWriter.current
    var updatedAt = ""
    var seq = 0

    static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Pomo/state.json")
    }()

    /// Monotonic per process. A reader that sees `seq` stop advancing knows the
    /// writer stopped writing, even if wall-clock timestamps are equal or the
    /// system clock moves.
    private static let seqCounter = OSAllocatedUnfairLock(initialState: 0)

    private static func nextSeq() -> Int {
        seqCounter.withLock { value in
            value += 1
            return value
        }
    }

    func write() {
        var snapshot = self
        snapshot.writer = .current
        snapshot.updatedAt = Date().pomoAgentTimestamp
        snapshot.seq = Self.nextSeq()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
