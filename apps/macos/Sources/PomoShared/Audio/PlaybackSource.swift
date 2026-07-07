import Foundation

/// Recognizes and normalizes background-audio URLs (YouTube, SoundCloud, …).
enum PlaybackSource: Equatable {
    case youTube
    case soundCloud
    case generic

    static func detect(from raw: String) -> PlaybackSource {
        let normalized = normalizedSource(raw)
        let host = URLComponents(string: normalized)?.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youTube
        }
        if host.contains("soundcloud.com") {
            return .soundCloud
        }
        return .generic
    }

    static func isPlayable(_ raw: String) -> Bool {
        playbackURL(from: raw, pageMode: false) != nil
    }

    /// Resolved URL to load in the web player.
    static func playbackURL(from raw: String, pageMode: Bool) -> URL? {
        let normalized = normalizedSource(raw)
        if detect(from: normalized) == .soundCloud {
            if pageMode, let canonical = soundCloudCanonicalURL(from: normalized) {
                return URL(string: canonical)
            }
            return soundCloudEmbedURL(from: normalized)
        }

        let host = URLComponents(string: normalized)?.host ?? ""
        if host.contains("music.youtube.com") { return URL(string: normalized) }
        if let id = youTubeID(from: normalized) {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")
        }
        guard let url = URL(string: normalized), url.scheme != nil else { return nil }
        return url
    }

    static func normalizedSource(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("youtube.com/")
            || lower.hasPrefix("www.youtube.com/")
            || lower.hasPrefix("m.youtube.com/")
            || lower.hasPrefix("music.youtube.com/")
            || lower.hasPrefix("youtu.be/")
            || lower.hasPrefix("soundcloud.com/")
            || lower.hasPrefix("www.soundcloud.com/")
            || lower.hasPrefix("on.soundcloud.com/")
            || lower.hasPrefix("w.soundcloud.com/")
            || lower.hasPrefix("api.soundcloud.com/") {
            return "https://\(trimmed)"
        }
        return trimmed
    }

    /// Canonical SoundCloud page URL for favorites, browser hand-off, and page mode.
    static func soundCloudCanonicalURL(from raw: String) -> String? {
        let normalized = normalizedSource(raw)
        guard detect(from: normalized) == .soundCloud else { return nil }

        if let comps = URLComponents(string: normalized),
           comps.host?.lowercased() == "w.soundcloud.com",
           let encoded = comps.queryItems?.first(where: { $0.name == "url" })?.value,
           let decoded = encoded.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
           !decoded.isEmpty {
            if decoded.hasPrefix("http") { return decoded }
            return "https://\(decoded)"
        }

        guard var comps = URLComponents(string: normalized) else { return nil }
        let host = comps.host?.lowercased() ?? ""
        guard host == "soundcloud.com"
            || host == "www.soundcloud.com"
            || host == "on.soundcloud.com"
            || host == "api.soundcloud.com"
        else { return normalized }

        comps.scheme = "https"
        if host == "www.soundcloud.com" { comps.host = "soundcloud.com" }
        return comps.url?.absoluteString
    }

    /// Compact widget player — reliable audio in the drawer.
    static func soundCloudEmbedURL(from raw: String) -> URL? {
        let normalized = normalizedSource(raw)
        guard detect(from: normalized) == .soundCloud else { return nil }

        let target = soundCloudCanonicalURL(from: normalized) ?? normalized
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "w.soundcloud.com"
        comps.path = "/player/"
        comps.queryItems = [
            URLQueryItem(name: "url", value: target),
            URLQueryItem(name: "auto_play", value: "true"),
            URLQueryItem(name: "show_artwork", value: "true"),
            URLQueryItem(name: "show_playcount", value: "false"),
            URLQueryItem(name: "show_teaser", value: "false"),
            URLQueryItem(name: "visual", value: "false"),
            URLQueryItem(name: "single_active", value: "false"),
        ]
        return comps.url
    }

    /// Static artwork when the live player has not reported one yet.
    static func fallbackArtworkURL(for raw: String) -> String {
        if let id = youTubeID(from: raw) {
            return "https://img.youtube.com/vi/\(id)/mqdefault.jpg"
        }
        return ""
    }

    static func youTubeID(from string: String) -> String? {
        let normalized = normalizedSource(string)
        if let comps = URLComponents(string: normalized) {
            let host = comps.host ?? ""
            if host.contains("youtu.be") {
                let id = comps.path.split(separator: "/").first.map(String.init)
                if let id, isYouTubeID(id) { return id }
            }
            if host.contains("youtube.com") {
                if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, isYouTubeID(v) { return v }
                let parts = comps.path.split(separator: "/").map(String.init)
                if let idx = parts.firstIndex(where: { ["embed", "live", "shorts", "v"].contains($0) }),
                   idx + 1 < parts.count, isYouTubeID(parts[idx + 1]) { return parts[idx + 1] }
            }
        }
        return isYouTubeID(normalized) ? normalized : nil
    }

    private static func isYouTubeID(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }

    static func artworkURL(for raw: String, liveArtwork: String) -> String? {
        let live = liveArtwork.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        let fallback = fallbackArtworkURL(for: raw)
        return fallback.isEmpty ? nil : fallback
    }

    static func shortLabel(for raw: String) -> String {
        switch detect(from: raw) {
        case .youTube:
            if let id = youTubeID(from: raw) { return "youtube · \(id)" }
        case .soundCloud:
            if let path = soundCloudCanonicalURL(from: raw).flatMap(URL.init(string:))?.path,
               !path.isEmpty, path != "/" {
                let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !trimmed.isEmpty { return "soundcloud · \(trimmed)" }
            }
            return "soundcloud"
        case .generic:
            break
        }
        return URLComponents(string: raw)?.host?
            .replacingOccurrences(of: "www.", with: "") ?? raw
    }

    static func playerAttachmentJS(volume: Int, restoreSeek: Double, visualizerActive: Bool, scopeIntervalMs: Int) -> String {
        """
        (function(){
          function post(m){ try{ window.webkit.messageHandlers.pomo.postMessage(m); }catch(e){} }
          var host = (location.hostname || '').toLowerCase();
          var isEmbed = host === 'w.soundcloud.com';
          var isPage = host.endsWith('soundcloud.com') && !isEmbed;
          if (!isEmbed && !isPage) return;

          document.documentElement && document.documentElement.classList.add('pomo-soundcloud');
          var __pomoRestoreSeek = \(restoreSeek);
          var __pomoLastTitle = '';
          var __pomoTitleTick = 0;

          function cleanTitle(text){
            text = (text || '').toString().replace(/\\s+/g, ' ').trim();
            text = text.replace(/\\s+on SoundCloud$/i, '');
            text = text.replace(/\\s+\\|\\s+SoundCloud$/i, '');
            text = text.replace(/\\s+-\\s+SoundCloud$/i, '');
            return text.trim();
          }

          function reportTitle(text){
            text = cleanTitle(text);
            if (!text || text === __pomoLastTitle) return;
            __pomoLastTitle = text;
            post('title:' + encodeURIComponent(text));
          }

          function reportArtwork(url){
            if (!url) return;
            post('artwork:' + encodeURIComponent(url));
          }

          function reportTitleFromDOM(){
            var el = document.querySelector('.soundTitle__title, .soundTitle__titleText, h1.soundTitle, h1');
            var title = el && el.textContent || '';
            if (!title) {
              var meta = document.querySelector('meta[property="og:title"], meta[name="title"]');
              title = meta && meta.getAttribute('content') || document.title || '';
            }
            reportTitle(title);
            var img = document.querySelector('.playbackSoundBadge__avatar img, .soundBadge__avatar img, img[src*="sndcdn.com/artworks"]');
            if (img && img.src) reportArtwork(img.src);
            else {
              var art = document.querySelector('meta[property="og:image"]');
              if (art) reportArtwork(art.getAttribute('content') || '');
            }
          }

          function restoreSeek(v, attempts){
            var target = Number(__pomoRestoreSeek) || 0;
            if (target <= 1 || !v) return;
            try {
              var duration = Number(v.duration) || 0;
              var clamped = duration > 2 ? Math.min(target, Math.max(0, duration - 1)) : target;
              if (Math.abs((Number(v.currentTime) || 0) - clamped) > 1.5) v.currentTime = clamped;
              if (duration > 0) {
                __pomoRestoreSeek = 0;
                post('seekrestore:' + Math.round(clamped));
                return;
              }
            } catch(e) {}
            if (attempts > 0) setTimeout(function(){ restoreSeek(v, attempts - 1); }, 450);
          }

          function attachMedia(v){
            try { v.volume = \(volume)/100.0; } catch(e) {}
            restoreSeek(v, 12);
            function clock(){
              var duration = Number(v.duration);
              post('clock:' + JSON.stringify({
                time: Number(v.currentTime) || 0,
                duration: isFinite(duration) ? duration : 0,
                paused: !!v.paused,
                rate: Number(v.playbackRate) || 1,
                ended: !!v.ended
              }));
              __pomoTitleTick += 1;
              if (__pomoTitleTick % 4 === 0) reportTitleFromDOM();
            }
            v.play().then(function(){ post('playing'); }).catch(function(e){ post('playfail:' + e); });
            if (!v.__pomo) {
              v.__pomo = true;
              v.addEventListener('playing', function(){ post('state:1'); });
              v.addEventListener('pause', function(){ post('state:2'); });
              v.addEventListener('ended', function(){ post('state:0'); });
              v.addEventListener('seeked', clock);
              v.addEventListener('ratechange', clock);
              v.addEventListener('durationchange', clock);
              v.addEventListener('timeupdate', clock);
              v.__pomoClockTimer = setInterval(clock, 500);
            }
            clock();
            reportTitleFromDOM();
            post('attached');
          }

          function setupEmbed(attempts){
            var media = document.querySelector('video,audio');
            if (media) { attachMedia(media); return; }
            var play = document.querySelector('.playControl, button.playControls__control');
            if (play) {
              try { play.click(); } catch(e) {}
              post('playing');
            }
            reportTitleFromDOM();
            if (attempts > 0) setTimeout(function(){ setupEmbed(attempts - 1); }, 700);
            else post('no-video');
          }

          function bootWidget(iframe){
            var widget = SC.Widget(iframe);
            window.__pomoSCWidget = widget;
            widget.bind(SC.Widget.Events.READY, function(){
              widget.setVolume(\(volume));
              widget.play();
              widget.getCurrentSound(function(sound){
                if (sound && sound.title) reportTitle(sound.title);
                if (sound && sound.artwork_url) {
                  reportArtwork(String(sound.artwork_url).replace('-large', '-t500x500'));
                }
              });
              post('playing');
            });
            widget.bind(SC.Widget.Events.PLAY, function(){ post('state:1'); });
            widget.bind(SC.Widget.Events.PAUSE, function(){ post('state:2'); });
            widget.bind(SC.Widget.Events.FINISH, function(){ post('state:0'); });
            widget.bind(SC.Widget.Events.PLAY_PROGRESS, function(e){
              widget.getDuration(function(dur){
                post('clock:' + JSON.stringify({
                  time: (e.currentPosition || 0) / 1000,
                  duration: (dur || 0) / 1000,
                  paused: false,
                  rate: 1,
                  ended: false
                }));
              });
            });
          }

          function setupPage(attempts){
            var iframe = document.querySelector('iframe[src*="w.soundcloud.com/player"]');
            if (!iframe) {
              var media = document.querySelector('video,audio');
              if (media) { attachMedia(media); return; }
              if (attempts > 0) setTimeout(function(){ setupPage(attempts - 1); }, 700);
              else post('no-video');
              return;
            }
            function start(){
              try { bootWidget(iframe); } catch(e) { post('playfail:' + e); }
            }
            if (typeof SC !== 'undefined' && SC.Widget) start();
            else {
              var script = document.createElement('script');
              script.src = 'https://w.soundcloud.com/player/api.js';
              script.onload = start;
              script.onerror = function(){ post('playfail:widget-api'); };
              document.head.appendChild(script);
            }
          }

          window.__pomoVisualizerActive = \(visualizerActive ? "true" : "false");
          window.__pomoScopeIntervalMs = \(scopeIntervalMs);
          if (isEmbed) setupEmbed(24);
          else if (isPage) setupPage(24);
        })();
        """
    }

    static let nextJS = """
    (function(){
      if (window.__pomoSCWidget) { window.__pomoSCWidget.next(); return; }
      var btn = document.querySelector('.skipControl__next, button[aria-label*="Skip to next"], button[title*="Next"]');
      if (btn) btn.click();
    })();
    """

    static let previousJS = """
    (function(){
      if (window.__pomoSCWidget) { window.__pomoSCWidget.prev(); return; }
      var btn = document.querySelector('.skipControl__previous, button[aria-label*="Skip to previous"], button[title*="Previous"]');
      if (btn) btn.click();
    })();
    """

    static let resumeJS = """
    (function(){
      if (window.__pomoSCWidget) { window.__pomoSCWidget.play(); return; }
      var media = document.querySelector('video,audio');
      if (media) { media.play(); return; }
      var btn = document.querySelector('.playControl:not(.playing), button.playControls__control[aria-label*="Play"]');
      if (btn) btn.click();
    })();
    """

    static let pauseJS = """
    (function(){
      if (window.__pomoSCWidget) { window.__pomoSCWidget.pause(); return; }
      var media = document.querySelector('video,audio');
      try { if (media) media.pause(); } catch(e) {}
      var btn = document.querySelector('.playControl.playing, button.playControls__control[aria-label*="Pause"]');
      if (btn) btn.click();
    })();
    """

    static func setVolumeJS(_ volume: Int) -> String {
        """
        (function(){
          var vol = \(volume);
          if (window.__pomoSCWidget) { window.__pomoSCWidget.setVolume(vol); return; }
          var media = document.querySelector('video,audio');
          if (media) media.volume = vol / 100.0;
        })();
        """
    }
}