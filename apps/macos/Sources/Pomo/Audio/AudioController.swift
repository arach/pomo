import AppKit
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

    /// Whether the video drawer is open. Stored (not computed) so the on-face
    /// buttons observe it and re-render when it toggles.
    private(set) var videoOpen = false

    /// Edge the drawer is docked to — the HUD reads this to square the matching
    /// corners so the two read as one block.
    private(set) var videoEdge: DrawerEdge = .right

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
    func setVideoVisible(_ visible: Bool) { web.setWindowVisible(visible); syncVideo(); notify() }
    func toggleVideo() { web.toggleWindow(); syncVideo(); notify() }

    /// Wire the drawer to the HUD panel when it appears / detach when it hides.
    func attachDrawer(to anchor: NSWindow?) { web.hudDidAppear(anchor: anchor); syncVideo() }
    func detachDrawer() { web.hudWillDisappear() }

    private func syncVideo() {
        videoOpen = web.isWindowVisible
        videoEdge = web.drawerEdge
    }

    private func notify() {
        isPlaying = web.isPlaying
        currentURL = web.currentURL
        engineName = web.isPlaying ? "web" : "none"
        onStateChange?()
    }
}
