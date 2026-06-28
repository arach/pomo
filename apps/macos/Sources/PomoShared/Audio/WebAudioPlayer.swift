import WebKit
import AppKit
import CryptoKit
import SwiftUI

/// Plays YouTube / YouTube Music audio by driving the **real watch page's
/// `<video>` element** in a small on-screen "mini-player" window. The IFrame
/// embed is refused for embedding-restricted videos (error 150/152) and raw
/// streams are PoToken-gated (403), so the live page is the reliable path — and
/// once you sign in (Premium) it plays ad-free.
///
/// Cookies/login persist in the default (disk-backed) `WKWebsiteDataStore`, which
/// the sign-in window shares, so a one-time login sticks across launches.
/// Which edge of the HUD the drawer docks against (and slides out from).
enum DrawerEdge { case right, left, below, above }

@MainActor
final class WebAudioPlayer: NSObject {
    private static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    private static let blankPageURL = URL(string: "about:blank")!
    private static let idleBrowserMemoryPurgeDelay: TimeInterval = 30
    private static let defaultAudioScopeFrameIntervalMilliseconds = 100
    private static let webAudioScopeFreshnessSeconds = 0.9
    private static let nativeAudioScopeFreshnessSeconds = 2.5
    private static let audioScopeFreshnessCheckInterval = 0.5
    private static let nativeAudioScopePermissionMessage = "optional visualizer audio capture is off"
    private static let nativeAudioScopeExecutableFingerprintKey = "pomo.audio.coreAudioTap.executableFingerprint"
    private static let nativeAudioScopeUserEnabledKey = "pomo.audio.coreAudioTap.userEnabled"
    private static let playbackSnapshotKey = "pomo.amp.playbackSnapshot"
    private static let playbackAutoResumeMaxAge: TimeInterval = 30 * 60

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var navProxy: NavProxy?          // retained — navigationDelegate is weak
    private var messageProxy: MessageProxy?
    private var signInWindow: NSWindow?
    private var importLoginWindow: NSWindow?

    private(set) var isPlaying = false
    private(set) var currentURL: String = ""
    private(set) var currentTitle: String = ""
    private var volume: Int = 60
    private(set) var mediaTime: Double = 0
    private(set) var mediaDuration: Double = 0
    private(set) var mediaPlaybackRate: Double = 1
    private(set) var mediaPaused: Bool = true
    private var mediaClockHostTime: Double = ProcessInfo.processInfo.systemUptime
    private var pendingSeekTime: Double?
    private var lastPlaybackSnapshotHostTime = 0.0
    private(set) var audioScope: AudioScopeFrame?
    private(set) var audioScopeError: String?
    private var silentScopeFrames = 0
    private var nonSilentScopeFrames = 0
    private var audioScopeFreshnessTimer: Timer?
    private var audioScopeFrameIntervalMilliseconds = WebAudioPlayer.defaultAudioScopeFrameIntervalMilliseconds
    private var visualizerActive = false
    private var nativeAudioScopeRestartWork: DispatchWorkItem?
    private var lastNativeAudioScopeRestartHostTime = 0.0
    private var nativeAudioScopeSuppressedUntil = 0.0
    private var nativeAudioScopeEnabledForSession = WebAudioPlayer.shouldAutoStartNativeAudioScope()
    private var nativeAudioScopeRecordedSuccessfulAccess = WebAudioPlayer.hasSuccessfulNativeAudioScopeAccessForCurrentExecutable()
    private lazy var nativeAudioScope = CoreAudioTapAudioScope(
        onFrame: { [weak self] frame in
            Task { @MainActor in self?.handleNativeAudioScopeFrame(frame) }
        },
        onError: { [weak self] error in
            Task { @MainActor in self?.handleNativeAudioScopeError(error) }
        },
        onLog: { [weak self] message in
            Task { @MainActor in self?.log(message) }
        }
    )

    private struct PlaybackSnapshot: Codable {
        var url: String
        var title: String
        var time: Double
        var duration: Double
        var wasPlaying: Bool
        var updatedAt: TimeInterval
    }

    /// User intent: whether the video drawer is open. Toggleable at runtime; kept
    /// across HUD hide/show so the drawer returns alongside the panel.
    private(set) var drawerOpen = false

    /// Edge the drawer last docked to — drives the HUD's seam-squaring.
    private(set) var drawerEdge: DrawerEdge = .right

    /// Expanded = full page (playlist/related) at a larger size; collapsed =
    /// chrome-stripped "screen" matched to the HUD.
    private(set) var drawerExpanded = false

    /// The HUD panel the drawer attaches to and slides out from. Weak — the
    /// panel owns its own lifecycle; we just track and dock against it.
    private weak var anchorWindow: NSWindow?

    /// Rounded container hosting the web view + the expand button overlay.
    private var drawerContainer: NSView?
    private var expandButton: NSButton?
    private var skipAdButton: NSButton?
    private var loadingView: PomoLoadingView?
    private var loadingHideWork: DispatchWorkItem?
    private var videoQualityWork: DispatchWorkItem?
    private var avatarView: NSImageView?
    private var idleMemoryPurgeWork: DispatchWorkItem?
    private var boundaryMemoryPurgeWork: DispatchWorkItem?
    private var preparedBrowserSwapWork: DispatchWorkItem?
    private var pendingThresholdPurgeReason: String?
    private var preparedBrowser: BrowserInstance?

    /// Signed-in YouTube identity, surfaced in Settings + the drawer avatar.
    let account = AccountStatus()

    /// Favorites, for the video menu's "Change Track" submenu. Weak — owned by
    /// AppDelegate; wired via `AudioController.bindFavorites`.
    weak var favorites: FavoritesStore?

    private static let drawerRadius: CGFloat = 12

    private struct BrowserInstance {
        let webView: DrawerWebView
        let hostWindow: NSWindow
        let navProxy: NavProxy
        let messageProxy: MessageProxy
        let drawerContainer: NSView
        let expandButton: NSButton
        let skipAdButton: NSButton
        let loadingView: PomoLoadingView
        let avatarView: NSImageView
    }

    /// Fired when playback state changes (from JS player events).
    var onStateChange: (() -> Void)?

    /// Keeps the on-disk cookie backup in sync, and coalesces the writes so a
    /// burst of cookie changes during a page load only persists once.
    private var cookieObserver: CookieStoreObserver?
    private var cookieSaveWork: DispatchWorkItem?
    private var restoredSavedLogin = false
    private var restoreLoginTask: Task<Void, Never>?
    private var persistedCookieSignature: String?

    override init() {
        super.init()
        // Keep the on-disk backup current. Playback/sign-in explicitly await
        // restoreSavedLoginIfNeeded() before first navigation.
        startCookiePersistence()
        startAudioScopeFreshnessWatchdog()
    }

    // MARK: - Playback

    /// Google multi-login account index (0 = default). Persisted so the chosen
    /// account sticks across relaunches.
    private var authUser: Int {
        get { UserDefaults.standard.integer(forKey: "pomo.audio.authUser") }
        set { UserDefaults.standard.set(max(0, newValue), forKey: "pomo.audio.authUser") }
    }

    func play(urlString raw: String, startAt: Double? = nil, knownTitle: String? = nil) {
        let urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, let base = Self.watchURL(from: urlString) else { return }
        cancelIdleMemoryPurge()
        cancelBoundaryMemoryPurge()
        cancelPreparedBrowserSwap()
        currentURL = urlString
        currentTitle = knownTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        pendingSeekTime = (startAt ?? 0) > 1 ? startAt : nil
        mediaTime = 0
        mediaDuration = 0
        mediaPlaybackRate = 1
        mediaPaused = false
        mediaClockHostTime = ProcessInfo.processInfo.systemUptime
        resetAudioScope()
        stopNativeAudioScope()
        ensureWebView()
        isPlaying = true
        persistPlaybackSnapshot(force: true, wasPlaying: true)

        Task { @MainActor in
            await self.restoreSavedLoginIfNeeded()
            guard self.currentURL == urlString else { return }
            let url = Self.withAuthUser(base, self.authUser)
            self.log("play \(url.absoluteString)")
            self.webView?.load(URLRequest(url: url))
        }
    }

    /// Pick which signed-in Google account to use, and reload.
    func setAccount(_ index: Int) {
        authUser = index
        log("account → \(index)")
        if !currentURL.isEmpty { play(urlString: currentURL) }
    }

    func resume(stored: String) {
        cancelIdleMemoryPurge()
        cancelBoundaryMemoryPurge()
        cancelPreparedBrowserSwap()
        let url = currentURL.isEmpty ? stored : currentURL
        if currentURL.isEmpty || webView == nil {
            if restoreRecentPlayback(preferredURL: url, requireWasPlaying: false) {
                return
            }
            play(urlString: url)
            return
        }
        eval("document.querySelector('video,audio')&&document.querySelector('video,audio').play();")
        isPlaying = true
        persistPlaybackSnapshot(force: true, wasPlaying: true)
    }

    func pause() {
        eval(Self.pauseAndSuspendScopeJS)
        mediaTime = estimatedMediaTime()
        isPlaying = false
        mediaPaused = true
        mediaClockHostTime = ProcessInfo.processInfo.systemUptime
        stopNativeAudioScope()
        persistPlaybackSnapshot(force: true, wasPlaying: false)
        scheduleIdleMemoryPurge(reason: "paused audio")
    }

