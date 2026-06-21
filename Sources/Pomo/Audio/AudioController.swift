import Foundation
import Observation

/// Routes background-audio playback between two engines:
///
/// - **Native** (`yt-dlp` → AVPlayer): ad-free, headless, for single tracks,
///   curated favorites, and direct media files. Preferred when yt-dlp exists.
/// - **Webview** (`WebAudioPlayer`): for **playlists / radio**, where the
///   YouTube player's built-in autoplay + next-track is the whole point — a
///   single resolved URL can't advance on its own.
///
/// `@Observable` so SwiftUI surfaces (the menu-bar popover) reflect play state
/// live. Exposes the same surface AppDelegate used for the old web-only player.
@MainActor
@Observable
final class AudioController {
    private let native = NativeAudioPlayer()
    private let web = WebAudioPlayer()
    private let resolver = StreamResolver()

    private enum Engine { case none, native, web }
    @ObservationIgnored private var engine: Engine = .none
    @ObservationIgnored private var resolveToken = 0
    @ObservationIgnored private var volume: Double = 0.6

    /// Fired whenever playback state changes (including async, after a resolve)
    /// so the owner can refresh the state file.
    @ObservationIgnored var onStateChange: (() -> Void)?

    // Observable playback state.
    private(set) var isPlaying = false
    private(set) var engineName = "none"  // "native" | "web" | "none"
    private(set) var currentURL = ""

    var ytdlpAvailable: Bool { resolver.isAvailable }

    init() {
        // If native playback can't actually produce sound (YouTube 403/PoToken),
        // fall back to the webview so the user always hears audio.
        native.onFailure = { [weak self] in
            guard let self, self.engine == .native, !self.currentURL.isEmpty else { return }
            self.useWeb(self.currentURL)
        }
    }

    func setVolume(_ value: Double) {
        volume = value
        native.setVolume(value)
        web.setVolume(value)
    }

    func play(urlString raw: String) {
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        currentURL = url
        resolveToken += 1
        let token = resolveToken

        // Playlists / radio → webview (keeps native next-track + autoplay).
        if Self.isPlaylist(url) {
            useWeb(url)
            return
        }
        // Direct audio files → straight to AVPlayer.
        if Self.isDirectMedia(url) {
            web.stop()
            engine = .native
            native.play(directURL: url, volume: volume)
            notify()
            return
        }
        // Single track → yt-dlp (ad-free) when available, else webview.
        guard resolver.isAvailable else {
            useWeb(url)
            return
        }

        web.stop()
        engine = .native
        Task { [weak self] in
            guard let self else { return }
            let stream = await self.resolver.resolve(url)
            guard token == self.resolveToken else { return }   // superseded by a newer play()
            if let stream {
                self.native.play(directURL: stream, volume: self.volume)
                self.engine = .native
            } else {
                self.native.stop()
                self.useWeb(url)                                // yt-dlp failed → fall back
            }
            self.notify()
        }
    }

    func resume(stored: String) {
        if currentURL.isEmpty {
            play(urlString: stored)
            return
        }
        switch engine {
        case .native: native.resume()
        case .web:    web.resume(stored: stored)
        case .none:   play(urlString: currentURL)
        }
        notify()
    }

    func pause() {
        switch engine {
        case .native: native.pause()
        case .web:    web.pause()
        case .none:   break
        }
        notify()
    }

    func stop() {
        resolveToken += 1
        native.stop()
        web.stop()
        engine = .none
        currentURL = ""
        notify()
    }

    private func useWeb(_ url: String) {
        native.stop()
        engine = .web
        web.play(urlString: url)
        notify()
    }

    private func notify() {
        switch engine {
        case .native: isPlaying = native.isPlaying; engineName = "native"
        case .web:    isPlaying = web.isPlaying;    engineName = "web"
        case .none:   isPlaying = false;            engineName = "none"
        }
        onStateChange?()
    }

    // MARK: - Routing heuristics

    static func isPlaylist(_ string: String) -> Bool {
        guard let comps = URLComponents(string: string) else { return false }
        if comps.queryItems?.contains(where: { $0.name == "list" }) == true { return true }
        return comps.path.contains("/playlist")
    }

    static func isDirectMedia(_ string: String) -> Bool {
        let exts: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "opus", "ogg", "aiff"]
        guard let url = URL(string: string) else { return false }
        return exts.contains(url.pathExtension.lowercased())
    }
}
