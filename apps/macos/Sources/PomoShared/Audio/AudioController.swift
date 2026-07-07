import AppKit
import Darwin
import Foundation
import Observation

/// Background audio — **browser only**. Everything (YouTube, YouTube Music,
/// SoundCloud, direct media URLs, pages) plays through `WebAudioPlayer`'s mini-player. No
/// yt-dlp, no native AVPlayer: the webview is the one engine, and signing in
/// (Premium) makes it ad-free.
///
/// `@Observable` so the menu-bar popover reflects play state live.
@MainActor
@Observable
final class AudioController {
    private let web = WebAudioPlayer()
    private var browserMemoryTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var lastPeriodicBrowserMemoryPurge = Date()
    private var lastThresholdBrowserMemoryPurge = Date.distantPast

    @ObservationIgnored var onStateChange: (() -> Void)?

    private(set) var isPlaying = false
    private(set) var engineName = "none"   // "web" | "none" (kept in state.json)
    private(set) var currentURL = ""
    private(set) var currentTitle = ""
    private(set) var currentArtworkURL = ""

    /// Whether the video drawer is open. Stored (not computed) so the on-face
    /// buttons observe it and re-render when it toggles.
    private(set) var videoOpen = false
    private(set) var videoExpanded = false

    /// Edge the drawer is docked to — the HUD reads this to square the matching
    /// corners so the two read as one block.
    private(set) var videoEdge: DrawerEdge = .right

    var videoVisible: Bool { web.isWindowVisible }

    init() {
        web.onStateChange = { [weak self] in self?.notify() }
        startBrowserMemoryMaintenance()
    }

    /// Hand the player the favorites store so the video menu's "Change Track"
    /// submenu can list them.
    func bindFavorites(_ store: FavoritesStore) { web.favorites = store }

    func setVolume(_ value: Double) { web.setVolume(value) }

    func play(urlString raw: String) { web.play(urlString: raw); notify() }
    func resume(stored: String) { web.resume(stored: stored); notify() }
    func pause() { web.pause(); notify() }
    func stop() { web.stop(); notify() }

    func next() { web.next() }
    func previous() { web.previous() }
    func nextTimestampSection() { web.nextTimestampSection() }
    func previousTimestampSection() { web.previousTimestampSection() }
    @discardableResult
    func restoreRecentPlayback(preferredURL: String) -> Bool {
        let restored = web.restoreRecentPlayback(preferredURL: preferredURL)
        if restored { notify() }
        return restored
    }
    func persistPlaybackSnapshot() { web.persistPlaybackSnapshotNow() }
    func signIn() { web.signIn() }
    func signInSoundCloud() { web.signInSoundCloud() }
    func showImportLogin() { web.showImportLogin() }
    func showSoundCloudImportLogin() { web.showSoundCloudImportLogin() }
    func importCookies(browser: String?, profile: String?, accountIndex: Int = 0) {
        web.importCookies(fromBrowser: browser, profile: profile, accountIndex: accountIndex)
    }
    func importSoundCloudCookies(browser: String?, profile: String?) {
        web.importSoundCloudCookies(fromBrowser: browser, profile: profile)
    }
    func clearLogin() { web.clearLogin() }
    func clearSoundCloudLogin() { web.clearSoundCloudLogin() }
    var soundCloudAccount: AccountStatus { web.soundCloudAccount }
    func setAccount(_ index: Int) { web.setAccount(index) }
    func requestAudioScopePermission() { web.requestAudioScopePermission(); notify() }
    func setVisualizerActive(_ active: Bool) { web.setVisualizerActive(active); notify() }
    func setVisualizerScopeFrameInterval(milliseconds: Int) { web.setVisualizerScopeFrameInterval(milliseconds: milliseconds) }

    /// Signed-in YouTube identity, observed by Settings + the drawer avatar.
    var account: AccountStatus { web.account }
    var mediaDuration: Double { web.mediaDuration }
    var mediaPlaybackRate: Double { web.mediaPlaybackRate }
    var audioScope: AudioScopeFrame? { web.audioScope }
    var audioScopeError: String? { web.audioScopeError }
    func estimatedMediaTime(at hostTime: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        web.estimatedMediaTime(at: hostTime)
    }
    func setVideoVisible(_ visible: Bool) {
        PomoAmpDebugLog.write("audio setVideoVisible begin target=\(visible) current=\(web.isWindowVisible)")
        web.setWindowVisible(visible)
        PomoAmpDebugLog.write("audio setVideoVisible end target=\(visible) current=\(web.isWindowVisible)")
        notify()
    }
    func toggleVideo() {
        PomoAmpDebugLog.write("audio toggleVideo begin current=\(web.isWindowVisible)")
        web.toggleWindow()
        PomoAmpDebugLog.write("audio toggleVideo end current=\(web.isWindowVisible)")
        notify()
    }
    func setOriginalPageVisible(_ visible: Bool) {
        PomoAmpDebugLog.write("audio setOriginalPageVisible begin target=\(visible) videoVisible=\(web.isWindowVisible)")
        web.setOriginalPageVisible(visible)
        PomoAmpDebugLog.write("audio setOriginalPageVisible end target=\(visible) videoVisible=\(web.isWindowVisible)")
        notify()
    }

