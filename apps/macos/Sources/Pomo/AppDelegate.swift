import AppKit
import SwiftUI
import Carbon

/// Owns the app's long-lived objects and wires them together. Runs as a menu-bar
/// (accessory) app: no dock icon, no main window — just the status item and the
/// hotkey-summoned HUD panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = PomoSettings()
    private lazy var model = TimerModel(settings: settings)
    private let chime = CompletionChime()
    private let audio = AudioController()
    private let favorites = FavoritesStore()
    private lazy var hud = HUDController(model: model, settings: settings)
    private lazy var menuBar = MenuBarController(model: model, settings: settings, audio: audio, favorites: favorites)
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Timer → menu-bar countdown + completion behaviour.
        model.onTick = { [weak self] in
            guard let self else { return }
            self.menuBar.refresh()
            self.writeState()
        }
        model.onComplete = { [weak self] _ in
            guard let self else { return }
            if self.settings.soundEnabled {
                self.chime.play(volume: self.settings.volume)
            }
            self.hud.show() // surface the HUD when a session ends
            self.writeState()
        }

        // Preference edits → keep an idle timer + the panel + hotkey + audio in sync.
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.model.reloadDurationsIfIdle()
            self.hud.applyOpacity()
            self.menuBar.refresh()
            self.registerSummonHotkey()
            self.audio.setVolume(self.settings.audioVolume)
        }

        // Register the pomo:// URL scheme for agent control.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        menuBar.onShowHUD = { [weak self] in self?.hud.show() }
        menuBar.onToggleHUD = { [weak self] in self?.hud.toggle() }
        menuBar.onOpenSettings = { [weak self] in self?.showSettings() }
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onToggleAudio = { [weak self] in self?.toggleAudio() }
        menuBar.onStopAudio = { [weak self] in self?.audio.stop() }
        menuBar.onPlayFavorite = { [weak self] favorite in self?.playFavorite(favorite) }

        hud.onOpenSettings = { [weak self] in self?.showSettings() }

        // Audio playback state can change asynchronously (after a yt-dlp resolve),
        // so refresh the state file whenever it does.
        audio.onStateChange = { [weak self] in self?.writeState() }

        // System-wide summon hotkey (default Hyper+P), configurable in Settings.
        registerSummonHotkey()

        // Surface the HUD on first launch so it's discoverable.
        hud.show()

        audio.setVolume(settings.audioVolume)
        writeState()

        // Dev affordance: `POMO_DEV_AUTOSTART=1` starts a session immediately, so
        // the running state can be exercised without synthetic keystrokes.
        if ProcessInfo.processInfo.environment["POMO_DEV_AUTOSTART"] == "1" {
            model.start()
        }
        if ProcessInfo.processInfo.environment["POMO_DEV_OPEN_SETTINGS"] == "1" {
            showSettings()
        }
    }

    private func registerSummonHotkey() {
        let (keyCode, modifiers) = settings.hotkeyCarbon
        HotkeyManager.shared.register(id: 1, keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.hud.toggle()
        }
    }

    // MARK: - Audio helpers

    private func toggleAudio() {
        if audio.isPlaying {
            audio.pause()
        } else {
            audio.resume(stored: settings.audioURL)
        }
    }

    private func playFavorite(_ favorite: Favorite) {
        settings.audioURL = favorite.url
        settings.saveNow()
        audio.play(urlString: favorite.url)
    }

    // MARK: - Agent control (pomo:// scheme)

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string)
        else { return }
        if let command = PomoCommand(url: url) { apply(command) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let command = PomoCommand(url: url) { apply(command) }
        }
    }

    private func apply(_ command: PomoCommand) {
        switch command {
        case .start:       model.start()
        case .pause:       model.pause()
        case .toggle:      model.toggle()
        case .reset:       model.reset()
        case .skip:        model.skip()
        case .showHUD:     hud.show()
        case .hideHUD:     hud.hide()
        case .toggleHUD:   hud.toggle()
        case .session(let type): model.setSessionType(type)
        case .duration(let minutes): model.setMinutes(minutes)
        case .face(let face):
            settings.watchface = face
            settings.saveNow()
            menuBar.refresh()
        case .audioPlay(let url):
            if let url, !url.isEmpty {
                settings.audioURL = url
                settings.saveNow()
                audio.play(urlString: url)
            } else {
                audio.resume(stored: settings.audioURL)
            }
        case .audioPause:  audio.pause()
        case .audioStop:   audio.stop()
        case .audioVolume(let v):
            settings.audioVolume = Double(max(0, min(100, v))) / 100.0
            settings.saveNow()
            audio.setVolume(settings.audioVolume)
        case .favoriteAdd(let url, let title):
            favorites.add(url: url, title: title)
        case .favoritePlay(let index):
            if let favorite = favorites.item(at: index) { playFavorite(favorite) }
        case .favoriteRemove(let index):
            favorites.remove(at: index)
        case .favoritesList:
            break // state (with favorites) is written below
        case .openMenu:    menuBar.toggleMenu()
        case .openSettings: showSettings()
        case .quit:        NSApp.terminate(nil)
        }
        writeState()
    }

    private func writeState() {
        PomoState(
            phase: phaseName,
            sessionType: model.sessionType.rawValue,
            remainingSeconds: model.remainingSeconds,
            totalSeconds: model.totalSeconds,
            clock: model.clock,
            progress: model.progress,
            completedFocusCount: model.completedFocusCount,
            watchface: settings.watchface.rawValue,
            hudVisible: hud.isShown,
            audioPlaying: audio.isPlaying,
            audioURL: audio.currentURL.isEmpty ? settings.audioURL : audio.currentURL,
            audioEngine: audio.engineName,
            favorites: favorites.items
        ).write()
    }

    private var phaseName: String {
        switch model.phase {
        case .idle:    return "idle"
        case .running: return "running"
        case .paused:  return "paused"
        }
    }

    private func showSettings() {
        // A menu-bar (accessory) app can't bring a window to the front on its own;
        // switch to a regular activation policy while Settings is open so the
        // window is focusable, then drop back to accessory when it closes.
        NSApp.setActivationPolicy(.regular)

        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(
            settings: settings,
            onClose: { [weak self] in self?.settingsWindow?.close() },
            onAudioPlay: { [weak self] url in self?.audio.play(urlString: url) },
            onAudioPause: { [weak self] in self?.audio.pause() },
            onAudioStop: { [weak self] in self?.audio.stop() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Pomo Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        // Back to a menu-bar-only app once Settings is dismissed.
        NSApp.setActivationPolicy(.accessory)
    }
}
