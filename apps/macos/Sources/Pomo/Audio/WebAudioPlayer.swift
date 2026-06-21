import WebKit
import AppKit

/// Plays audio from a YouTube link (or any URL) without showing video. A hidden
/// `WKWebView` hosts the YouTube IFrame player; only the audio is heard. The view
/// lives in a 1×1 near-invisible on-screen window so macOS doesn't throttle media
/// playback for an occluded/off-screen window.
@MainActor
final class WebAudioPlayer: NSObject {
    private var webView: WKWebView?
    private var hostWindow: NSWindow?

    private(set) var isPlaying = false
    private(set) var currentURL: String = ""
    private var volume: Int = 60

    // MARK: - Controls

    /// Load a URL and start playing. YouTube links use the IFrame player (so we
    /// can play/pause/volume via JS); anything else is loaded directly.
    func play(urlString raw: String) {
        let urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }
        currentURL = urlString
        ensureWebView()

        if let videoID = Self.youTubeID(from: urlString) {
            let html = Self.embedHTML(videoID: videoID, volume: volume)
            webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        } else if let url = URL(string: urlString) {
            webView?.load(URLRequest(url: url))
        } else {
            return
        }
        isPlaying = true
    }

    /// Resume the currently loaded media (re-loads `stored` if nothing is loaded).
    func resume(stored: String) {
        if currentURL.isEmpty {
            play(urlString: stored)
            return
        }
        eval("if(window.player&&player.playVideo){player.playVideo();}")
        isPlaying = true
    }

    func pause() {
        eval("if(window.player&&player.pauseVideo){player.pauseVideo();}")
        isPlaying = false
    }

    func stop() {
        webView?.loadHTMLString("<html><body></body></html>", baseURL: nil)
        currentURL = ""
        isPlaying = false
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(100, Int((value * 100).rounded())))
        eval("if(window.player&&player.setVolume){player.setVolume(\(volume));}")
    }

    // MARK: - Web view plumbing

    private func eval(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func ensureWebView() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []   // allow autoplay w/ sound
        config.allowsAirPlayForMediaPlayback = true

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), configuration: config)

        // Park it on-screen but effectively invisible (1×1, almost transparent) so
        // playback isn't suspended by window occlusion. Bottom-left corner.
        let origin = NSScreen.main?.visibleFrame.origin ?? .zero
        let window = NSWindow(
            contentRect: NSRect(x: origin.x, y: origin.y, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = wv
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0.02
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.orderFrontRegardless()

        hostWindow = window
        webView = wv
    }

    // MARK: - YouTube helpers

    /// Extract an 11-character YouTube video id from the common URL shapes
    /// (watch?v=, youtu.be/, /embed/, /live/, /shorts/) or a bare id.
    static func youTubeID(from string: String) -> String? {
        if let comps = URLComponents(string: string) {
            let host = comps.host ?? ""
            if host.contains("youtu.be") {
                let id = comps.path.split(separator: "/").first.map(String.init)
                if let id, isID(id) { return id }
            }
            if host.contains("youtube.com") {
                if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, isID(v) {
                    return v
                }
                let parts = comps.path.split(separator: "/").map(String.init)
                if let idx = parts.firstIndex(where: { ["embed", "live", "shorts", "v"].contains($0) }),
                   idx + 1 < parts.count, isID(parts[idx + 1]) {
                    return parts[idx + 1]
                }
            }
        }
        return isID(string) ? string : nil
    }

    private static func isID(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }

    private static func embedHTML(videoID: String, volume: Int) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden}</style>
        </head><body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '1', width: '1', videoId: '\(videoID)',
            playerVars: { autoplay: 1, controls: 0, playsinline: 1, modestbranding: 1 },
            events: {
              onReady: function(e) { try { e.target.setVolume(\(volume)); } catch(_){}; e.target.playVideo(); }
            }
          });
        }
        </script>
        </body></html>
        """
    }
}
