import WebKit
import AppKit
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

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var navProxy: NavProxy?          // retained — navigationDelegate is weak
    private var messageProxy: MessageProxy?
    private var signInWindow: NSWindow?
    private var importLoginWindow: NSWindow?

    private(set) var isPlaying = false
    private(set) var currentURL: String = ""
    private var volume: Int = 60

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
    private var loadingView: PomoLoadingView?
    private var loadingHideWork: DispatchWorkItem?
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
        let loadingView: PomoLoadingView
        let avatarView: NSImageView
    }

    /// Fired when playback state changes (from JS player events).
    var onStateChange: (() -> Void)?

    /// Keeps the on-disk cookie backup in sync, and coalesces the writes so a
    /// burst of cookie changes during a page load only persists once.
    private var cookieObserver: CookieStoreObserver?
    private var cookieSaveWork: DispatchWorkItem?

    override init() {
        super.init()
        // Re-seed any login saved on disk into the shared store, then keep that
        // backup current as cookies change — so login survives relaunches and
        // even a switch between the dev build and the installed release.
        restoreSavedLogin()
        startCookiePersistence()
    }

    // MARK: - Playback

    /// Google multi-login account index (0 = default). Persisted so the chosen
    /// account sticks across relaunches.
    private var authUser: Int {
        get { UserDefaults.standard.integer(forKey: "pomo.audio.authUser") }
        set { UserDefaults.standard.set(max(0, newValue), forKey: "pomo.audio.authUser") }
    }

    func play(urlString raw: String) {
        let urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, let base = Self.watchURL(from: urlString) else { return }
        let url = Self.withAuthUser(base, authUser)
        cancelIdleMemoryPurge()
        cancelBoundaryMemoryPurge()
        cancelPreparedBrowserSwap()
        currentURL = urlString
        ensureWebView()
        log("play \(url.absoluteString)")
        webView?.load(URLRequest(url: url))
        isPlaying = true
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
            play(urlString: url)
            return
        }
        eval("document.querySelector('video,audio')&&document.querySelector('video,audio').play();")
        isPlaying = true
    }

    func pause() {
        eval("document.querySelector('video,audio')&&document.querySelector('video,audio').pause();")
        isPlaying = false
        scheduleIdleMemoryPurge(reason: "paused audio")
    }

    func stop() {
        webView?.load(URLRequest(url: URL(string: "about:blank")!))
        currentURL = ""
        isPlaying = false
        setWindowVisible(false)
        scheduleIdleMemoryPurge(reason: "stopped audio")
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(100, Int((value * 100).rounded())))
        eval("var v=document.querySelector('video,audio'); if(v){v.volume=\(volume)/100.0;}")
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

    // MARK: - Attached video drawer

    /// Reflects user intent (not raw window visibility) so the on-face toggle
    /// stays correct even mid-animation.
    var isWindowVisible: Bool { drawerOpen }

    /// Show/hide the drawer with a slide animation. Opening lazily builds the
    /// web view if it doesn't exist yet.
    func setWindowVisible(_ visible: Bool) {
        drawerOpen = visible
        if visible {
            cancelIdleMemoryPurge()
            cancelPreparedBrowserSwap()
            ensureWebView()
            openDrawer()
        } else {
            closeDrawer()
            scheduleIdleMemoryPurge(reason: "hidden video drawer")
        }
    }

    func toggleWindow() { setWindowVisible(!drawerOpen) }

    /// The HUD appeared: anchor to it and, if the drawer was open, slide it back
    /// out alongside the (possibly repositioned) panel.
    func hudDidAppear(anchor: NSWindow?) {
        anchorWindow = anchor
        if drawerOpen { openDrawer() }
    }

    /// The HUD is hiding: tuck the drawer away with it, keeping the open intent
    /// so it returns on the next summon.
    func hudWillDisappear() {
        guard let host = hostWindow else { return }
        if let anchor = anchorWindow, host.parent === anchor { anchor.removeChildWindow(host) }
        host.orderOut(nil)
        host.alphaValue = 1
    }

    /// Switch between the original YouTube page (comments/details/account UI)
    /// and the chrome-stripped player view that matches the HUD.
    func setExpanded(_ on: Bool) {
        guard drawerOpen, let host = hostWindow, let anchor = anchorWindow else { return }
        drawerExpanded = on
        applyBare(!on)                      // bare (chrome hidden) only when collapsed
        applyDrawerCorners()
        updateExpandButton()
        let a = anchor.frame
        let screen = (anchor.screen ?? NSScreen.main)?.visibleFrame ?? a
        let open = openFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a, screen: screen)
        if host.parent === anchor { anchor.removeChildWindow(host) }
        host.order(.below, relativeTo: anchor.windowNumber)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.26
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            host.animator().setFrame(open, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let host = self.hostWindow, let anchor = self.anchorWindow,
                      self.drawerOpen, host.parent !== anchor else { return }
                anchor.addChildWindow(host, ordered: .below)
            }
        })
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

    // MARK: - Drawer geometry + slide animation

    /// First edge (right → left → below → above) with room for the collapsed
    /// drawer beside the HUD.
    private func chooseEdge(_ a: NSRect, _ screen: NSRect) -> DrawerEdge {
        let sideW = collapsedSize(.right).width, vertH = collapsedSize(.below).height
        if a.maxX - seam + sideW <= screen.maxX { return .right }
        if a.minX + seam - sideW >= screen.minX { return .left }
        if a.minY + seam - vertH >= screen.minY { return .below }
        if a.maxY - seam + vertH <= screen.maxY { return .above }
        return .right
    }

    private static let seamOverlap: CGFloat = 2     // hairline tuck so no desktop shows through
    private var seam: CGFloat { Self.seamOverlap }

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
        drawerExpanded ? expandedSize(edge, hud: hud) : collapsedSize(edge, hud: hud)
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

    /// The collapsed open frame shifted fully behind the HUD along the slide axis.
    private func tuckedFrame(_ open: NSRect, edge: DrawerEdge) -> NSRect {
        switch edge {
        case .right: return open.offsetBy(dx: -open.width, dy: 0)
        case .left:  return open.offsetBy(dx:  open.width, dy: 0)
        case .below: return open.offsetBy(dx: 0, dy:  open.height)
        case .above: return open.offsetBy(dx: 0, dy: -open.height)
        }
    }

    /// Slide the drawer out from behind the HUD, then adopt it as a child window
    /// so it tracks the panel when dragged.
    private func openDrawer() {
        guard let host = hostWindow else { return }
        guard let anchor = anchorWindow else { host.orderFrontRegardless(); return }
        let a = anchor.frame
        let screen = (anchor.screen ?? NSScreen.main)?.visibleFrame ?? a
        drawerEdge = chooseEdge(a, screen)
        applyDrawerCorners()
        applyBare(!drawerExpanded)
        applyVideoQuality()              // bump if it was playing audio-only at low res

        let collapsedOpen = drawerFrame(size: collapsedSize(drawerEdge, hud: a), edge: drawerEdge, anchor: a)
        let open = openFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a, screen: screen)
        host.setFrame(tuckedFrame(collapsedOpen, edge: drawerEdge), display: false)
        host.alphaValue = 0
        host.order(.below, relativeTo: anchor.windowNumber)        // emerge from behind
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            host.animator().setFrame(open, display: true)
            host.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {       // NSAnimationContext fires on the main thread
                guard let self, let host = self.hostWindow, let anchor = self.anchorWindow,
                      self.drawerOpen, host.parent !== anchor else { return }
                anchor.addChildWindow(host, ordered: .below)
            }
        })
    }

    /// Slide the drawer back behind the HUD and order it out. Preserve the
    /// current page/player mode so reopening feels like returning to the same
    /// surface, not starting over.
    private func closeDrawer() {
        showLoading(false)
        guard let host = hostWindow, host.isVisible else {
            hostWindow?.orderOut(nil)
            scheduleIdleMemoryPurge(reason: "hidden video drawer")
            completePendingThresholdPurge(at: "hidden video drawer", delay: 0)
            return
        }
        let target: NSRect
        if let anchor = anchorWindow {
            let a = anchor.frame
            let collapsedOpen = drawerFrame(size: collapsedSize(drawerEdge, hud: a), edge: drawerEdge, anchor: a)
            target = tuckedFrame(collapsedOpen, edge: drawerEdge)
            if host.parent === anchor { anchor.removeChildWindow(host) }
            host.order(.below, relativeTo: anchor.windowNumber)
        } else {
            target = host.frame
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.24
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            host.animator().setFrame(target, display: true)
            host.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {       // NSAnimationContext fires on the main thread
                guard let self, let host = self.hostWindow, !self.drawerOpen else { return }
                host.orderOut(nil)
                host.alphaValue = 1
                self.updateExpandButton()
                self.scheduleIdleMemoryPurge(reason: "hidden video drawer")
                self.completePendingThresholdPurge(at: "hidden video drawer", delay: 0)
            }
        })
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
            if aggressive { applyVideoQuality() }
            else { prepareReplacementBrowser(reason: reason) }
            return
        }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 180, execute: work)
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
            webView?.stopLoading()
            webView?.navigationDelegate = nil
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "pomo")
            webView?.loadHTMLString("", baseURL: nil)
            hostWindow?.contentView = nil
            hostWindow?.orderOut(nil)
        }

        webView = nil
        hostWindow = nil
        navProxy = nil
        messageProxy = nil
        drawerContainer = nil
        expandButton = nil
        loadingView = nil
        avatarView = nil
    }

    /// Round only the *outer* corners when collapsed (so the inner edge butts the
    /// HUD square — one block); round all four when expanded (free-floating panel).
    private func applyDrawerCorners() {
        guard let layer = drawerContainer?.layer else { return }
        layer.cornerRadius = Self.drawerRadius
        if drawerExpanded {
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

        wv.load(URLRequest(url: URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F")!))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Borrow the YouTube login from a browser/profile (via the rookie helper)
    /// and reload signed-in. Clears any prior Google/YouTube cookies first so
    /// accounts/profiles don't mix. `browser` nil = all; `profile` e.g. "Profile 1".
    func importCookies(fromBrowser browser: String?, profile: String?) {
        Task { @MainActor in _ = await importLogin(fromBrowser: browser, profile: profile) }
    }

    /// Awaitable import that returns how many auth cookies were found, so callers
    /// (e.g. the import panel) can report success vs "nothing found". Clears any
    /// prior Google/YouTube cookies first so accounts/profiles don't mix.
    @discardableResult
    func importLogin(fromBrowser browser: String?, profile: String?) async -> Int {
        ensureWebView()
        guard let webView else { return 0 }
        let label = [browser, profile].compactMap { $0 }.joined(separator: " / ")
        log("importing cookies from \(label.isEmpty ? "all browsers" : label)…")
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let cleared = await Self.clearAuthCookies(store)
        let cookies = await CookieImporter.cookies(fromBrowser: browser, profile: profile)
        for cookie in cookies { await store.setCookie(cookie) }
        authUser = 0   // a profile's default account is the intended one
        log("cleared \(cleared), imported \(cookies.count) cookies")
        if !currentURL.isEmpty, let base = Self.watchURL(from: currentURL) {
            webView.load(URLRequest(url: Self.withAuthUser(base, 0)))
        }
        return cookies.count
    }

    /// Sign out: drop all Google/YouTube cookies and reload.
    func clearLogin() {
        ensureWebView()
        guard let webView else { return }
        Task { @MainActor in
            let cleared = await Self.clearAuthCookies(webView.configuration.websiteDataStore.httpCookieStore)
            self.authUser = 0
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
        let d = domain.lowercased()
        return d.contains("youtube.com") || d.contains("google.com") || d.contains("google.")
    }

    // MARK: - Login persistence (cookies on disk)

    /// Re-inject any login saved on a prior run into the shared default store, so
    /// a one-time sign-in is reloaded on every launch (and across builds).
    private func restoreSavedLogin() {
        let saved = CookieJar.load()
        guard !saved.isEmpty else { return }
        let store = WKWebsiteDataStore.default().httpCookieStore
        Task { @MainActor in
            for cookie in saved { await store.setCookie(cookie) }
            self.log("restored \(saved.count) login cookies from disk")
        }
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
            CookieJar.save(all.filter { Self.isAuthDomain($0.domain) })
        }
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
            onImport: { [weak self] browser, profile in
                await self?.importLogin(fromBrowser: browser, profile: profile) ?? 0
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

    private func currentBrowserInstance() -> BrowserInstance? {
        guard let webView = webView as? DrawerWebView,
              let hostWindow,
              let navProxy,
              let messageProxy,
              let drawerContainer,
              let expandButton,
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
        instance.webView.stopLoading()
        instance.webView.navigationDelegate = nil
        instance.webView.configuration.userContentController.removeScriptMessageHandler(forName: "pomo")
        instance.webView.loadHTMLString("", baseURL: nil)
        instance.hostWindow.contentView = nil
        instance.hostWindow.orderOut(nil)
    }

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

    /// Crisp while the drawer is visible; lowest (audio-only) while hidden to
    /// save bandwidth.
    private var videoQuality: String { drawerOpen ? "hd720" : "tiny" }

    private func applyVideoQuality() {
        let q = videoQuality
        eval("(function(){var mp=document.getElementById('movie_player');if(mp){try{mp.setPlaybackQualityRange&&mp.setPlaybackQualityRange('\(q)','\(q)');}catch(e){}try{mp.setPlaybackQuality&&mp.setPlaybackQuality('\(q)');}catch(e){}}})();")
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
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = container
        positionBottomRight(window)

        return BrowserInstance(
            webView: wv,
            hostWindow: window,
            navProxy: navProxy,
            messageProxy: messageProxy,
            drawerContainer: container,
            expandButton: expand,
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
        log("navigation finished")
        let js = """
        (function(){
          function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
          function go(n){
            var v = document.querySelector('video,audio');
            if (v) {
              try { v.volume = \(volume)/100.0; } catch(e){}
              // Crisp while the drawer is on screen; lowest (audio-only) when
              // hidden. Audio is served independently, so it stays full quality.
              var mp = document.getElementById('movie_player');
              if (mp) {
                try { mp.setPlaybackQualityRange && mp.setPlaybackQualityRange('\(videoQuality)','\(videoQuality)'); } catch(e){}
                try { mp.setPlaybackQuality && mp.setPlaybackQuality('\(videoQuality)'); } catch(e){}
              }
              v.play().then(function(){ post('playing'); }).catch(function(e){ post('playfail:'+e); });
              if (!v.__pomo) {
                v.__pomo = true;
                v.addEventListener('playing', function(){ post('state:1'); });
                v.addEventListener('pause', function(){ post('state:2'); });
                v.addEventListener('ended', function(){ post('state:0'); });
              }
              post('attached');
            } else if (n > 0) { setTimeout(function(){ go(n-1); }, 700); }
            else { post('no-video'); }
          }
          go(10);
        })();
        """
        eval(js)
        applyBare(!drawerExpanded)        // a fresh navigation re-asserts the bare default
        eval(Self.accountJS)              // read the signed-in identity off the masthead
        eval(Self.timestampKeyJS)
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

    fileprivate func handlePlayerEvent(_ body: Any) {
        let message = "\(body)"
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
    private static func watchURL(from raw: String) -> URL? {
        let host = URLComponents(string: raw)?.host ?? ""
        if host.contains("music.youtube.com") { return URL(string: raw) }
        if let id = youTubeID(from: raw) { return URL(string: "https://www.youtube.com/watch?v=\(id)") }
        return URL(string: raw)
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
        if let comps = URLComponents(string: string) {
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
        return isID(string) ? string : nil
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
    }
}
