import WebKit
import AppKit

/// Plays YouTube / YouTube Music audio by driving the **real watch page's
/// `<video>` element** in a small on-screen "mini-player" window. The IFrame
/// embed is refused for embedding-restricted videos (error 150/152) and raw
/// streams are PoToken-gated (403), so the live page is the reliable path — and
/// once you sign in (Premium) it plays ad-free.
///
/// Cookies/login persist in the default (disk-backed) `WKWebsiteDataStore`, which
/// the sign-in window shares, so a one-time login sticks across launches.
@MainActor
final class WebAudioPlayer: NSObject {
    private static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var navProxy: NavProxy?          // retained — navigationDelegate is weak
    private var messageProxy: MessageProxy?
    private var signInWindow: NSWindow?

    private(set) var isPlaying = false
    private(set) var currentURL: String = ""
    private var volume: Int = 60

    /// Whether the mini-player window is shown. Toggleable at runtime.
    private(set) var windowVisible = true

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
        hostWindow?.orderOut(nil)
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

    // MARK: - Window (show video) toggle

    var isWindowVisible: Bool { hostWindow?.isVisible ?? false }

    func setWindowVisible(_ visible: Bool) {
        windowVisible = visible
        guard let hostWindow else { return }
        if visible { hostWindow.orderFrontRegardless() } else { hostWindow.orderOut(nil) }
    }

    func toggleWindow() { setWindowVisible(!isWindowVisible) }

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
        ensureWebView()
        guard let webView else { return }
        let label = [browser, profile].compactMap { $0 }.joined(separator: " / ")
        log("importing cookies from \(label.isEmpty ? "all browsers" : label)…")
        Task { @MainActor in
            let store = webView.configuration.websiteDataStore.httpCookieStore
            let cleared = await Self.clearAuthCookies(store)
            let cookies = await CookieImporter.cookies(fromBrowser: browser, profile: profile)
            for cookie in cookies { await store.setCookie(cookie) }
            self.authUser = 0   // a profile's default account is the intended one
            self.log("cleared \(cleared), imported \(cookies.count) cookies")
            if !self.currentURL.isEmpty, let base = Self.watchURL(from: self.currentURL) {
                webView.load(URLRequest(url: Self.withAuthUser(base, 0)))
            }
        }
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

    // MARK: - Web view plumbing

    private func eval(_ js: String) { webView?.evaluateJavaScript(js, completionHandler: nil) }

    private func ensureWebView() {
        if webView == nil {
            let config = WKWebViewConfiguration()
            config.mediaTypesRequiringUserActionForPlayback = []
            config.allowsAirPlayForMediaPlayback = true
            config.websiteDataStore = .default()     // persistent cookies/login
            let messageProxy = MessageProxy(self)
            self.messageProxy = messageProxy
            config.userContentController.add(messageProxy, name: "pomo")

            let frame = NSRect(x: 0, y: 0, width: 380, height: 214)
            let wv = WKWebView(frame: frame, configuration: config)
            wv.customUserAgent = Self.desktopUA
            let navProxy = NavProxy(self)
            self.navProxy = navProxy
            wv.navigationDelegate = navProxy

            let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Pomo · Audio"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = wv
            positionBottomRight(window)
            hostWindow = window
            webView = wv
        }
        if windowVisible { hostWindow?.orderFrontRegardless() }
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
              // Lowest video quality — we only want the audio. (Audio is served
              // independently, so it stays full quality.)
              var mp = document.getElementById('movie_player');
              if (mp) {
                try { mp.setPlaybackQualityRange && mp.setPlaybackQualityRange('tiny','tiny'); } catch(e){}
                try { mp.setPlaybackQuality && mp.setPlaybackQuality('tiny'); } catch(e){}
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
    }

    fileprivate func handlePlayerEvent(_ body: Any) {
        let message = "\(body)"
        log("event: \(message)")
        if message.contains("state:1") || message == "playing" { isPlaying = true }
        if message.contains("state:2") || message.contains("state:0")
            || message.hasPrefix("playfail") || message == "no-video" { isPlaying = false }
        onStateChange?()
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
        guard (notification.object as? NSWindow) === signInWindow else { return }
        signInWindow = nil
        NSApp.setActivationPolicy(.accessory)
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
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.owner?.didFinishNavigation() }
    }
}
