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

    /// Signed-in YouTube identity, surfaced in Settings + the drawer avatar.
    let account = AccountStatus()

    private static let drawerRadius: CGFloat = 12

    /// Fired when playback state changes (from JS player events).
    var onStateChange: (() -> Void)?

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
        if currentURL.isEmpty { play(urlString: stored); return }
        eval("document.querySelector('video,audio')&&document.querySelector('video,audio').play();")
        isPlaying = true
    }

    func pause() {
        eval("document.querySelector('video,audio')&&document.querySelector('video,audio').pause();")
        isPlaying = false
    }

    func stop() {
        webView?.load(URLRequest(url: URL(string: "about:blank")!))
        currentURL = ""
        isPlaying = false
        setWindowVisible(false)
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

    // MARK: - Attached video drawer

    /// Reflects user intent (not raw window visibility) so the on-face toggle
    /// stays correct even mid-animation.
    var isWindowVisible: Bool { drawerOpen }

    /// Show/hide the drawer with a slide animation. Opening lazily builds the
    /// web view if it doesn't exist yet.
    func setWindowVisible(_ visible: Bool) {
        drawerOpen = visible
        if visible {
            ensureWebView()
            openDrawer()
        } else {
            closeDrawer()
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

    /// Expand the drawer to the full page (playlist/related, chrome shown) or
    /// collapse it back to the chrome-stripped "screen" that matches the HUD.
    func setExpanded(_ on: Bool) {
        guard drawerOpen, let host = hostWindow, let anchor = anchorWindow else { return }
        drawerExpanded = on
        applyBare(!on)                      // bare (chrome hidden) only when collapsed
        applyDrawerCorners()
        updateExpandButton()
        let a = anchor.frame
        let open = drawerFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a)
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
        switch edge {
        case .right, .left: return NSSize(width: 480, height: max(hud.height, 340))
        case .below, .above: return NSSize(width: max(hud.width, 460), height: 360)
        }
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
        let open = drawerFrame(size: size(for: drawerEdge, in: a), edge: drawerEdge, anchor: a)
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

    /// Slide the drawer back behind the HUD and order it out (resetting to the
    /// collapsed screen so the next open is compact).
    private func closeDrawer() {
        showLoading(false)
        guard let host = hostWindow, host.isVisible else {
            hostWindow?.orderOut(nil); return
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
                self.drawerExpanded = false
                self.updateExpandButton()
            }
        })
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
        eval("(function(){var h=document.documentElement;if(h){h.classList[\(bare ? "add" : "remove")]('pomo-bare');}})();")
    }

    private func updateExpandButton() {
        let symbol = drawerExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        expandButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: drawerExpanded ? "Collapse" : "Expand")
        expandButton?.toolTip = drawerExpanded ? "Collapse to screen" : "Expand to full page"
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
            self.log("logout — cleared \(cleared) cookies")
            if !self.currentURL.isEmpty, let url = Self.watchURL(from: self.currentURL) {
                webView.load(URLRequest(url: url))
            }
        }
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

    // MARK: - Video-pane context menu + import panel

    /// Right-click menu shown over the drawer's video pane (see `DrawerWebView`).
    /// A compact Pomo surface — transport, open-in-browser, and account actions —
    /// in place of WebKit's default web context menu.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        addItem(to: menu, isPlaying ? "Pause" : "Play", #selector(ctxTogglePlay))
        addItem(to: menu, "Next", #selector(ctxNext))
        addItem(to: menu, "Previous", #selector(ctxPrevious))
        menu.addItem(.separator())
        addItem(to: menu, "Open in Browser", #selector(ctxOpenInBrowser))
        addItem(to: menu, "Hide Video", #selector(ctxHideVideo))
        menu.addItem(.separator())

        if account.signedIn {
            let who = NSMenuItem(title: "Signed in\(account.name.map { " as \($0)" } ?? "")",
                                 action: nil, keyEquivalent: "")
            who.isEnabled = false
            menu.addItem(who)
            addItem(to: menu, "Sign Out", #selector(ctxSignOut))
        } else {
            addItem(to: menu, "Sign In to YouTube…", #selector(ctxSignIn))
        }
        addItem(to: menu, "Import Login from Browser…", #selector(ctxImportLogin))
        return menu
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func ctxTogglePlay() {
        if isPlaying {
            pause()
        } else {
            eval("(function(){var v=document.querySelector('video,audio'); if(v){v.play();}})();")
            isPlaying = true
        }
        onStateChange?()
    }
    @objc private func ctxNext() { next() }
    @objc private func ctxPrevious() { previous() }
    @objc private func ctxOpenInBrowser() { openInBrowser() }
    @objc private func ctxHideVideo() { setWindowVisible(false) }
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
            onImport: { [weak self] browser in await self?.importLogin(fromBrowser: browser, profile: nil) ?? 0 },
            onClose: { [weak self] in self?.importLoginWindow?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Import YouTube Login"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        importLoginWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Web view plumbing

    private func eval(_ js: String) { webView?.evaluateJavaScript(js, completionHandler: nil) }

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

    private func ensureWebView() {
        if webView == nil {
            let config = WKWebViewConfiguration()
            config.mediaTypesRequiringUserActionForPlayback = []
            config.allowsAirPlayForMediaPlayback = true
            config.websiteDataStore = .default()     // persistent cookies/login
            let messageProxy = MessageProxy(self)
            self.messageProxy = messageProxy
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
            self.navProxy = navProxy
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
            self.loadingView = loading

            // Corner overlay buttons, pinned top-right: open-in-browser, then expand.
            let bsize: CGFloat = 22, margin: CGFloat = 8, gap: CGFloat = 6
            let expand = Self.overlayButton(symbol: "arrow.up.left.and.arrow.down.right",
                                            tip: "Expand to full page", target: self, action: #selector(didTapExpand))
            expand.frame = NSRect(x: frame.width - bsize - margin, y: frame.height - bsize - margin, width: bsize, height: bsize)
            expand.autoresizingMask = [.minXMargin, .minYMargin]
            container.addSubview(expand)
            self.expandButton = expand

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
            self.avatarView = avatar

            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = container
            positionBottomRight(window)
            hostWindow = window
            webView = wv
            drawerContainer = container
            updateExpandButton()
        }
    }

    private func positionBottomRight(_ window: NSWindow) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24))
    }

    /// Injected after the watch page loads: find <video>, set volume, play, and
    /// report state. Retries because the element appears asynchronously.
    fileprivate func didFinishNavigation() {
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
    }

    /// Reads the signed-in avatar (and best-effort name) from the YouTube /
    /// YT Music masthead, or detects the sign-in button. Retries since the
    /// masthead hydrates asynchronously.
    private static let accountJS = """
    (function(){
      function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
      function check(n){
        var img = document.querySelector('#avatar-btn img, ytd-topbar-menu-button-renderer img, #masthead #avatar-btn img, ytmusic-settings-button img, ytmusic-nav-bar img#right-content-icon');
        var signin = document.querySelector('a[href*="ServiceLogin"], a[href*="accounts.google.com"][aria-label], ytd-button-renderer#sign-in-button a, tp-yt-paper-button[aria-label="Sign in"], a.sign-in-link');
        if (img && img.src && img.src.indexOf('http') === 0) {
          post('account:1|' + (img.alt || '').replace(/[|]/g,' ') + '|' + img.src);
        } else if (signin) {
          post('account:0||');
        } else if (n > 0) {
          setTimeout(function(){ check(n - 1); }, 800);
        }
      }
      check(8);
    })();
    """

    fileprivate func handlePlayerEvent(_ body: Any) {
        let message = "\(body)"
        log("event: \(message)")
        if message.hasPrefix("account:") {
            handleAccount(String(message.dropFirst("account:".count)))
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
        }
        onStateChange?()
    }

    // MARK: - Loading overlay (branded shimmer over the cold YouTube load)

    /// A fresh main-frame navigation started — if the drawer is on screen, cover
    /// it with the branded shimmer until the player reports it's rendering.
    fileprivate func navigationStarted() {
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
        Task { @MainActor in self.owner?.navigationStarted() }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.owner?.didFinishNavigation() }
    }
}

/// The drawer's video pane. Right-click shows a compact Pomo menu (transport +
/// account actions) rather than WebKit's default web context menu.
final class DrawerWebView: WKWebView {
    weak var owner: WebAudioPlayer?

    override func rightMouseDown(with event: NSEvent) {
        MainActor.assumeIsolated {
            guard let menu = owner?.makeContextMenu() else { return }
            menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
        }
    }
}
