import Foundation
import Observation

/// Background audio — **browser only**. Everything (YouTube, YouTube Music,
/// direct media URLs, pages) plays through `WebAudioPlayer`'s mini-player. No
/// yt-dlp, no native AVPlayer: the webview is the one engine, and signing in
/// (Premium) makes it ad-free.
///
/// `@Observable` so the menu-bar popover reflects play state live.
@MainActor
@Observable
final class AudioController {
    private let web = WebAudioPlayer()

    @ObservationIgnored var onStateChange: (() -> Void)?

    private(set) var isPlaying = false
    private(set) var engineName = "none"   // "web" | "none" (kept in state.json)
    private(set) var currentURL = ""

    var videoVisible: Bool { web.isWindowVisible }

    init() {
        web.onStateChange = { [weak self] in self?.notify() }
    }

    func setVolume(_ value: Double) { web.setVolume(value) }

    func play(urlString raw: String) { web.play(urlString: raw); notify() }
    func resume(stored: String) { web.resume(stored: stored); notify() }
    func pause() { web.pause(); notify() }
    func stop() { web.stop(); notify() }

    func next() { web.next() }
    func previous() { web.previous() }
    func signIn() { web.signIn() }
    func importCookies(browser: String?, profile: String?) { web.importCookies(fromBrowser: browser, profile: profile) }
    func clearLogin() { web.clearLogin() }
    func setAccount(_ index: Int) { web.setAccount(index) }
    func setVideoVisible(_ visible: Bool) { web.setWindowVisible(visible) }
    func toggleVideo() { web.toggleWindow() }

    private func notify() {
        isPlaying = web.isPlaying
        currentURL = web.currentURL
        engineName = web.isPlaying ? "web" : "none"
        onStateChange?()
    }
}
