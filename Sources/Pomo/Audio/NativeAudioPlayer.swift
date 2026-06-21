import AVFoundation

/// Plays a direct stream URL natively with AVPlayer — ad-free, headless, no
/// webview. Fed resolved URLs by `StreamResolver`, or direct media file URLs.
///
/// YouTube's googlevideo URLs are often PoToken/SABR-gated and return 403 when
/// fetched outside a real player, so AVPlayer can "play" silence. We detect that
/// (item fails, or playback never progresses) and report it via `onFailure` so
/// the controller can fall back to the webview.
@MainActor
final class NativeAudioPlayer {
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var watchdog: Timer?
    private(set) var isPlaying = false
    private var volume: Float = 0.6

    /// Called when the stream can't actually be played (403, decode error, stall).
    var onFailure: (() -> Void)?

    func play(directURL: String, volume: Double) {
        cleanup()
        self.volume = Float(max(0, min(1, volume)))
        guard let url = URL(string: directURL) else { onFailure?(); return }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = self.volume
        self.player = player
        isPlaying = true

        // Hard failure (e.g. 403) surfaces as item.status == .failed.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            Task { @MainActor in if failed { self?.fail() } }
        }

        player.play()

        // Backstop: if playback hasn't actually progressed after a grace period,
        // treat it as a silent stall and fall back.
        watchdog = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.checkProgress() }
        }
    }

    private func checkProgress() {
        guard isPlaying, let player else { return }
        let started = player.timeControlStatus == .playing || player.currentTime().seconds > 0.2
        if player.currentItem?.status == .failed || player.error != nil || !started {
            fail()
        }
    }

    private func fail() {
        guard isPlaying else { return }
        cleanup()
        onFailure?()
    }

    func resume() {
        player?.play()
        isPlaying = (player != nil)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() { cleanup() }

    func setVolume(_ value: Double) {
        volume = Float(max(0, min(1, value)))
        player?.volume = volume
    }

    private func cleanup() {
        watchdog?.invalidate(); watchdog = nil
        statusObservation?.invalidate(); statusObservation = nil
        player?.pause()
        player = nil
        isPlaying = false
    }
}