    func stop() {
        if let webView {
            quietWebViewForRelease(webView, reason: "stopped audio")
        }
        currentURL = ""
        currentTitle = ""
        isPlaying = false
        mediaTime = 0
        mediaDuration = 0
        mediaPlaybackRate = 1
        mediaPaused = true
        mediaClockHostTime = ProcessInfo.processInfo.systemUptime
        resetAudioScope()
        stopNativeAudioScope()
        setWindowVisible(false)
        Self.clearPlaybackSnapshot()
        scheduleIdleMemoryPurge(reason: "stopped audio")
        scheduleMediaCachePurge(reason: "stopped audio")
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(100, Int((value * 100).rounded())))
        eval("var v=document.querySelector('video,audio'); if(v){v.volume=\(volume)/100.0;}")
    }

    func requestAudioScopePermission() {
        audioScopeError = nil
        nativeAudioScopeSuppressedUntil = 0
        ScreenCaptureAudioPermission.registerPermissionTarget(reason: "visualizer requested")
        Self.recordNativeAudioScopeUserIntent()
        nativeAudioScopeEnabledForSession = true
        if isPlaying {
            startNativeAudioScope(reason: "visualizer requested", userInitiated: true)
        } else {
            ScreenCaptureAudioPermission.showAssistant(startRequest: false)
        }
        onStateChange?()
    }

    func setVisualizerActive(_ active: Bool) {
        guard visualizerActive != active else { return }
        visualizerActive = active

        if active {
            eval(Self.setVisualizerActiveJS(true))
            eval(Self.setAudioScopeFrameIntervalJS(audioScopeFrameIntervalMilliseconds))
            if isPlaying {
                eval("window.__pomoSetupScope && window.__pomoSetupScope();")
            }
        } else {
            eval(Self.setVisualizerActiveJS(false))
            eval(Self.suspendAudioScopeJS)
            resetAudioScope()
            stopNativeAudioScope()
        }
        onStateChange?()
    }

    func setVisualizerScopeFrameInterval(milliseconds: Int) {
        let clamped = max(33, min(500, milliseconds))
        guard audioScopeFrameIntervalMilliseconds != clamped else { return }
        audioScopeFrameIntervalMilliseconds = clamped
        nativeAudioScope.setFrameInterval(milliseconds: clamped)
        eval(Self.setAudioScopeFrameIntervalJS(clamped))
        if visualizerActive, isPlaying {
            eval("window.__pomoSetupScope && window.__pomoSetupScope();")
        }
    }

    func estimatedMediaTime(at hostTime: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        var time = mediaTime
        if isPlaying, !mediaPaused {
            time += max(0, hostTime - mediaClockHostTime) * max(0, mediaPlaybackRate)
        }
        if mediaDuration > 0 {
            time = min(time, mediaDuration)
        }
        return max(0, time)
    }

    /// Skip to the next track — works on YouTube playlists/radio and YT Music.
    func next() {
        eval(Self.clickJS([
            ".ytp-next-button",
            "ytmusic-player-bar .next-button button",
            "tp-yt-paper-icon-button.next-button",
            "[aria-label='Next']", "[title='Next']",
        ]))
    }

    func previous() {
        eval(Self.clickJS([
            "ytmusic-player-bar .previous-button button",
            "tp-yt-paper-icon-button.previous-button",
            "[aria-label='Previous']", "[title='Previous']",
        ]))
    }

    func nextTimestampSection() {
        seekTimestampSection(direction: 1)
    }

    func previousTimestampSection() {
        seekTimestampSection(direction: -1)
    }

    @discardableResult
    func restoreRecentPlayback(preferredURL: String, requireWasPlaying: Bool = true) -> Bool {
        let snapshot = Self.loadPlaybackSnapshot()
        let fallbackURL = preferredURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let snapshot else { return false }
        guard !requireWasPlaying || snapshot.wasPlaying else { return false }
        guard Date().timeIntervalSince1970 - snapshot.updatedAt <= Self.playbackAutoResumeMaxAge else { return false }

        let url = snapshot.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let restoreURL = url.isEmpty ? fallbackURL : url
        guard !restoreURL.isEmpty else { return false }
        play(urlString: restoreURL, startAt: snapshot.time, knownTitle: snapshot.title)
        return true
    }

    func persistPlaybackSnapshotNow() {
        persistPlaybackSnapshot(force: true)
    }

    // MARK: - Attached video drawer

    /// Reflects user intent (not raw window visibility) so the on-face toggle
    /// stays correct even mid-animation.
    var isWindowVisible: Bool { drawerOpen }

    /// Show/hide the drawer. Opening lazily builds the web view if it doesn't
    /// exist yet, then docks it directly to the current HUD panel.
    func setWindowVisible(_ visible: Bool) {
        let changed = drawerOpen != visible
        drawerOpen = visible
        if visible {
            cancelIdleMemoryPurge()
            cancelPreparedBrowserSwap()
            let restoreURL = webView == nil ? currentURL : ""
            ensureWebView()
            if !restoreURL.isEmpty {
                play(urlString: restoreURL)
            }
            openDrawer()
        } else {
            closeDrawer()
            scheduleIdleMemoryPurge(reason: "hidden video drawer")
        }
        if changed {
            onStateChange?()
        }
    }

    func toggleWindow() { setWindowVisible(!drawerOpen) }

    /// The HUD appeared: anchor to it and, if the drawer was open, dock it back
    /// alongside the (possibly repositioned) panel.
    func hudDidAppear(anchor: NSWindow?) {
        anchorWindow = anchor
        if drawerOpen { openDrawer() }
        onStateChange?()
    }

    /// The HUD is hiding: tuck the drawer away with it, keeping the open intent
    /// so it returns on the next summon.
    func hudWillDisappear() {
        guard let host = hostWindow else { return }
        if let anchor = anchorWindow, host.parent === anchor { anchor.removeChildWindow(host) }
        host.orderOut(nil)
        host.alphaValue = 1
        onStateChange?()
    }

    /// Switch between the original YouTube page (comments/details/account UI)
    /// and the chrome-stripped player view that matches the HUD.
    func setExpanded(_ on: Bool) {
        guard drawerOpen, let host = hostWindow, let anchor = anchorWindow else { return }
        drawerExpanded = on
        let a = anchor.frame
        let shade = isShadeAnchor(a)
        applyBare(shade || !on)             // shade mode always uses the compact player sheet
        applyDrawerCorners()
        updateExpandButton()
        onStateChange?()
        let screen = (anchor.screen ?? NSScreen.main)?.visibleFrame ?? a
        let open = openFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a, screen: screen)
        if host.parent === anchor { anchor.removeChildWindow(host) }
        host.alphaValue = 1
        host.setFrame(open, display: true)
        host.order(.below, relativeTo: anchor.windowNumber)
        if host.parent !== anchor {
            anchor.addChildWindow(host, ordered: .below)
        }
        scheduleVideoQualityRefresh(delay: 0.45)
    }

    func setOriginalPageVisible(_ visible: Bool) {
        if visible && !drawerOpen {
            setWindowVisible(true)
        }
        guard drawerOpen else {
            drawerExpanded = visible
            return
        }
        setExpanded(visible)
    }

    @objc private func didTapExpand() { setExpanded(!drawerExpanded) }

    @objc private func didTapOpenInBrowser() { openInBrowser() }

    @objc private func didTapSkipAd() {
        eval(Self.skipAdClickJS)
        setSkipAdAvailable(false)
    }

    /// Pop the *currently playing* page (playlist/index intact) out to the
    /// default browser, where playlists, autoplay and the user's extensions work.
    func openInBrowser() {
        guard let url = webView?.url ?? (currentURL.isEmpty ? nil : URL(string: currentURL)) else { return }
        log("open in browser \(url.absoluteString)")
        NSWorkspace.shared.open(url)
    }

    private static func overlayButton(symbol: String, tip: String, target: Any?, action: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(),
                         target: target, action: action)
        b.isBordered = false
        b.imagePosition = .imageOnly
        b.contentTintColor = .white
        b.wantsLayer = true
        b.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        b.layer?.cornerRadius = 11
        b.toolTip = tip
        return b
    }

    private static func skipAdOverlayButton(target: Any?, action: Selector) -> NSButton {
        let b = NSButton(title: "Skip Ad", target: target, action: action)
        b.isBordered = false
        b.bezelStyle = .regularSquare
        b.wantsLayer = true
        b.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.74).cgColor
        b.layer?.cornerRadius = 8
        b.layer?.borderWidth = 1
        b.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        b.contentTintColor = .white
        b.font = .systemFont(ofSize: 12, weight: .semibold)
        b.toolTip = "Skip YouTube ad"
        return b
    }

    // MARK: - Drawer geometry

    /// First edge (right → left → below → above) with room for the collapsed
    /// drawer beside the HUD.
    private func chooseEdge(_ a: NSRect, _ screen: NSRect) -> DrawerEdge {
        if isShadeAnchor(a) {
            let sheetHeight = collapsedSize(.below, hud: a).height
            let roomBelow = a.minY - screen.minY + seam
            let roomAbove = screen.maxY - a.maxY + seam
            if roomBelow >= sheetHeight { return .below }
            if roomAbove >= sheetHeight { return .above }
            return roomBelow >= roomAbove ? .below : .above
        }

        let sideW = collapsedSize(.right).width, vertH = collapsedSize(.below).height
        if a.maxX - seam + sideW <= screen.maxX { return .right }
        if a.minX + seam - sideW >= screen.minX { return .left }
        if a.minY + seam - vertH >= screen.minY { return .below }
        if a.maxY - seam + vertH <= screen.maxY { return .above }
        return .right
    }

    private static let seamOverlap: CGFloat = 2     // hairline tuck so no desktop shows through
    private var seam: CGFloat { Self.seamOverlap }

    private func isShadeAnchor(_ anchor: NSRect) -> Bool {
        anchor.height <= 44
    }

    /// Collapsed matches the HUD across the shared edge; height/width filled in
    /// from the anchor at call sites that have it.
    private func collapsedSize(_ edge: DrawerEdge, hud: NSRect = .zero) -> NSSize {
        switch edge {
        case .right, .left: return NSSize(width: 360, height: hud.height == 0 ? 244 : hud.height)
        case .below, .above: return NSSize(width: hud.width == 0 ? 352 : hud.width, height: 202)
        }
    }

    private func expandedSize(_ edge: DrawerEdge, hud: NSRect) -> NSSize {
        let screen = (anchorWindow?.screen ?? NSScreen.main)?.visibleFrame ?? hud
        let width = min(760, max(560, screen.width - 64))
        let height = min(560, max(420, screen.height - 96))
        return NSSize(width: width, height: height)
    }

    private func size(for edge: DrawerEdge, in hud: NSRect) -> NSSize {
        if isShadeAnchor(hud) {
            return collapsedSize(edge, hud: hud)
        }
        return drawerExpanded ? expandedSize(edge, hud: hud) : collapsedSize(edge, hud: hud)
    }

    /// Place a drawer of `size` flush against `edge` of the HUD, centred on the
    /// cross axis and tucked `seam` px behind it.
    private func drawerFrame(size s: NSSize, edge: DrawerEdge, anchor a: NSRect) -> NSRect {
        switch edge {
        case .right: return NSRect(x: a.maxX - seam,            y: a.midY - s.height / 2, width: s.width, height: s.height)
        case .left:  return NSRect(x: a.minX + seam - s.width,  y: a.midY - s.height / 2, width: s.width, height: s.height)
        case .below: return NSRect(x: a.midX - s.width / 2,     y: a.minY + seam - s.height, width: s.width, height: s.height)
        case .above: return NSRect(x: a.midX - s.width / 2,     y: a.maxY - seam, width: s.width, height: s.height)
        }
    }

    private func openFrame(size s: NSSize, edge: DrawerEdge, anchor a: NSRect, screen: NSRect) -> NSRect {
        let frame = drawerFrame(size: s, edge: edge, anchor: a)
        if isShadeAnchor(a) {
            return constrained(frame, to: screen.insetBy(dx: 8, dy: 8))
        }
        return drawerExpanded ? constrained(frame, to: screen.insetBy(dx: 16, dy: 16)) : frame
    }

    private func constrained(_ frame: NSRect, to bounds: NSRect) -> NSRect {
        var frame = frame
        frame.size.width = min(frame.width, bounds.width)
        frame.size.height = min(frame.height, bounds.height)
        if frame.minX < bounds.minX { frame.origin.x = bounds.minX }
        if frame.maxX > bounds.maxX { frame.origin.x = bounds.maxX - frame.width }
        if frame.minY < bounds.minY { frame.origin.y = bounds.minY }
        if frame.maxY > bounds.maxY { frame.origin.y = bounds.maxY - frame.height }
        return frame
    }

    /// Dock the drawer to the HUD, then adopt it as a child window so it tracks
    /// the panel when dragged.
    private func openDrawer() {
        guard let host = hostWindow else { return }
        guard let anchor = anchorWindow else { host.orderFrontRegardless(); return }
        let a = anchor.frame
        let screen = (anchor.screen ?? NSScreen.main)?.visibleFrame ?? a
        let shade = isShadeAnchor(a)
        drawerEdge = chooseEdge(a, screen)
        applyDrawerCorners()
        applyBare(shade || !drawerExpanded)

        let open = openFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a, screen: screen)
        if host.parent === anchor { anchor.removeChildWindow(host) }
        host.alphaValue = 1
        host.setFrame(open, display: true)
        host.order(.below, relativeTo: anchor.windowNumber)
        if host.parent !== anchor {
            anchor.addChildWindow(host, ordered: .below)
        }
        scheduleVideoQualityRefresh(delay: 0.65)
    }

    /// Hide the drawer. Preserve the current page/player mode so reopening feels
    /// like returning to the same surface, not starting over.
    private func closeDrawer() {
        showLoading(false)
        guard let host = hostWindow, host.isVisible else {
            hostWindow?.orderOut(nil)
            scheduleIdleMemoryPurge(reason: "hidden video drawer")
            completePendingThresholdPurge(at: "hidden video drawer", delay: 0)
            return
        }
        if let anchor = anchorWindow {
            if host.parent === anchor { anchor.removeChildWindow(host) }
        }
        host.orderOut(nil)
        host.alphaValue = 1
        updateExpandButton()
        scheduleVideoQualityRefresh(delay: 1.0)
        scheduleIdleMemoryPurge(reason: "hidden video drawer")
        completePendingThresholdPurge(at: "hidden video drawer", delay: 0)
    }

    // MARK: - Browser/video memory reclamation

    /// Main entry point for proactive cleanup. Cache data is safe to drop while
    /// active; the actual WKWebView is released only when playback is idle and
    /// the video drawer is hidden, so cleanup never interrupts a visible player.
    func purgeBrowserMemory(reason: String, aggressive: Bool = false) {
        log("memory purge requested (\(reason))")
        URLCache.shared.removeAllCachedResponses()
        purgeWebsiteCaches(reason: reason)
        if aggressive { discardPreparedBrowser(reason: reason) }

        if isPlaying || drawerOpen {
            discardPreparedBrowser(reason: reason)
            applyVideoQuality()
            return
        }

        purgeWebKitMediaCacheFiles(reason: reason)
        if aggressive {
            releaseWebView(reason: reason)
        } else {
            rotateIdleWebView(reason: reason)
        }
    }

    /// A memory threshold crossed while WebKit may still be useful. Mark the
    /// cleanup pending and let track/session boundaries complete it.
    func deferBrowserMemoryPurgeUntilBoundary(reason: String) {
        pendingThresholdPurgeReason = reason
        log("memory threshold crossed; deferring web player release until boundary (\(reason))")
        discardPreparedBrowser(reason: reason)
        URLCache.shared.removeAllCachedResponses()
        purgeWebsiteCaches(reason: reason)
        if !isPlaying {
            completePendingThresholdPurge(at: "idle threshold check", delay: 0)
        }
    }

    func purgeBrowserMemoryAtSessionBoundary() {
        if pendingThresholdPurgeReason != nil {
            completePendingThresholdPurge(at: "pomo session boundary", delay: 0)
        } else {
            purgeBrowserMemory(reason: "pomo session boundary")
        }
    }

    private func scheduleIdleMemoryPurge(reason: String) {
        idleMemoryPurgeWork?.cancel()
        guard !isPlaying, !drawerOpen else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.purgeBrowserMemory(reason: reason)
            }
        }
        idleMemoryPurgeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleBrowserMemoryPurgeDelay, execute: work)
    }

    private func cancelIdleMemoryPurge() {
        idleMemoryPurgeWork?.cancel()
        idleMemoryPurgeWork = nil
    }

    private func completePendingThresholdPurge(at boundary: String, delay: TimeInterval = 4) {
        guard pendingThresholdPurgeReason != nil else { return }
        boundaryMemoryPurgeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let reason = self.pendingThresholdPurgeReason else { return }
                guard !self.isPlaying else {
                    self.log("deferred memory purge still waiting; playback resumed before \(boundary)")
                    return
                }
                guard !self.drawerOpen else {
                    self.log("deferred memory purge still waiting; drawer visible at \(boundary)")
                    self.purgeWebsiteCaches(reason: "\(boundary) after \(reason)")
                    self.purgeWebKitMediaCacheFiles(reason: "\(boundary) after \(reason)")
                    return
                }
                self.pendingThresholdPurgeReason = nil
                self.purgeBrowserMemory(reason: "\(boundary) after \(reason)", aggressive: true)
            }
        }
        boundaryMemoryPurgeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelBoundaryMemoryPurge() {
        boundaryMemoryPurgeWork?.cancel()
        boundaryMemoryPurgeWork = nil
    }

    private func completePreparedBrowserSwap(at boundary: String, delay: TimeInterval = 4) {
        guard preparedBrowser != nil else { return }
        preparedBrowserSwapWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.preparedBrowser != nil else { return }
                guard !self.isPlaying else {
                    self.log("prepared web player still waiting; playback resumed before \(boundary)")
                    return
                }
                guard !self.drawerOpen else {
                    self.log("prepared web player still waiting; drawer visible at \(boundary)")
                    return
                }
                self.rotateIdleWebView(reason: "\(boundary) warm replacement")
            }
        }
        preparedBrowserSwapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPreparedBrowserSwap() {
        preparedBrowserSwapWork?.cancel()
        preparedBrowserSwapWork = nil
    }

    private func purgeWebsiteCaches(reason: String) {
        let types: Set<String> = [
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeDiskCache,
        ]
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in self?.log("purged browser caches (\(reason))") }
        }
    }

    private func scheduleMediaCachePurge(reason: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            MainActor.assumeIsolated {
                self?.purgeWebKitMediaCacheFiles(reason: reason)
            }
        }
    }

    private func purgeWebKitMediaCacheFiles(reason: String) {
        guard !isPlaying else { return }
        let manager = FileManager.default
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return }
        let mediaCache = manager.temporaryDirectory
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("WebKit", isDirectory: true)
            .appendingPathComponent("MediaCache", isDirectory: true)

        guard let files = try? manager.contentsOfDirectory(
            at: mediaCache,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var removed = 0
        for file in files where file.lastPathComponent.hasPrefix("CachedMedia-") {
            let isRegularFile = (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true
            guard isRegularFile else { continue }
            do {
                try manager.removeItem(at: file)
                removed += 1
            } catch {
                log("media cache prune skipped \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if removed > 0 {
            log("purged \(removed) WebKit media cache file(s) (\(reason))")
        }
    }

    private func prepareReplacementBrowser(reason: String) {
        guard webView != nil || hostWindow != nil else { return }
        guard preparedBrowser == nil else { return }
        let replacement = makeBrowserInstance()
        preparedBrowser = replacement
        replacement.webView.loadHTMLString("<!doctype html><meta charset=\"utf-8\">", baseURL: nil)
        log("prepared replacement web player (\(reason))")
    }

    private func discardPreparedBrowser(reason: String) {
        guard let prepared = preparedBrowser else { return }
        cancelPreparedBrowserSwap()
        preparedBrowser = nil
        tearDownBrowserInstance(prepared)
        log("discarded prepared web player (\(reason))")
    }

    private func rotateIdleWebView(reason: String) {
        guard webView != nil || hostWindow != nil else { return }
        guard let current = currentBrowserInstance() else {
            releaseWebView(reason: reason)
            return
        }

        let replacement: BrowserInstance
        if let prepared = preparedBrowser {
            preparedBrowser = nil
            replacement = prepared
            log("swapping to prepared web player (\(reason))")
        } else {
            replacement = makeBrowserInstance()
            log("created replacement web player before releasing old one (\(reason))")
        }

        loadingHideWork?.cancel()
        loadingHideWork = nil
        installBrowserInstance(replacement)
        tearDownBrowserInstance(current)
        pendingThresholdPurgeReason = nil
        cancelIdleMemoryPurge()
        cancelBoundaryMemoryPurge()
        cancelPreparedBrowserSwap()
    }

    private func releaseWebView(reason: String) {
        guard webView != nil || hostWindow != nil || preparedBrowser != nil else { return }
        log("releasing idle web player (\(reason))")
        pendingThresholdPurgeReason = nil
        cancelIdleMemoryPurge()
        cancelBoundaryMemoryPurge()
        cancelPreparedBrowserSwap()
        loadingHideWork?.cancel()
        loadingHideWork = nil
        loadingView?.stop()
        showLoading(false)

        discardPreparedBrowser(reason: reason)
        if let current = currentBrowserInstance() {
            tearDownBrowserInstance(current)
        } else {
            if let host = hostWindow, let anchor = anchorWindow, host.parent === anchor {
                anchor.removeChildWindow(host)
            }
            if let drawer = webView as? DrawerWebView {
                drawer.owner = nil
            }
            if let webView {
                quietWebViewForRelease(webView, reason: reason)
            }
            webView?.navigationDelegate = nil
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "pomo")
            hostWindow?.contentView = nil
            hostWindow?.orderOut(nil)
        }

        webView = nil
        hostWindow = nil
        navProxy = nil
        messageProxy = nil
        drawerContainer = nil
        expandButton = nil
        skipAdButton = nil
        loadingView = nil
        avatarView = nil
        scheduleMediaCachePurge(reason: reason)
    }

    /// Round only the *outer* corners when collapsed (so the inner edge butts the
    /// HUD square — one block); round all four when expanded (free-floating panel).
    private func applyDrawerCorners() {
        guard let layer = drawerContainer?.layer else { return }
        layer.cornerRadius = Self.drawerRadius
        let shade = anchorWindow.map { isShadeAnchor($0.frame) } ?? false
        if drawerExpanded && !shade {
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                   .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            return
        }
        switch drawerEdge {                                       // keep the 2 corners away from the HUD
        case .right: layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        case .left:  layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .below: layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case .above: layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
    }

    /// Toggle the injected "bare" class that strips YouTube to just the player.
    private func applyBare(_ bare: Bool) {
        if bare {
            eval("(function(){var h=document.documentElement;if(h){h.classList.add('pomo-bare');}window.dispatchEvent(new Event('resize'));})();")
        } else {
            eval("""
            (function(){
              var h=document.documentElement, b=document.body;
              if (h) {
                h.classList.remove('pomo-bare');
                h.style.overflow='';
                h.style.background='';
              }
              if (b) {
                b.style.overflow='';
                b.style.background='';
              }
              ['ytd-app','ytd-page-manager','ytd-watch-flexy','#page-manager','#columns','#primary','#secondary','#below'].forEach(function(sel){
                var el=document.querySelector(sel);
                if(!el) return;
                el.style.display='';
                el.style.visibility='';
                el.style.position='';
                el.style.inset='';
                el.style.width='';
                el.style.height='';
                el.style.maxWidth='';
                el.style.maxHeight='';
                el.style.overflow='';
              });
              window.dispatchEvent(new Event('resize'));
              setTimeout(function(){ window.dispatchEvent(new Event('resize')); }, 120);
            })();
            """)
        }
    }

    private func updateExpandButton() {
        let symbol = drawerExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        expandButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: drawerExpanded ? "Show Player" : "Show Page")
        expandButton?.toolTip = drawerExpanded ? "Show Player" : "Show Page"
    }

    // MARK: - Sign in (persistent profile)

    func signIn() {
        // A login needs keyboard focus, which an accessory app can't grab without
        // becoming a regular app; revert when the window closes.
        NSApp.setActivationPolicy(.regular)

        if let signInWindow {
            NSApp.activate(ignoringOtherApps: true)
            signInWindow.makeKeyAndOrderFront(nil)
            return
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()     // shared with the player → login persists
        let frame = NSRect(x: 0, y: 0, width: 920, height: 720)
        let wv = WKWebView(frame: frame, configuration: config)
        wv.customUserAgent = Self.desktopUA

        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Sign in to YouTube / YouTube Music"
        window.isReleasedWhenClosed = false
        window.contentView = wv
        window.center()
        window.delegate = self
        signInWindow = window

        Task { @MainActor in
            await self.restoreSavedLoginIfNeeded()
            let continueURL = URL(string: "https://www.youtube.com/")!
            wv.load(URLRequest(url: Self.serviceLoginURL(continueURL: continueURL, accountIndex: self.authUser)))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Borrow the YouTube login from a browser/profile (via the rookie helper)
    /// and reload signed-in. Clears any prior Google/YouTube cookies first so
    /// accounts/profiles don't mix. `browser` nil = all; `profile` e.g. "Profile 1".
    func importCookies(fromBrowser browser: String?, profile: String?, accountIndex: Int = 0) {
        Task { @MainActor in
            _ = await importLogin(fromBrowser: browser, profile: profile, accountIndex: accountIndex)
        }
    }

    /// Awaitable import that returns how many auth cookies were found, so callers
    /// (e.g. the import panel) can report success vs "nothing found". Clears any
    /// prior Google/YouTube cookies first so accounts/profiles don't mix.
    @discardableResult
    func importLogin(fromBrowser browser: String?, profile: String?, accountIndex: Int = 0) async -> Int {
        ensureWebView()
        guard let webView else { return 0 }
        let accountIndex = max(0, accountIndex)
        let label = [browser, profile].compactMap { $0 }.joined(separator: " / ")
        log("importing cookies from \(label.isEmpty ? "all browsers" : label)…")
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await CookieImporter.cookies(fromBrowser: browser, profile: profile)
        guard !cookies.isEmpty else {
            log("import found no cookies; keeping existing login")
            return 0
        }

        if let restoreLoginTask {
            await restoreLoginTask.value
            self.restoreLoginTask = nil
        }
        let cleared = await Self.clearAuthCookies(store)
        for cookie in cookies { await store.setCookie(cookie) }
        let acceptedCookies = (await store.allCookies()).filter(Self.isPersistableAuthCookie)
        let persistedCookies = acceptedCookies.isEmpty ? cookies.filter(Self.isPersistableAuthCookie) : acceptedCookies
        CookieJar.save(persistedCookies)
        restoredSavedLogin = true
        persistedCookieSignature = Self.cookieSignature(persistedCookies)
        cookieSaveWork?.cancel()
        authUser = accountIndex
        log("cleared \(cleared), imported \(cookies.count) cookies for account \(accountIndex)")
        let targetURL: URL
        if !currentURL.isEmpty, let base = Self.watchURL(from: currentURL) {
            targetURL = Self.withAuthUser(base, accountIndex)
        } else if let url = URL(string: "https://www.youtube.com/") {
            targetURL = Self.withAuthUser(url, accountIndex)
        } else {
            return cookies.count
        }
        webView.load(URLRequest(url: Self.serviceLoginURL(continueURL: targetURL, accountIndex: accountIndex)))
        return cookies.count
    }

    /// Sign out: drop all Google/YouTube cookies and reload.
    func clearLogin() {
        ensureWebView()
        guard let webView else { return }
        Task { @MainActor in
            if let restoreLoginTask = self.restoreLoginTask {
                await restoreLoginTask.value
                self.restoreLoginTask = nil
            }
            let cleared = await Self.clearAuthCookies(webView.configuration.websiteDataStore.httpCookieStore)
            self.authUser = 0
            self.restoredSavedLogin = true
            self.persistedCookieSignature = nil
            CookieJar.save([])   // write-through so logout survives an immediate quit
            self.log("logout — cleared \(cleared) cookies")
            if !self.currentURL.isEmpty, let url = Self.watchURL(from: self.currentURL) {
                webView.load(URLRequest(url: url))
            }
        }
    }

    /// Reload the player's current page so a freshly-acquired login is detected.
    /// The signed-in identity is read off the *player's* masthead, not the
    /// sign-in window, so without this a web sign-in never registers. No-op when
    /// nothing is loaded (there's no page to read the account from yet).
    private func reloadForLogin() {
        guard let webView, !currentURL.isEmpty, let base = Self.watchURL(from: currentURL) else { return }
        authUser = 0
        webView.load(URLRequest(url: Self.withAuthUser(base, 0)))
    }

    @discardableResult
    private static func clearAuthCookies(_ store: WKHTTPCookieStore) async -> Int {
        let existing = await store.allCookies()
        let auth = existing.filter { isAuthDomain($0.domain) }
        for cookie in auth { await store.deleteCookie(cookie) }
        return auth.count
    }

    private static func isAuthDomain(_ domain: String) -> Bool {
        let d = domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return d == "youtube.com" || d.hasSuffix(".youtube.com")
            || d == "google.com" || d.hasSuffix(".google.com")
    }

    // MARK: - Login persistence (cookies on disk)

    /// Re-inject any login saved on a prior run into the shared default store.
    /// First navigation waits for this so YouTube does not boot signed-out and
    /// overwrite the imported session during hydration.
    private func restoreSavedLoginIfNeeded() async {
        if restoredSavedLogin { return }
        if let restoreLoginTask {
            await restoreLoginTask.value
            return
        }

        let task = Task { @MainActor in
            defer { self.restoredSavedLogin = true }
            let saved = CookieJar.load()
            guard !saved.isEmpty else { return }
            let store = self.webView?.configuration.websiteDataStore.httpCookieStore
                ?? WKWebsiteDataStore.default().httpCookieStore
            for cookie in saved { await store.setCookie(cookie) }
            self.persistedCookieSignature = Self.cookieSignature(saved)
            self.log("restored \(saved.count) login cookies from disk")
        }

        restoreLoginTask = task
        await task.value
        restoreLoginTask = nil
    }

    /// Watch the shared cookie store and mirror the auth cookies to disk whenever
    /// they change — so logging in (or out) is written through automatically.
    private func startCookiePersistence() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let observer = CookieStoreObserver { [weak self] in
            // Delivered on the main thread; coalesce the burst during a page load.
            MainActor.assumeIsolated { self?.scheduleCookieSave() }
        }
        store.add(observer)
        cookieObserver = observer
    }

    private func scheduleCookieSave() {
        cookieSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.persistAuthCookies() }
        }
        cookieSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func persistAuthCookies() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        Task { @MainActor in
            let all = await store.allCookies()
            let cookies = all.filter(Self.isPersistableAuthCookie)
            guard !cookies.isEmpty else { return }
            let signature = Self.cookieSignature(cookies)
            guard signature != self.persistedCookieSignature else { return }
            CookieJar.save(cookies)
            self.persistedCookieSignature = signature
            self.log("persisted \(cookies.count) login cookies")
        }
    }

    private static func isPersistableAuthCookie(_ cookie: HTTPCookie) -> Bool {
        guard isAuthDomain(cookie.domain), !cookie.value.isEmpty else { return false }
        if let expires = cookie.expiresDate, expires <= Date() { return false }
        return true
    }

    private static func cookieSignature(_ cookies: [HTTPCookie]) -> String {
        cookies
            .map { cookie in
                let expires = cookie.expiresDate?.timeIntervalSince1970 ?? 0
                return "\(cookie.domain)\t\(cookie.path)\t\(cookie.name)\t\(cookie.value)\t\(expires)"
            }
            .sorted()
            .joined(separator: "\n")
    }

    private static func serviceLoginURL(continueURL: URL, accountIndex: Int) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/ServiceLogin")!
        components.queryItems = [
            URLQueryItem(name: "service", value: "youtube"),
            URLQueryItem(name: "continue", value: continueURL.absoluteString),
            URLQueryItem(name: "authuser", value: String(max(0, accountIndex))),
        ]
        return components.url!
    }

    // MARK: - Video-pane context menu + import panel

    /// Augment WebKit's default video context menu rather than replace it: keep
    /// the useful native items (Mute, Loop, Full Screen, PiP, …), drop the
    /// redundant "Show Controls" (YouTube has its own controls), and append
    /// Pomo's open-in-browser, hide, and account actions. Called from
    /// `DrawerWebView.willOpenMenu`, which is the path WebKit actually uses (an
    /// `NSView.rightMouseDown` override doesn't intercept web-content menus).
    func augmentVideoMenu(_ menu: NSMenu) {
        menu.items
            .filter {
                $0.identifier?.rawValue == "WKMenuItemIdentifierToggleVideoControls"
                    || $0.title.range(of: "controls", options: .caseInsensitive) != nil
            }
            .forEach { menu.removeItem($0) }

        menu.addItem(.separator())
        addItem(
            to: menu,
            drawerExpanded ? "Show Player" : "Show Page",
            #selector(ctxToggleFullPage),
            icon: drawerExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
        )
        addItem(to: menu, "Open in Browser", #selector(ctxOpenInBrowser), icon: "safari")
        menu.addItem(changeTrackItem())
        addItem(to: menu, "Hide Video", #selector(ctxHideVideo), icon: "eye.slash")
        menu.addItem(.separator())

        // Account: once you're signed in, Sign In / Import are irrelevant — show
        // who you are and a way out. Import is only an alternative sign-in path.
        if account.signedIn {
            let who = NSMenuItem(title: "Signed in\(account.name.map { " as \($0)" } ?? "")",
                                 action: nil, keyEquivalent: "")
            who.isEnabled = false
            who.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
            menu.addItem(who)
            addItem(to: menu, "Sign Out", #selector(ctxSignOut), icon: "rectangle.portrait.and.arrow.right")
        } else {
            addItem(to: menu, "Sign In to YouTube…", #selector(ctxSignIn), icon: "person.crop.circle.badge.plus")
            addItem(to: menu, "Import Login from Browser…", #selector(ctxImportLogin), icon: "key.horizontal")
        }
    }

    /// "Change Track ▸" — switch the player to one of your favorites without
    /// leaving the video. The current track is checked.
    private func changeTrackItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Change Track", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
        let sub = NSMenu()
        sub.autoenablesItems = false
        let favs = favorites?.items ?? []
        if favs.isEmpty {
            let none = NSMenuItem(title: "No favorites yet", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        } else {
            for fav in favs {
                let row = NSMenuItem(title: fav.title, action: #selector(ctxPlayFavorite(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = fav.url
                row.state = (fav.url == currentURL) ? .on : .off
                sub.addItem(row)
            }
        }
        item.submenu = sub
        return item
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, icon: String? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let icon {
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        }
        menu.addItem(item)
    }

    @objc private func ctxOpenInBrowser() { openInBrowser() }
    @objc private func ctxToggleFullPage() { setOriginalPageVisible(!drawerExpanded) }
    @objc private func ctxHideVideo() { setWindowVisible(false) }
    @objc private func ctxPlayFavorite(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? String else { return }
        play(urlString: url)
    }
    @objc private func ctxSignIn() { signIn() }
    @objc private func ctxSignOut() { clearLogin() }
    @objc private func ctxImportLogin() { showImportLogin() }

    /// A tiny, guided window for importing a browser login (see `CookieImportPanel`).
    func showImportLogin() {
        NSApp.setActivationPolicy(.regular)
        if let importLoginWindow {
            NSApp.activate(ignoringOtherApps: true)
            importLoginWindow.makeKeyAndOrderFront(nil)
            return
        }
        let view = CookieImportPanel(
            account: account,
            profiles: CookieImporter.detectedProfiles(),
            onImport: { [weak self] browser, profile, accountIndex in
                await self?.importLogin(fromBrowser: browser, profile: profile, accountIndex: accountIndex) ?? 0
            },
            onClose: { [weak self] in self?.importLoginWindow?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Import YouTube Login"
        window.styleMask = [.titled, .closable]
        // The panel draws its own titled header, so hide the window title (and
        // blend the titlebar into the content) to avoid showing it twice.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        importLoginWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Web view plumbing

    private func eval(_ js: String) { webView?.evaluateJavaScript(js, completionHandler: nil) }

    private func quietWebViewForRelease(_ webView: WKWebView, reason: String) {
        log("quieting web player (\(reason))")
        webView.evaluateJavaScript(Self.shutdownMediaJS, completionHandler: nil)
        webView.stopLoading()
        webView.load(URLRequest(url: Self.blankPageURL))
    }

    private func currentBrowserInstance() -> BrowserInstance? {
        guard let webView = webView as? DrawerWebView,
              let hostWindow,
              let navProxy,
              let messageProxy,
              let drawerContainer,
              let expandButton,
              let skipAdButton,
              let loadingView,
              let avatarView
        else { return nil }
        return BrowserInstance(
            webView: webView,
            hostWindow: hostWindow,
            navProxy: navProxy,
            messageProxy: messageProxy,
            drawerContainer: drawerContainer,
            expandButton: expandButton,
            skipAdButton: skipAdButton,
            loadingView: loadingView,
            avatarView: avatarView
        )
    }

    private func installBrowserInstance(_ instance: BrowserInstance) {
        hostWindow = instance.hostWindow
        webView = instance.webView
        navProxy = instance.navProxy
        messageProxy = instance.messageProxy
        drawerContainer = instance.drawerContainer
        expandButton = instance.expandButton
        skipAdButton = instance.skipAdButton
        loadingView = instance.loadingView
        avatarView = instance.avatarView
        avatarView?.image = account.avatar
        avatarView?.isHidden = !(account.signedIn && account.avatar != nil)
        applyDrawerCorners()
        updateExpandButton()
    }

    private func tearDownBrowserInstance(_ instance: BrowserInstance) {
        if let anchor = anchorWindow, instance.hostWindow.parent === anchor {
            anchor.removeChildWindow(instance.hostWindow)
        }
        instance.loadingView.stop()
        instance.webView.owner = nil
        quietWebViewForRelease(instance.webView, reason: "tearing down web player")
        instance.webView.navigationDelegate = nil
        instance.webView.configuration.userContentController.removeScriptMessageHandler(forName: "pomo")
        instance.hostWindow.contentView = nil
        instance.hostWindow.orderOut(nil)
    }

    private static func setVisualizerActiveJS(_ active: Bool) -> String {
        "window.__pomoVisualizerActive=\(active ? "true" : "false");"
    }

    private static func setAudioScopeFrameIntervalJS(_ milliseconds: Int) -> String {
        "window.__pomoScopeIntervalMs=\(max(33, min(500, milliseconds)));"
    }

    private static let suspendAudioScopeJS = """
    (function(){
      try {
        if (window.__pomoStopScope) {
          window.__pomoStopScope(false);
          return;
        }
        var hasPlayingMedia = false;
        Array.prototype.forEach.call(document.querySelectorAll('video,audio'), function(v){
          if (!v.paused && !v.ended) hasPlayingMedia = true;
          if (v.__pomoScopeTimer) {
            clearInterval(v.__pomoScopeTimer);
            v.__pomoScopeTimer = null;
          }
        });
        if (hasPlayingMedia) return;
        Array.prototype.forEach.call(document.querySelectorAll('video,audio'), function(v){
          try { if (v.__pomoScopeAnalyser) v.__pomoScopeAnalyser.disconnect(); } catch(e) {}
        });
        var ctx = window.__pomoAudioContext;
        if (ctx && ctx.state === 'running' && ctx.suspend) {
          var p = ctx.suspend();
          if (p && p.catch) p.catch(function(){});
        }
      } catch(e) {}
    })();
    """

    private static let pauseAndSuspendScopeJS = """
    (function(){
      var media = document.querySelector('video,audio');
      try { if (media) media.pause(); } catch(e) {}
      \(suspendAudioScopeJS)
    })();
    """

    private static let shutdownMediaJS = """
    (function(){
      window.__pomoVisualizerActive = false;
      try {
        if (window.__pomoStopScope) window.__pomoStopScope(true);
      } catch(e) {}
      Array.prototype.forEach.call(document.querySelectorAll('video,audio'), function(v){
        try { v.pause(); } catch(e) {}
        if (v.__pomoClockTimer) {
          clearInterval(v.__pomoClockTimer);
          v.__pomoClockTimer = null;
        }
        if (v.__pomoScopeTimer) {
          clearInterval(v.__pomoScopeTimer);
          v.__pomoScopeTimer = null;
        }
        try { v.removeAttribute('src'); } catch(e) {}
        try { v.src = ''; } catch(e) {}
        try { v.load(); } catch(e) {}
      });
      try {
        var ctx = window.__pomoAudioContext;
        window.__pomoAudioContext = null;
        if (ctx && ctx.state !== 'closed' && ctx.close) {
          var p = ctx.close();
          if (p && p.catch) p.catch(function(){});
        }
      } catch(e) {}
      window.__pomoSetupScope = null;
      window.__pomoStopScope = null;
    })();
    """

    /// Injected as a "content script": a user stylesheet that, while the
    /// `pomo-bare` class is on `<html>`, strips YouTube down to just the player +
    /// its transport controls. Toggling the class (see `applyBare`) flips between
    /// the bare screen and the full page with no reload.
    private static let bareScript = """
    (function(){
      var CSS = `
      html.pomo-bare, html.pomo-bare body { overflow:hidden!important; background:#000!important; }
      html.pomo-bare ytd-masthead, html.pomo-bare #masthead-container, html.pomo-bare #masthead,
      html.pomo-bare tp-yt-app-header, html.pomo-bare #secondary, html.pomo-bare #secondary-inner,
      html.pomo-bare #below, html.pomo-bare ytd-watch-metadata, html.pomo-bare #comments,
      html.pomo-bare #chat, html.pomo-bare ytmusic-nav-bar, html.pomo-bare #merch-shelf,
      html.pomo-bare ytd-watch-next-secondary-results-renderer { display:none!important; }
      html.pomo-bare #movie_player, html.pomo-bare .html5-video-player {
        position:fixed!important; inset:0!important; width:100vw!important; height:100vh!important;
        max-width:none!important; max-height:none!important; margin:0!important;
        z-index:2147483640!important; background:#000!important;
      }
      html.pomo-bare .html5-video-container { width:100%!important; height:100%!important; }
      html.pomo-bare video.html5-main-video {
        width:100%!important; height:100%!important; top:0!important; left:0!important; object-fit:cover!important;
      }
      html.pomo-bare .ytp-chrome-top, html.pomo-bare .ytp-gradient-top, html.pomo-bare .ytp-pause-overlay,
      html.pomo-bare .ytp-ce-element, html.pomo-bare .ytp-show-cards-title { display:none!important; }
      html.pomo-bare ::-webkit-scrollbar { display:none!important; }
      `;
      function inject(){
        var h = document.head || document.documentElement;
        if (h && !document.getElementById('pomo-skin')) {
          var s = document.createElement('style'); s.id = 'pomo-skin'; s.textContent = CSS; h.appendChild(s);
        }
        if (document.documentElement) document.documentElement.classList.add('pomo-bare');
      }
      inject();
      document.addEventListener('DOMContentLoaded', inject);
    })();
    """

    /// Prefer modest quality for the compact drawer to avoid media rebuffering
    /// when the user reveals the player from audio-only mode.
    private var videoQuality: String {
        if drawerExpanded { return "hd720" }
        return drawerOpen ? "medium" : "tiny"
    }

    private func scheduleVideoQualityRefresh(delay: TimeInterval) {
        videoQualityWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.applyVideoQuality()
            }
        }
        videoQualityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func applyVideoQuality() {
        let q = videoQuality
        eval("(function(){var mp=document.getElementById('movie_player');if(mp){try{mp.setPlaybackQuality&&mp.setPlaybackQuality('\(q)');}catch(e){}}})();")
    }

    private func seekTimestampSection(direction: Int) {
        log("timestamp section seek \(direction < 0 ? "previous" : "next")")
        let js = #"""
        (function(){
          var direction = \#(direction) < 0 ? -1 : 1;
          function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
          function player(){ return document.getElementById('movie_player'); }
          function media(){ return document.querySelector('video,audio'); }
          function duration(){
            var mp = player(), v = media();
            try { if (mp && mp.getDuration) return Number(mp.getDuration()) || 0; } catch(e){}
            return v && isFinite(v.duration) ? v.duration : 0;
          }
          function currentTime(){
            var mp = player(), v = media();
            try { if (mp && mp.getCurrentTime) return Number(mp.getCurrentTime()) || 0; } catch(e){}
            return v ? Number(v.currentTime) || 0 : 0;
          }
          function parseClock(text){
            var match = String(text || '').match(/\b(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\b/);
            if (!match) return null;
            var hours = match[1] == null ? 0 : Number(match[1]);
            return hours * 3600 + Number(match[2]) * 60 + Number(match[3]);
          }
          function parseTimeParam(value){
            if (!value) return null;
            value = String(value).trim().toLowerCase();
            if (/^\d+$/.test(value)) return Number(value);
            var total = 0, found = false, part;
            var re = /(\d+(?:\.\d+)?)(h|m|s)/g;
            while ((part = re.exec(value))) {
              found = true;
              var n = Number(part[1]);
              if (part[2] === 'h') total += n * 3600;
              if (part[2] === 'm') total += n * 60;
              if (part[2] === 's') total += n;
            }
            return found ? total : null;
          }
          function add(list, seconds){
            if (seconds == null) return;
            seconds = Number(seconds);
            var d = duration();
            if (!isFinite(seconds) || seconds < 0) return;
            if (d > 0 && seconds > d - 0.5) return;
            list.push(seconds);
          }
          function playerResponseChapters(list){
            var mp = player(), response;
            try { response = mp && mp.getPlayerResponse && mp.getPlayerResponse(); } catch(e){}
            var maps = response
              && response.playerOverlays
              && response.playerOverlays.playerOverlayRenderer
              && response.playerOverlays.playerOverlayRenderer.decoratedPlayerBarRenderer
              && response.playerOverlays.playerOverlayRenderer.decoratedPlayerBarRenderer.decoratedPlayerBarRenderer
              && response.playerOverlays.playerOverlayRenderer.decoratedPlayerBarRenderer.decoratedPlayerBarRenderer.playerBar
              && response.playerOverlays.playerOverlayRenderer.decoratedPlayerBarRenderer.decoratedPlayerBarRenderer.playerBar.multiMarkersPlayerBarRenderer
              && response.playerOverlays.playerOverlayRenderer.decoratedPlayerBarRenderer.decoratedPlayerBarRenderer.playerBar.multiMarkersPlayerBarRenderer.markersMap;
            if (!Array.isArray(maps)) return;
            maps.forEach(function(map){
              var chapters = map && map.value && map.value.chapters;
              if (!Array.isArray(chapters)) return;
              chapters.forEach(function(chapter){
                var start = chapter && chapter.chapterRenderer && chapter.chapterRenderer.timeRangeStartMillis;
                if (start != null) add(list, Number(start) / 1000);
              });
            });
          }
          function descriptionRoots(){
            var selectors = [
              'ytd-watch-metadata',
              '#description',
              '#description-inline-expander',
              'ytd-text-inline-expander',
              'ytd-expander',
              'yt-attributed-string',
              'ytmusic-description-shelf-renderer'
            ];
            var roots = [];
            selectors.forEach(function(selector){
              Array.prototype.forEach.call(document.querySelectorAll(selector), function(root){
                if (roots.indexOf(root) < 0) roots.push(root);
              });
            });
            return roots;
          }
          function addTimestampAnchor(list, anchor, includeText){
            var href = anchor.getAttribute('href') || '';
            try {
              var url = new URL(href, location.href);
              add(list, parseTimeParam(url.searchParams.get('t') || url.searchParams.get('start')));
            } catch(e){}
            if (includeText) {
              add(list, parseClock(anchor.textContent || anchor.getAttribute('aria-label') || ''));
            }
          }
          function timestampLinks(list){
            var roots = descriptionRoots();
            roots.forEach(function(root){
              Array.prototype.forEach.call(root.querySelectorAll('a[href]'), function(anchor){
                addTimestampAnchor(list, anchor, true);
              });
            });
            if (!roots.length) {
              Array.prototype.forEach.call(document.querySelectorAll('a[href*="t="],a[href*="start="]'), function(anchor){
                addTimestampAnchor(list, anchor, false);
              });
            }
          }
          function sectionStarts(){
            var list = [];
            playerResponseChapters(list);
            timestampLinks(list);
            return list
              .sort(function(a, b){ return a - b; })
              .filter(function(value, index, arr){ return index === 0 || Math.abs(value - arr[index - 1]) > 1; });
          }
          var starts = sectionStarts();
          if (!starts.length) { post('section-seek:none'); return; }
          var now = currentTime();
          var target = null;
          if (direction > 0) {
            target = starts.find(function(start){ return start > now + 2; });
          } else {
            for (var i = starts.length - 1; i >= 0; i--) {
              if (starts[i] < now - 3) { target = starts[i]; break; }
            }
          }
          if (target == null) { post('section-seek:edge'); return; }
          var mp = player(), v = media();
          try {
            if (mp && mp.seekTo) mp.seekTo(target, true);
            else if (v) v.currentTime = target;
            if (v && !v.paused) {
              var play = v.play();
              if (play && play.catch) play.catch(function(){});
            }
            post('section-seek:' + Math.round(target));
          } catch(e) {
            post('section-seek:error:' + e);
          }
        })();
        """#
        eval(js)
    }

    private func ensureWebView() {
        guard webView == nil else { return }
        if let prepared = preparedBrowser {
            preparedBrowser = nil
            log("using prepared web player")
            installBrowserInstance(prepared)
        } else {
            installBrowserInstance(makeBrowserInstance())
        }
    }

    private func makeBrowserInstance() -> BrowserInstance {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.websiteDataStore = .default()     // persistent cookies/login
        let messageProxy = MessageProxy(self)
        config.userContentController.add(messageProxy, name: "pomo")
        // Our "extension": strip the page to just the player while bare.
        config.userContentController.addUserScript(
            WKUserScript(source: Self.bareScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )

        let frame = NSRect(x: 0, y: 0, width: 360, height: 244)
        let wv = DrawerWebView(frame: frame, configuration: config)
        wv.owner = self
        wv.customUserAgent = Self.desktopUA
        WebKitInspectorMenu.enableInspection(on: wv)
        let navProxy = NavProxy(self)
        wv.navigationDelegate = navProxy

        // Rounded container clips the web view and hosts the expand button, so
        // the drawer reads as a screen tucked against the HUD. Per-corner
        // rounding (see applyDrawerCorners) squares the edge facing the HUD.
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.drawerRadius
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        wv.frame = container.bounds
        wv.autoresizingMask = [.width, .height]
        container.addSubview(wv)

        // Branded loading overlay — masks the cold YouTube player load.
        let loading = PomoLoadingView(frame: container.bounds)
        loading.autoresizingMask = [.width, .height]
        loading.alphaValue = 0
        container.addSubview(loading)

        // Corner overlay buttons, pinned top-right: open-in-browser, then expand.
        let bsize: CGFloat = 22, margin: CGFloat = 8, gap: CGFloat = 6
        let expand = Self.overlayButton(symbol: "arrow.up.left.and.arrow.down.right",
                                        tip: "Expand to full page", target: self, action: #selector(didTapExpand))
        expand.frame = NSRect(x: frame.width - bsize - margin, y: frame.height - bsize - margin, width: bsize, height: bsize)
        expand.autoresizingMask = [.minXMargin, .minYMargin]
        container.addSubview(expand)

        let browser = Self.overlayButton(symbol: "safari",
                                         tip: "Open in browser", target: self, action: #selector(didTapOpenInBrowser))
        browser.frame = NSRect(x: frame.width - bsize * 2 - margin - gap, y: frame.height - bsize - margin, width: bsize, height: bsize)
        browser.autoresizingMask = [.minXMargin, .minYMargin]
        container.addSubview(browser)

        let skipAd = Self.skipAdOverlayButton(target: self, action: #selector(didTapSkipAd))
        skipAd.frame = NSRect(x: frame.width - 92 - 12, y: 38, width: 92, height: 30)
        skipAd.autoresizingMask = [.minXMargin, .maxYMargin]
        skipAd.isHidden = true
        container.addSubview(skipAd)

        // Signed-in avatar, pinned top-left (the top-right corner is taken by the
        // open-in-browser / expand controls). Hidden until we know the identity.
        let avatarSize: CGFloat = 22
        let avatar = NSImageView(frame: NSRect(x: margin, y: frame.height - avatarSize - margin, width: avatarSize, height: avatarSize))
        avatar.wantsLayer = true
        avatar.layer?.cornerRadius = avatarSize / 2
        avatar.layer?.masksToBounds = true
        avatar.layer?.borderWidth = 1
        avatar.layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
        avatar.imageScaling = .scaleProportionallyUpOrDown
        avatar.autoresizingMask = [.maxXMargin, .minYMargin]
        avatar.isHidden = !(account.signedIn && account.avatar != nil)
        avatar.image = account.avatar
        avatar.toolTip = "Signed in to YouTube"
        container.addSubview(avatar)

        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Pomo Amp Video Player"
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.sharingType = .readOnly
        window.isExcludedFromWindowsMenu = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .participatesInCycle]
        window.contentView = container
        positionBottomRight(window)

        return BrowserInstance(
            webView: wv,
            hostWindow: window,
            navProxy: navProxy,
            messageProxy: messageProxy,
            drawerContainer: container,
            expandButton: expand,
            skipAdButton: skipAd,
            loadingView: loading,
            avatarView: avatar
        )
    }

    private func positionBottomRight(_ window: NSWindow) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24))
    }

    /// Injected after the watch page loads: find <video>, set volume, play, and
    /// report state. Retries because the element appears asynchronously.
    fileprivate func didFinishNavigation(for candidate: WKWebView) {
        guard candidate === webView else { return }
        let restoreSeekTime = pendingSeekTime ?? 0
        pendingSeekTime = nil
        log("navigation finished")
        let js = """
        (function(){
          function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
          var __pomoRestoreSeek = \(restoreSeekTime);
          var __pomoLastTitle = '';
          var __pomoTitleTick = 0;
          function cleanTitle(text){
            text = (text || '').toString().replace(/\\s+/g, ' ').trim();
            text = text.replace(/\\s+-\\s+YouTube(?:\\s+Music)?$/i, '');
            text = text.replace(/\\s+\\|\\s+YouTube(?:\\s+Music)?$/i, '');
            return text.trim();
          }
          function playerTitle(){
            var mp = document.getElementById('movie_player'), response, title = '';
            try { response = mp && mp.getPlayerResponse && mp.getPlayerResponse(); } catch(e){}
            try { title = response && response.videoDetails && response.videoDetails.title || ''; } catch(e){}
            if (!title) {
              var meta = document.querySelector('meta[property="og:title"],meta[name="title"]');
              title = meta && meta.getAttribute('content') || '';
            }
            if (!title) {
              var heading = document.querySelector('ytd-watch-metadata h1 yt-formatted-string, ytd-watch-metadata h1, h1.title, h1');
              title = heading && heading.textContent || '';
            }
            if (!title) title = document.title || '';
            return cleanTitle(title);
          }
          function reportTitle(){
            var title = playerTitle();
            if (!title || title === __pomoLastTitle) return;
            __pomoLastTitle = title;
            post('title:' + encodeURIComponent(title));
          }
          window.__pomoVisualizerActive = \(visualizerActive ? "true" : "false");
          window.__pomoScopeIntervalMs = \(audioScopeFrameIntervalMilliseconds);
          function restoreSeek(v, attempts){
            var target = Number(__pomoRestoreSeek) || 0;
            if (target <= 1 || !v) return;
            try {
              var duration = Number(v.duration) || 0;
              var clamped = duration > 2 ? Math.min(target, Math.max(0, duration - 1)) : target;
              if (Math.abs((Number(v.currentTime) || 0) - clamped) > 1.5) {
                v.currentTime = clamped;
              }
              if (duration > 0) {
                __pomoRestoreSeek = 0;
                post('seekrestore:' + Math.round(clamped));
                return;
              }
            } catch(e) {}
            if (attempts > 0) setTimeout(function(){ restoreSeek(v, attempts - 1); }, 450);
          }
          function go(n){
            var v = document.querySelector('video,audio');
            if (v) {
              try { v.volume = \(volume)/100.0; } catch(e){}
              restoreSeek(v, 12);
              function clock(){
                var duration = Number(v.duration);
                var payload = {
                  time: Number(v.currentTime) || 0,
                  duration: isFinite(duration) ? duration : 0,
                  paused: !!v.paused,
                  rate: Number(v.playbackRate) || 1,
                  ended: !!v.ended
                };
                post('clock:' + JSON.stringify(payload));
                __pomoTitleTick += 1;
                if (__pomoTitleTick % 4 === 0) reportTitle();
              }
              function setupScope(){
                if (!window.__pomoVisualizerActive) return;
                try {
                  var AudioContext = window.AudioContext || window.webkitAudioContext;
                  if (!AudioContext) { post('scopeerr:AudioContext unavailable'); return; }
                  var ctx = window.__pomoAudioContext;
                  if (!ctx) ctx = window.__pomoAudioContext = new AudioContext();
                  if (ctx.state === 'suspended') {
                    try {
                      var resume = ctx.resume && ctx.resume();
                      if (resume && resume.catch) resume.catch(function(e){ post('scopeerr:resume: ' + e); });
                    } catch(e) {}
                  }
                  if (!v.__pomoScopeAnalyser) {
                    var analyser = ctx.createAnalyser();
                    analyser.fftSize = 1024;
                    analyser.smoothingTimeConstant = 0.72;
                    var source = v.__pomoScopeSource;
                    if (!source) source = v.__pomoScopeSource = ctx.createMediaElementSource(v);
                    source.connect(analyser);
                    analyser.connect(ctx.destination);
                    v.__pomoScopeAnalyser = analyser;
                  } else {
                    try { v.__pomoScopeAnalyser.disconnect(); } catch(e) {}
                    try { v.__pomoScopeAnalyser.connect(ctx.destination); } catch(e) {}
                  }
                  var node = v.__pomoScopeAnalyser;
                  var freq = new Uint8Array(node.frequencyBinCount);
                  var wave = new Uint8Array(node.fftSize);
                  function compactFreq(values, count){
                    var out = [];
                    var max = Math.max(1, values.length - 1);
                    for (var i = 0; i < count; i++) {
                      var start = Math.floor(Math.pow(i / count, 1.65) * max);
                      var end = Math.max(start + 1, Math.floor(Math.pow((i + 1) / count, 1.65) * max));
                      var total = 0, n = 0;
                      for (var j = start; j <= end && j < values.length; j++) { total += values[j]; n++; }
                      out.push(n ? Math.round(total / n) : 0);
                    }
                    return out;
                  }
                  function compactWave(values, count){
                    var out = [];
                    var step = values.length / count;
                    for (var i = 0; i < count; i++) {
                      out.push(values[Math.min(values.length - 1, Math.floor(i * step))] || 128);
                    }
                    return out;
                  }
                  function tick(){
                    try {
                      node.getByteFrequencyData(freq);
                      node.getByteTimeDomainData(wave);
                      var duration = Number(v.duration);
                      post('scopeframe:' + JSON.stringify({
                        time: Number(v.currentTime) || 0,
                        duration: isFinite(duration) ? duration : 0,
                        paused: !!v.paused,
                        rate: Number(v.playbackRate) || 1,
                        ctxState: ctx.state || '',
                        bands: compactFreq(freq, 24),
                        waveform: compactWave(wave, 32)
                      }));
                    } catch(e) {
                      post('scopeerr:tick: ' + e);
                    }
                  }
                  if (v.__pomoScopeTimer) clearInterval(v.__pomoScopeTimer);
                  v.__pomoScopeTimer = setInterval(tick, Math.max(33, Math.min(500, Number(window.__pomoScopeIntervalMs) || 100)));
                  tick();
                  post('scope:started');
                } catch(e) {
                  post('scopeerr:' + ((e && e.name ? e.name + ': ' : '') + (e && e.message ? e.message : String(e))));
                }
              }
              function teardownScope(closeContext){
                if (v.__pomoScopeTimer) {
                  clearInterval(v.__pomoScopeTimer);
                  v.__pomoScopeTimer = null;
                }
                if (closeContext) {
                  try {
                    if (v.__pomoScopeSource) v.__pomoScopeSource.disconnect();
                  } catch(e) {}
                  try { if (v.__pomoScopeAnalyser) v.__pomoScopeAnalyser.disconnect(); } catch(e) {}
                  v.__pomoScopeAnalyser = null;
                  v.__pomoScopeSource = null;
                  var ctx = window.__pomoAudioContext;
                  window.__pomoAudioContext = null;
                  if (ctx && ctx.state !== 'closed' && ctx.close) {
                    var close = ctx.close();
                    if (close && close.catch) close.catch(function(){});
                  }
                } else {
                  if (!v.paused && !v.ended) return;
                  try { if (v.__pomoScopeAnalyser) v.__pomoScopeAnalyser.disconnect(); } catch(e) {}
                  var ctx = window.__pomoAudioContext;
                  if (ctx && ctx.state === 'running' && ctx.suspend) {
                    var suspend = ctx.suspend();
                    if (suspend && suspend.catch) suspend.catch(function(){});
                  }
                }
              }
              window.__pomoSetupScope = setupScope;
              window.__pomoStopScope = teardownScope;
              // Crisp while the drawer is on screen; lowest (audio-only) when
              // hidden. Audio is served independently, so it stays full quality.
              var mp = document.getElementById('movie_player');
              if (mp) {
                try { mp.setPlaybackQuality && mp.setPlaybackQuality('\(videoQuality)'); } catch(e){}
              }
              v.play().then(function(){ post('playing'); }).catch(function(e){ post('playfail:'+e); });
              if (!v.__pomo) {
                v.__pomo = true;
                v.addEventListener('playing', function(){ post('state:1'); });
                v.addEventListener('pause', function(){ post('state:2'); });
                v.addEventListener('ended', function(){ post('state:0'); });
                v.addEventListener('seeked', clock);
                v.addEventListener('ratechange', clock);
                v.addEventListener('durationchange', clock);
                v.addEventListener('timeupdate', clock);
                v.addEventListener('play', function(){ if (window.__pomoVisualizerActive) setupScope(); });
                v.addEventListener('playing', function(){ if (window.__pomoVisualizerActive) setupScope(); });
                v.__pomoClockTimer = setInterval(clock, 500);
              }
              clock();
              reportTitle();
              if (window.__pomoVisualizerActive) setupScope();
              else teardownScope(false);
              post('attached');
            } else if (n > 0) { setTimeout(function(){ go(n-1); }, 700); }
            else { post('no-video'); }
          }
          reportTitle();
          setTimeout(reportTitle, 500);
          setTimeout(reportTitle, 1500);
          go(10);
        })();
        """
        eval(js)
        applyBare(!drawerExpanded)        // a fresh navigation re-asserts the bare default
        eval(Self.accountJS)              // read the signed-in identity off the masthead
        eval(Self.timestampKeyJS)
        eval(Self.adSkipMonitorJS)
    }

    /// Reads the signed-in avatar (and best-effort name) from the YouTube /
    /// YT Music masthead, or detects the sign-in button. Retries since the
    /// masthead hydrates asynchronously.
    private static let accountJS = """
    (function(){
      function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
      function clean(s){ return (s || '').toString().replace(/[|]/g,' ').trim(); }
      function cfg(k){
        try { return window.ytcfg && window.ytcfg.get && window.ytcfg.get(k); }
        catch(e) { return undefined; }
      }
      function check(n){
        var loggedIn = cfg('LOGGED_IN');
        var cfgName = cfg('SESSION_USER_DISPLAY_NAME') || cfg('DELEGATED_SESSION_NAME') || '';
        var img = document.querySelector([
          '#avatar-btn img',
          'button#avatar-btn img',
          'ytd-topbar-menu-button-renderer img',
          'ytd-masthead #avatar-btn img',
          'ytmusic-settings-button img',
          'ytmusic-nav-bar img#right-content-icon',
          'a[href*="account"] img[src^="http"]',
          'button[aria-label*="Account"] img[src^="http"]',
          'img[src*="yt3.ggpht.com"]',
          'img[src*="googleusercontent.com"]'
        ].join(','));
        var accountButton = document.querySelector('#avatar-btn, button#avatar-btn, button[aria-label*="Account"], ytd-topbar-menu-button-renderer button');
        var signin = document.querySelector('a[href*="ServiceLogin"], a[href*="accounts.google.com"][aria-label], ytd-button-renderer#sign-in-button a, tp-yt-paper-button[aria-label*="Sign in"], a.sign-in-link, a[aria-label*="Sign in"], button[aria-label*="Sign in"]');
        if (img && img.src && img.src.indexOf('http') === 0) {
          post('account:1|' + clean(img.alt || img.getAttribute('aria-label') || cfgName) + '|' + img.src);
        } else if (loggedIn === true || loggedIn === 'true') {
          post('account:1|' + clean(cfgName || (accountButton && accountButton.getAttribute('aria-label'))) + '|');
        } else if (loggedIn === false || loggedIn === 'false' || signin) {
          post('account:0||');
        } else if (n > 0) {
          setTimeout(function(){ check(n - 1); }, 800);
        } else {
          post('account:?||');
        }
      }
      check(8);
    })();
    """

    private static let timestampKeyJS = """
    (function(){
      if (window.__pomoTimestampKeysInstalled) return;
      window.__pomoTimestampKeysInstalled = true;
      function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
      function editableTarget(target) {
        var el = target;
        while (el && el !== document.documentElement) {
          var tag = (el.tagName || '').toLowerCase();
          if (tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable) return true;
          el = el.parentElement;
        }
        return false;
      }
      document.addEventListener('keydown', function(event){
        if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return;
        if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
        if (editableTarget(event.target)) return;
        event.preventDefault();
        event.stopPropagation();
        post(event.key === 'ArrowRight' ? 'section-key:next' : 'section-key:previous');
      }, true);
    })();
    """

    private static let adSkipButtonSelectors = [
        ".ytp-ad-skip-button",
        ".ytp-ad-skip-button-modern",
        ".ytp-skip-ad-button",
        ".ytp-ad-skip-button-container button",
        "button[aria-label^='Skip']",
        "button[title^='Skip']"
    ]

    private static var adSkipButtonSelectorListJS: String {
        "[" + adSkipButtonSelectors.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    }

    private static let skipAdClickJS = """
    (function(){
      function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
      function visible(el){
        if (!el || el.disabled || el.getAttribute('aria-disabled') === 'true') return false;
        var style = window.getComputedStyle(el);
        if (!style || style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
        var rect = el.getBoundingClientRect();
        return rect.width > 2 && rect.height > 2;
      }
      var selectors = \(WebAudioPlayer.adSkipButtonSelectorListJS);
      for (var i = 0; i < selectors.length; i++) {
        var nodes = document.querySelectorAll(selectors[i]);
        for (var j = 0; j < nodes.length; j++) {
          if (visible(nodes[j])) {
            nodes[j].click();
            post('adskip:clicked');
            return true;
          }
        }
      }
      post('adskip:0');
      return false;
    })();
    """

    private static let adSkipMonitorJS = """
    (function(){
      if (window.__pomoAdSkipMonitorInstalled) return;
      window.__pomoAdSkipMonitorInstalled = true;
      function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
      var selectors = \(WebAudioPlayer.adSkipButtonSelectorListJS);
      var last = null;
      function visible(el){
        if (!el || el.disabled || el.getAttribute('aria-disabled') === 'true') return false;
        var style = window.getComputedStyle(el);
        if (!style || style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
        var rect = el.getBoundingClientRect();
        return rect.width > 2 && rect.height > 2;
      }
      function hasSkipButton(){
        for (var i = 0; i < selectors.length; i++) {
          var nodes = document.querySelectorAll(selectors[i]);
          for (var j = 0; j < nodes.length; j++) {
            if (visible(nodes[j])) return true;
          }
        }
        return false;
      }
      function check(){
        var next = hasSkipButton();
        if (next !== last) {
          last = next;
          post(next ? 'adskip:1' : 'adskip:0');
        }
      }
      check();
      setInterval(check, 300);
      try {
        new MutationObserver(check).observe(document.documentElement || document.body, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['class', 'style', 'hidden', 'disabled', 'aria-disabled', 'aria-label', 'title']
        });
      } catch(e) {}
    })();
    """

    fileprivate func handlePlayerEvent(_ body: Any) {
        let message = "\(body)"
        if message.hasPrefix("clock:") {
            handleMediaClock(String(message.dropFirst("clock:".count)))
            return
        }
        if message.hasPrefix("scopeframe:") {
            handleAudioScopeFrame(String(message.dropFirst("scopeframe:".count)))
            return
        }
        if message.hasPrefix("scopeerr:") {
            handleAudioScopeError(String(message.dropFirst("scopeerr:".count)))
            return
        }
        if message.hasPrefix("title:") {
            handleMediaTitle(String(message.dropFirst("title:".count)))
            return
        }
        if message == "scope:started" {
            log("scope started")
            return
        }
        if message.hasPrefix("adskip:") {
            setSkipAdAvailable(message == "adskip:1")
            return
        }
        if message == "adskip:clicked" {
            setSkipAdAvailable(false)
            return
        }
        log("event: \(message)")
        if message.hasPrefix("account:") {
            handleAccount(String(message.dropFirst("account:".count)))
            return
        }
        if message == "section-key:next" {
            nextTimestampSection()
            return
        }
        if message == "section-key:previous" {
            previousTimestampSection()
            return
        }
        if message.contains("state:1") || message == "playing" {
            isPlaying = true
            showLoading(false)          // video is rendering — reveal it
        }
        if message.contains("state:2") || message.contains("state:0")
            || message.hasPrefix("playfail") || message == "no-video" {
            isPlaying = false
            if message.hasPrefix("playfail") || message == "no-video" { showLoading(false) }
            if message.contains("state:0") {
                completePendingThresholdPurge(at: "track boundary")
                completePreparedBrowserSwap(at: "track boundary")
            }
        }
        onStateChange?()
    }

    private func setSkipAdAvailable(_ available: Bool) {
        guard let skipAdButton else { return }
        skipAdButton.isHidden = !available
    }

    private func handleMediaTitle(_ encodedTitle: String) {
        let decoded = encodedTitle.removingPercentEncoding ?? encodedTitle
        let clean = Self.cleanMediaTitle(decoded)
        guard !clean.isEmpty, clean != currentTitle else { return }
        currentTitle = clean
        persistPlaybackSnapshot(force: true)
        onStateChange?()
    }

    private static func cleanMediaTitle(_ raw: String) -> String {
        var title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }
        for suffix in [" - YouTube Music", " - YouTube", " | YouTube Music", " | YouTube"] {
            if title.lowercased().hasSuffix(suffix.lowercased()) {
                title = String(title.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return title
    }

    private func persistPlaybackSnapshot(force: Bool = false, wasPlaying override: Bool? = nil) {
        guard !currentURL.isEmpty else { return }
        let hostTime = ProcessInfo.processInfo.systemUptime
        if !force, hostTime - lastPlaybackSnapshotHostTime < 2.0 { return }
        lastPlaybackSnapshotHostTime = hostTime

        let snapshot = PlaybackSnapshot(
            url: currentURL,
            title: currentTitle,
            time: estimatedMediaTime(at: hostTime),
            duration: mediaDuration,
            wasPlaying: override ?? isPlaying,
            updatedAt: Date().timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.playbackSnapshotKey)
    }

    private static func loadPlaybackSnapshot() -> PlaybackSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: playbackSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(PlaybackSnapshot.self, from: data)
    }

    private static func clearPlaybackSnapshot() {
        UserDefaults.standard.removeObject(forKey: playbackSnapshotKey)
    }

    private func handleMediaClock(_ json: String) {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        mediaTime = max(0, payload["time"] as? Double ?? mediaTime)
        mediaDuration = max(0, payload["duration"] as? Double ?? mediaDuration)
        mediaPlaybackRate = max(0, payload["rate"] as? Double ?? mediaPlaybackRate)
        mediaPaused = payload["paused"] as? Bool ?? mediaPaused
        mediaClockHostTime = ProcessInfo.processInfo.systemUptime
        persistPlaybackSnapshot(wasPlaying: !mediaPaused && isPlaying)
    }

    private func handleAudioScopeFrame(_ json: String) {
        guard visualizerActive else { return }
        guard let data = json.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let hostTime = ProcessInfo.processInfo.systemUptime
        let rawBands = Self.numberArray(payload["bands"])
        let rawWaveform = Self.numberArray(payload["waveform"])
        let bands = rawBands.map { Self.clamp($0 / 255, 0, 1) }
        let waveform = rawWaveform.map { Self.clamp(($0 - 128) / 128, -1, 1) }
        let rms = sqrt(Self.average(waveform.map { $0 * $0 }))
        let peak = waveform.map { abs($0) }.max() ?? 0

        let frame = AudioScopeFrame(
            source: "webAudio",
            hostTime: hostTime,
            mediaTime: max(0, Self.double(payload["time"], fallback: estimatedMediaTime(at: hostTime))),
            duration: max(0, Self.double(payload["duration"], fallback: mediaDuration)),
            playbackRate: max(0, Self.double(payload["rate"], fallback: mediaPlaybackRate)),
            bands: bands,
            waveform: waveform,
            rms: Self.clamp(rms, 0, 1),
            peak: Self.clamp(peak, 0, 1),
            low: Self.average(bands.prefix(6)),
            mid: Self.average(bands.dropFirst(6).prefix(9)),
            high: Self.average(bands.dropFirst(15))
        )

        let silent = frame.peak < 0.003 && frame.rms < 0.002 && frame.bands.allSatisfy { $0 < 0.002 }
        if isPlaying, !mediaPaused, frame.mediaTime > 1.0, silent {
            silentScopeFrames += 1
            nonSilentScopeFrames = 0
            if silentScopeFrames > 30 {
                startNativeAudioScope(reason: "web audio analyser silent")
                if hasFreshNativeAudioScope(at: hostTime) {
                    return
                }
                audioScope = frame
                if audioScopeError != Self.nativeAudioScopePermissionMessage {
                    audioScopeError = "analyser is silent, using Core Audio tap fallback"
                }
            } else {
                audioScope = frame
            }
        } else {
            let hasNativeFallback = nativeAudioScope.isActive || hasFreshNativeAudioScope(at: hostTime)
            if hasNativeFallback {
                nonSilentScopeFrames += 1
                if nonSilentScopeFrames <= 12, hasFreshNativeAudioScope(at: hostTime) {
                    return
                }
            } else {
                nonSilentScopeFrames = 0
            }
            audioScope = frame
            silentScopeFrames = 0
            audioScopeError = nil
            if nonSilentScopeFrames > 12 || !hasNativeFallback {
                stopNativeAudioScope()
            }
        }
    }

    private func handleAudioScopeError(_ error: String) {
        guard visualizerActive else { return }
        let cleaned = error.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = cleaned.isEmpty ? "audio analyser unavailable" : cleaned
        if audioScopeError != message {
            log("scope error: \(message)")
        }
        audioScopeError = message
        audioScope = nil
        silentScopeFrames = 0
        nonSilentScopeFrames = 0
        startNativeAudioScope(reason: message)
    }

    private func resetAudioScope(error: String? = nil) {
        audioScope = nil
        audioScopeError = error
        silentScopeFrames = 0
        nonSilentScopeFrames = 0
    }

    private func startAudioScopeFreshnessWatchdog() {
        let timer = Timer(timeInterval: Self.audioScopeFreshnessCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.audioScopeFreshnessTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        audioScopeFreshnessTimer = timer
    }

    private func audioScopeFreshnessTick() {
        guard visualizerActive, isPlaying, !mediaPaused else { return }
        let hostTime = ProcessInfo.processInfo.systemUptime

        guard let scope = audioScope else {
            if audioScopeError == nil, mediaTime > 1.0 {
                startNativeAudioScope(reason: "missing audio scope")
            }
            return
        }

        let maxAge = scope.source == CoreAudioTapAudioScope.sourceName
            ? Self.nativeAudioScopeFreshnessSeconds
            : Self.webAudioScopeFreshnessSeconds
        let age = hostTime - scope.hostTime
        guard age > maxAge else { return }

        if scope.source == CoreAudioTapAudioScope.sourceName {
            restartNativeAudioScope(reason: "stale Core Audio tap scope (\(Int(age * 1000))ms)")
        } else {
            log("audio scope stale from \(scope.source); starting Core Audio tap fallback (\(Int(age * 1000))ms)")
            audioScope = nil
            startNativeAudioScope(reason: "stale \(scope.source) audio scope")
        }
    }

    private func startNativeAudioScope(reason: String, userInitiated: Bool = false) {
        guard visualizerActive || userInitiated else { return }
        guard isPlaying else { return }
        guard !nativeAudioScope.isActive else { return }
        if userInitiated {
            ScreenCaptureAudioPermission.registerPermissionTarget(reason: reason)
            Self.recordNativeAudioScopeUserIntent()
            nativeAudioScopeEnabledForSession = true
        } else if !nativeAudioScopeEnabledForSession {
            if Self.shouldAutoStartNativeAudioScope() {
                nativeAudioScopeEnabledForSession = true
            } else {
                noteNativeAudioScopePermissionNeeded(reason: reason)
                return
            }
        }
        if !nativeAudioScopeEnabledForSession {
            noteNativeAudioScopePermissionNeeded(reason: reason)
            return
        }
        let hostTime = ProcessInfo.processInfo.systemUptime
        guard hostTime >= nativeAudioScopeSuppressedUntil else { return }
        log("starting Core Audio tap scope (\(reason))")
        nativeAudioScope.start()
    }

    private func noteNativeAudioScopePermissionNeeded(reason: String) {
        let changed = audioScopeError != Self.nativeAudioScopePermissionMessage
        audioScopeError = Self.nativeAudioScopePermissionMessage
        if changed {
            log("Core Audio tap permission needed (\(reason)); waiting for explicit visualizer enable")
            onStateChange?()
        }
    }

    private func stopNativeAudioScope() {
        nativeAudioScopeRestartWork?.cancel()
        nativeAudioScopeRestartWork = nil
        guard nativeAudioScope.isActive else { return }
        log("stopping Core Audio tap scope")
        nativeAudioScope.stop()
    }

    private func restartNativeAudioScope(reason: String) {
        guard nativeAudioScopeRestartWork == nil else { return }
        guard isPlaying else { return }
        let hostTime = ProcessInfo.processInfo.systemUptime
        guard hostTime - lastNativeAudioScopeRestartHostTime > 1.5 else { return }
        lastNativeAudioScopeRestartHostTime = hostTime

        log("restarting Core Audio tap scope (\(reason))")
        audioScope = nil
        audioScopeError = nil
        nativeAudioScope.stop()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.nativeAudioScopeRestartWork = nil
            self.startNativeAudioScope(reason: reason)
        }
        nativeAudioScopeRestartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func hasFreshNativeAudioScope(at hostTime: Double) -> Bool {
        guard let audioScope,
              audioScope.source == CoreAudioTapAudioScope.sourceName
        else { return false }
        return hostTime - audioScope.hostTime <= Self.nativeAudioScopeFreshnessSeconds
    }

    private func handleNativeAudioScopeFrame(_ frame: AudioScopeFrame) {
        guard visualizerActive else {
            stopNativeAudioScope()
            return
        }
        let hostTime = ProcessInfo.processInfo.systemUptime
        var frame = frame
        frame.hostTime = hostTime
        frame.mediaTime = estimatedMediaTime(at: hostTime)
        frame.duration = mediaDuration
        frame.playbackRate = mediaPlaybackRate
        audioScope = frame
        audioScopeError = nil
        nativeAudioScopeSuppressedUntil = 0
        nativeAudioScopeEnabledForSession = true
        if !nativeAudioScopeRecordedSuccessfulAccess {
            Self.recordSuccessfulNativeAudioScopeAccessForCurrentExecutable()
            nativeAudioScopeRecordedSuccessfulAccess = true
            ScreenCaptureAudioPermission.recordSuccessfulAccess()
        }
        nonSilentScopeFrames = 0
    }

    private func handleNativeAudioScopeError(_ error: String?) {
        guard let error, !error.isEmpty else { return }
        if audioScopeError != error {
            log("scope error: \(error)")
        }
        if !hasFreshNativeAudioScope(at: ProcessInfo.processInfo.systemUptime) {
            audioScopeError = error
        }
        if Self.isAudioCapturePermissionError(error) {
            let alreadyAllowed = nativeAudioScopeEnabledForSession || Self.hasSuccessfulNativeAudioScopeAccessForCurrentExecutable()
            nativeAudioScopeEnabledForSession = false
            nativeAudioScopeRecordedSuccessfulAccess = false
            Self.clearSuccessfulNativeAudioScopeAccess()
            nativeAudioScopeSuppressedUntil = ProcessInfo.processInfo.systemUptime + (alreadyAllowed ? 180 : 30)
            audioScopeError = alreadyAllowed ? "system audio capture unavailable" : Self.nativeAudioScopePermissionMessage
            audioScope = nil
            silentScopeFrames = 0
            nonSilentScopeFrames = 0
            if !alreadyAllowed {
                ScreenCaptureAudioPermission.showAssistant(startRequest: false)
            }
            return
        }
        let lowercased = error.lowercased()
        let isRecoverableCaptureStop = lowercased.contains("stopped")
            || lowercased.contains("stalled")
            || lowercased.contains("no samples")
        if isPlaying,
           lowercased.contains("core audio tap"),
           isRecoverableCaptureStop {
           restartNativeAudioScope(reason: error)
        }
    }

    private static func isAudioCapturePermissionError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("permission")
            || lowercased.contains("not authorized")
            || lowercased.contains("not authorised")
            || lowercased.contains("not permitted")
            || lowercased.contains("not allowed")
            || lowercased.contains("denied")
            || lowercased.contains("declined")
            || lowercased.contains("tcc")
    }

    private static func shouldAutoStartNativeAudioScope() -> Bool {
        hasSuccessfulNativeAudioScopeAccessForCurrentExecutable()
            || (canStartNativeAudioScopeWithoutPrompt() && hasNativeAudioScopeUserIntent())
    }

    private static func canStartNativeAudioScopeWithoutPrompt() -> Bool {
        ScreenCaptureAudioPermission.systemReportsAccess
    }

    private static func hasNativeAudioScopeUserIntent() -> Bool {
        UserDefaults.standard.bool(forKey: nativeAudioScopeUserEnabledKey)
    }

    private static func recordNativeAudioScopeUserIntent() {
        UserDefaults.standard.set(true, forKey: nativeAudioScopeUserEnabledKey)
    }

    private static func hasSuccessfulNativeAudioScopeAccessForCurrentExecutable() -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: nativeAudioScopeExecutableFingerprintKey),
              let current = currentExecutableFingerprint()
        else { return false }
        return stored == current
    }

    private static func recordSuccessfulNativeAudioScopeAccessForCurrentExecutable() {
        guard let fingerprint = currentExecutableFingerprint() else { return }
        UserDefaults.standard.set(fingerprint, forKey: nativeAudioScopeExecutableFingerprintKey)
        recordNativeAudioScopeUserIntent()
    }

    private static func clearSuccessfulNativeAudioScopeAccess() {
        UserDefaults.standard.removeObject(forKey: nativeAudioScopeExecutableFingerprintKey)
        UserDefaults.standard.removeObject(forKey: nativeAudioScopeUserEnabledKey)
    }

    private static func currentExecutableFingerprint() -> String? {
        guard let executableURL = Bundle.main.executableURL,
              let data = try? Data(contentsOf: executableURL, options: .mappedIfSafe)
        else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func numberArray(_ value: Any?) -> [Double] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { double($0, fallback: .nan) }.filter { $0.isFinite }
    }

    private static func double(_ value: Any?, fallback: Double) -> Double {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let value = value as? Double {
            return value
        }
        if let value = value as? String, let number = Double(value) {
            return number
        }
        return fallback
    }

    private static func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        var total = 0.0
        var count = 0.0
        for value in values {
            total += value
            count += 1
        }
        return count > 0 ? total / count : 0
    }

    private static func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    fileprivate func handleDrawerKeyDown(_ event: NSEvent) -> Bool {
        guard drawerOpen, !drawerExpanded else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.subtracting([.shift, .numericPad, .function]).isEmpty else { return false }
        switch event.keyCode {
        case 123:
            previousTimestampSection()
            return true
        case 124:
            nextTimestampSection()
            return true
        default:
            return false
        }
    }

    // MARK: - Loading overlay (branded shimmer over the cold YouTube load)

    /// A fresh main-frame navigation started — if the drawer is on screen, cover
    /// it with the branded shimmer until the player reports it's rendering.
    fileprivate func navigationStarted(for candidate: WKWebView) {
        guard candidate === webView else { return }
        if drawerOpen { showLoading(true) }
    }

    private func showLoading(_ show: Bool) {
        guard let loading = loadingView else { return }
        loadingHideWork?.cancel()
        loadingHideWork = nil
        if show {
            loading.start()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                loading.animator().alphaValue = 1
            }
            // Never let the shimmer outstay the load.
            let work = DispatchWorkItem { [weak self] in self?.showLoading(false) }
            loadingHideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: work)
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                loading.animator().alphaValue = 0
            }, completionHandler: { [weak loading] in loading?.stop() })
        }
    }

    // MARK: - Account identity

    private func handleAccount(_ payload: String) {
        let parts = payload.components(separatedBy: "|")
        guard parts.first != "?" else { return }
        let signedIn = parts.first == "1"
        let name = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        let avatarURL = parts.count > 2 ? parts[2] : ""

        account.signedIn = signedIn
        account.name = name.isEmpty ? nil : name
        if signedIn {
            if !avatarURL.isEmpty { loadAvatar(avatarURL) }
        } else {
            account.avatar = nil
            avatarView?.image = nil
            avatarView?.isHidden = true
        }
        onStateChange?()
    }

    private func loadAvatar(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            Task { @MainActor in
                guard let self else { return }
                self.account.avatar = image
                self.avatarView?.image = image
                self.avatarView?.isHidden = !self.account.signedIn
                self.onStateChange?()
            }
        }.resume()
    }

    private func log(_ line: String) {
        let entry = "[pomo-webaudio] \(line)\n"
        FileHandle.standardError.write(entry.data(using: .utf8) ?? Data())
        if let data = entry.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/pomo-webaudio.log")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else { try? data.write(to: url) }
        }
    }

    // MARK: - URL helpers

    /// Normalise to a playable URL. YouTube Music links load as-is (the YT Music
    /// app, which has radio/next); plain YouTube/youtu.be/bare-id → watch URL.
    static func isPlayableSource(_ raw: String) -> Bool {
        watchURL(from: raw) != nil
    }

    private static func watchURL(from raw: String) -> URL? {
        let normalized = normalizedSource(raw)
        let host = URLComponents(string: normalized)?.host ?? ""
        if host.contains("music.youtube.com") { return URL(string: normalized) }
        if let id = youTubeID(from: normalized) { return URL(string: "https://www.youtube.com/watch?v=\(id)") }
        guard let url = URL(string: normalized), url.scheme != nil else { return nil }
        return url
    }

    private static func normalizedSource(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("youtube.com/")
            || lower.hasPrefix("www.youtube.com/")
            || lower.hasPrefix("m.youtube.com/")
            || lower.hasPrefix("music.youtube.com/")
            || lower.hasPrefix("youtu.be/") {
            return "https://\(trimmed)"
        }
        return trimmed
    }

    /// Append Google's `authuser=N` so multi-login picks the right account.
    private static func withAuthUser(_ url: URL, _ index: Int) -> URL {
        guard index > 0, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "authuser" }
        items.append(URLQueryItem(name: "authuser", value: String(index)))
        comps.queryItems = items
        return comps.url ?? url
    }

    static func youTubeID(from string: String) -> String? {
        let normalized = normalizedSource(string)
        if let comps = URLComponents(string: normalized) {
            let host = comps.host ?? ""
            if host.contains("youtu.be") {
                let id = comps.path.split(separator: "/").first.map(String.init)
                if let id, isID(id) { return id }
            }
            if host.contains("youtube.com") {
                if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, isID(v) { return v }
                let parts = comps.path.split(separator: "/").map(String.init)
                if let idx = parts.firstIndex(where: { ["embed", "live", "shorts", "v"].contains($0) }),
                   idx + 1 < parts.count, isID(parts[idx + 1]) { return parts[idx + 1] }
            }
        }
        return isID(normalized) ? normalized : nil
    }

    private static func isID(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }

    /// JS that clicks the first matching selector (for next/prev across surfaces).
    private static func clickJS(_ selectors: [String]) -> String {
        let list = selectors.map { "'\($0)'" }.joined(separator: ",")
        return "(function(){var s=[\(list)];for(var i=0;i<s.length;i++){var e=document.querySelector(s[i]);if(e){e.click();return;}}})();"
    }
}

extension WebAudioPlayer: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let window = notification.object as? NSWindow
        if window === signInWindow {
            signInWindow = nil
            NSApp.setActivationPolicy(.accessory)
            // The account is read off the *player's* page, not the sign-in
            // window, so reload the player to pick up the freshly-signed-in
            // session (otherwise a web sign-in never registers in the app).
            reloadForLogin()
        } else if window === importLoginWindow {
            importLoginWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: WebAudioPlayer?
    init(_ owner: WebAudioPlayer) { self.owner = owner }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        Task { @MainActor in self.owner?.handlePlayerEvent(body) }
    }
}

private final class NavProxy: NSObject, WKNavigationDelegate {
    weak var owner: WebAudioPlayer?
    init(_ owner: WebAudioPlayer) { self.owner = owner }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in self.owner?.navigationStarted(for: webView) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.owner?.didFinishNavigation(for: webView) }
    }
}

/// The drawer's video pane. Right-clicking augments WebKit's native video menu
/// with Pomo's account + open/hide actions (see `augmentVideoMenu`). We hook
/// `willOpenMenu` rather than `rightMouseDown` because WebKit builds the
/// web-content menu through the former; a `rightMouseDown` override is bypassed.
final class DrawerWebView: WKWebView {
    weak var owner: WebAudioPlayer?

    override func keyDown(with event: NSEvent) {
        if MainActor.assumeIsolated({ owner?.handleDrawerKeyDown(event) ?? false }) { return }
        super.keyDown(with: event)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        MainActor.assumeIsolated {
            owner?.augmentVideoMenu(menu)
        }
        WebKitInspectorMenu.addOpenInspectorItem(to: menu, webView: self)
    }
}
