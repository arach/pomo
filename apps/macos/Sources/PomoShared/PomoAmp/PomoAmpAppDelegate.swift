import AppKit
import SwiftUI
import Carbon

@MainActor
public final class PomoAmpAppDelegate: NSObject, NSApplicationDelegate {
    private let settings = PomoSettings()
    private let audio = AudioController()
    private let favorites = FavoritesStore()
    private lazy var hud = PomoAmpHUDController(settings: settings, audio: audio, favorites: favorites)
    private lazy var menuBar = PomoAmpMenuBarController(settings: settings, audio: audio, favorites: favorites)

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        menuBar.onToggleHUD = { [weak self] in self?.hud.toggle() }
        menuBar.onToggleAudio = { [weak self] in self?.toggleAudio() }
        menuBar.onPasteURL = { [weak self] in self?.pasteAndPlay() }
        menuBar.onToggleDrawer = { [weak self] in self?.toggleDrawer() }
        menuBar.onPreviousSection = { [weak self] in self?.audio.previousTimestampSection() }
        menuBar.onNextSection = { [weak self] in self?.audio.nextTimestampSection() }
        menuBar.onTogglePageMode = { [weak self] in self?.hud.toggleVideoPageMode() }
        menuBar.onToggleBig = { [weak self] in self?.hud.toggleBigMode() }
        menuBar.onToggleCompactMode = { [weak self] in self?.hud.toggleCompactMode() }
        menuBar.onShowShortcuts = { [weak self] in self?.hud.showShortcutsOverlay() }
        menuBar.onOpenInBrowser = { [weak self] in self?.audio.openInBrowser() }
        menuBar.onOpenPomo = { [weak self] in self?.openPomo() }
        menuBar.isBig = { [weak self] in self?.hud.isBig ?? false }
        menuBar.isCompactMode = { [weak self] in self?.hud.isCompactMode ?? false }
        menuBar.onQuit = { NSApp.terminate(nil) }

        hud.onOpenPomo = { [weak self] in self?.openPomo() }
        hud.onVisibilityChange = { [weak self] _ in
            self?.updateActivationPolicy()
        }

        audio.onStateChange = { [weak self] in
            self?.menuBar.refresh()
        }
        audio.bindFavorites(favorites)
        audio.setVolume(settings.audioVolume)

        settings.onChange = { [weak self] in
            guard let self else { return }
            self.hud.applyOpacity()
            self.menuBar.refresh()
            self.registerSummonHotkey()
            self.audio.setVolume(self.settings.audioVolume)
        }

        favorites.onChange = { [weak self] in self?.menuBar.refresh() }

        registerSummonHotkey()
        hud.show()
        restoreRecentPlaybackAfterLaunch()
        menuBar.refresh()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        audio.persistPlaybackSnapshot()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        hud.show()
        return true
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string)
        else { return }
        if let command = PomoCommand(url: url, allowedSchemes: ["pomo-amp"]) {
            apply(command)
        }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let command = PomoCommand(url: url, allowedSchemes: ["pomo-amp"]) {
                apply(command)
            }
        }
    }

    private func registerSummonHotkey() {
        let (keyCode, modifiers) = settings.hotkeyCarbon
        HotkeyManager.shared.register(id: 2, keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.hud.toggle()
        }
    }

    private func updateActivationPolicy() {
        NSApp.setActivationPolicy(hud.isShown ? .regular : .accessory)
    }

    private func restoreRecentPlaybackAfterLaunch() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            if self.audio.restoreRecentPlayback(preferredURL: self.preferredAudioURL()) {
                self.menuBar.refresh()
            }
        }
    }

    private func toggleAudio() {
        if audio.isPlaying {
            audio.pause()
        } else {
            audio.resume(stored: preferredAudioURL())
        }
    }

    private func apply(_ command: PomoCommand) {
        switch command {
        case .showHUD:
            hud.show()
        case .hideHUD:
            hud.hide()
        case .toggleHUD:
            hud.toggle()
        case .audioPlay(let url):
            if let url, !url.isEmpty {
                settings.audioURL = url
                settings.saveNow()
                audio.play(urlString: url)
            } else {
                audio.resume(stored: preferredAudioURL())
            }
        case .audioPause:
            audio.pause()
        case .audioStop:
            audio.stop()
        case .audioVolume(let value):
            settings.audioVolume = Double(max(0, min(100, value))) / 100.0
            settings.saveNow()
            audio.setVolume(settings.audioVolume)
        case .audioNext:
            audio.next()
        case .audioPrev:
            audio.previous()
        case .videoShow:
            hud.showVideo()
        case .videoHide:
            hud.hideVideo()
        case .videoToggle:
            hud.toggleVideo()
        case .videoPage:
            hud.showVideoPageMode()
        case .videoPlayer:
            hud.showVideoPlayerMode()
        case .videoBrowser:
            audio.openInBrowser()
        case .favoritePlay(let index):
            if let favorite = favorites.item(at: index) {
                settings.audioURL = favorite.url
                settings.saveNow()
                audio.play(urlString: favorite.url)
            }
        case .login:
            audio.signIn()
        case .importCookies(let browser, let profile, let accountIndex):
            audio.importCookies(browser: browser, profile: profile, accountIndex: accountIndex)
        case .logout:
            audio.clearLogin()
        case .selectAccount(let index):
            audio.setAccount(index)
        case .quit:
            NSApp.terminate(nil)
        default:
            break
        }
        menuBar.refresh()
    }

    private func toggleDrawer() {
        if audio.videoVisible {
            audio.setVideoVisible(false)
            return
        }

        if !audio.isPlaying, audio.currentURL.isEmpty {
            let url = preferredAudioURL()
            if !url.isEmpty { audio.play(urlString: url) }
        }
        hud.show()
        audio.setVideoVisible(true)
    }

    private func pasteAndPlay() {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              WebAudioPlayer.isPlayableSource(raw)
        else { return }
        settings.audioURL = raw
        settings.saveNow()
        audio.play(urlString: raw)
        menuBar.refresh()
    }

    private func openPomo() {
        guard let url = URL(string: "pomo://toggle-hud") else { return }
        if let pomoApp = pomoAppURL() {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: pomoApp, configuration: configuration) { _, error in
                if error != nil {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func pomoAppURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        let nestedHost = bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if nestedHost.lastPathComponent == "Pomo.app",
           appBundleExists(at: nestedHost) {
            return nestedHost
        }

        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Pomo.app", isDirectory: true)
        if appBundleExists(at: sibling) {
            return sibling
        }

        return nil
    }

    private func appBundleExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    }

    private func preferredAudioURL() -> String {
        if !audio.currentURL.isEmpty { return audio.currentURL }
        if !settings.audioURL.isEmpty { return settings.audioURL }
        return favorites.items.first?.url ?? ""
    }
}