    /// Pop the currently-playing video out to the default browser (where
    /// playlists, autoplay, queue and the user's extensions all work).
    func openInBrowser() { web.openInBrowser() }

    /// Wire the drawer to the HUD panel when it appears / detach when it hides.
    func attachDrawer(to anchor: NSWindow?) { web.hudDidAppear(anchor: anchor); notify() }
    func detachDrawer() { web.hudWillDisappear(); notify() }
    func purgeBrowserMemoryAtSessionBoundary() { web.purgeBrowserMemoryAtSessionBoundary() }

    private func syncVideo() {
        videoOpen = web.isWindowVisible
        videoExpanded = web.drawerExpanded
        videoEdge = web.drawerEdge
    }

    private func notify() {
        syncVideo()
        isPlaying = web.isPlaying
        currentURL = web.currentURL
        currentTitle = web.currentTitle
        currentArtworkURL = web.currentArtworkURL
        engineName = web.isPlaying ? "web" : "none"
        onStateChange?()
    }

    // MARK: - Browser/video memory maintenance

    private static let browserMemoryCheckInterval: TimeInterval = 60
    private static let periodicBrowserMemoryPurgeInterval: TimeInterval = 15 * 60
    private static let thresholdBrowserMemoryPurgeCooldown: TimeInterval = 5 * 60
    private static let defaultBrowserMemoryThresholdBytes: UInt64 = 700 * 1024 * 1024

    private var browserMemoryThresholdBytes: UInt64 {
        let configured = UserDefaults.standard.integer(forKey: "pomo.audio.memoryPurgeRSSMegabytes")
        guard configured > 0 else { return Self.defaultBrowserMemoryThresholdBytes }
        return UInt64(configured) * 1024 * 1024
    }

    private func startBrowserMemoryMaintenance() {
        let timer = Timer(timeInterval: Self.browserMemoryCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.browserMemoryMaintenanceTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        browserMemoryTimer = timer

        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.web.deferBrowserMemoryPurgeUntilBoundary(reason: "macOS memory pressure")
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func browserMemoryMaintenanceTick() {
        let now = Date()
        if now.timeIntervalSince(lastPeriodicBrowserMemoryPurge) >= Self.periodicBrowserMemoryPurgeInterval {
            lastPeriodicBrowserMemoryPurge = now
            web.purgeBrowserMemory(reason: "periodic maintenance")
        }

        guard let residentBytes = Self.residentMemoryBytes(),
              residentBytes >= browserMemoryThresholdBytes,
              now.timeIntervalSince(lastThresholdBrowserMemoryPurge) >= Self.thresholdBrowserMemoryPurgeCooldown
        else { return }

        lastThresholdBrowserMemoryPurge = now
        web.deferBrowserMemoryPurgeUntilBoundary(
            reason: "app/helper RSS \(Self.formatBytes(residentBytes)) over \(Self.formatBytes(browserMemoryThresholdBytes))"
        )
    }

    private static func residentMemoryBytes() -> UInt64? {
        guard let ownResidentBytes = currentProcessResidentMemoryBytes() else { return nil }
        return ownResidentBytes + childResidentMemoryBytes(parent: getpid())
    }

    private static func currentProcessResidentMemoryBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.resident_size)
    }

    private static func childResidentMemoryBytes(parent: pid_t) -> UInt64 {
        var pids = [pid_t](repeating: 0, count: 256)
        let returned = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listchildpids(parent, buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.size))
        }
        guard returned > 0 else { return 0 }

        let returnedPidsOrBytes = Int(returned)
        let returnedCount = returnedPidsOrBytes > pids.count
            ? returnedPidsOrBytes / MemoryLayout<pid_t>.size
            : returnedPidsOrBytes
        return pids
            .prefix(min(returnedCount, pids.count))
            .filter { $0 > 0 }
            .reduce(UInt64(0)) { total, pid in
                total + (residentMemoryBytes(pid: pid) ?? 0)
            }
    }

    private static func residentMemoryBytes(pid: pid_t) -> UInt64? {
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard result == 0 else { return nil }
        return UInt64(usage.ri_resident_size)
    }

    private static func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1024 / 1024
        return "\(Int(mb.rounded())) MB"
    }
}
