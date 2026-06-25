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
    private let history = SessionHistoryStore()
    private lazy var hud = HUDController(model: model, settings: settings, audio: audio, favorites: favorites)
    private lazy var menuBar = MenuBarController(model: model, settings: settings, audio: audio, favorites: favorites)
    private var settingsWindow: NSWindow?
    private var statsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Timer → menu-bar countdown + completion behaviour.
        model.onTick = { [weak self] in
            guard let self else { return }
            self.menuBar.refresh()
            self.writeState()
        }
        model.onComplete = { [weak self] type in
            guard let self else { return }
            if self.settings.soundEnabled {
                self.chime.play(volume: self.settings.volume)
            }
            // Log finished focus sessions for the stats heatmap. `totalSeconds`
            // is still the finished session's length here (advanceSession runs
            // after onComplete fires).
            if type == .focus {
                self.history.record(SessionRecord(
                    type: type,
                    completedAt: Date(),
                    durationSeconds: self.model.totalSeconds,
                    intent: self.model.intent
                ))
            }
            self.hud.show() // surface the HUD when a session ends
            self.writeState()
        }

        // Seed the session intent from the last run, then keep it persisted as
        // the user edits it. Seeding before wiring the callback avoids a
        // redundant save of the value we just loaded.
        if !settings.intent.isEmpty { model.setIntent(settings.intent) }
        model.onIntentChange = { [weak self] in
            guard let self else { return }
            self.settings.updateIntent(self.model.intent)
            self.settings.noteRecentIntent(self.model.intent)
            self.menuBar.refresh()
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
        menuBar.onOpenStats = { [weak self] in self?.showStats() }
        menuBar.onSetIntent = { [weak self] in
            // The quick field lives on the HUD, so summon it, then arm the field.
            self?.hud.show()
            self?.model.beginEditing(.intent)
        }
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onToggleAudio = { [weak self] in self?.toggleAudio() }
        menuBar.onStopAudio = { [weak self] in self?.audio.stop() }
        menuBar.onPlayFavorite = { [weak self] favorite in self?.playFavorite(favorite) }

        hud.onOpenSettings = { [weak self] in self?.showSettings() }
        // While the HUD is on screen, run as a regular Dock app so it shows an
        // icon and is reachable via ⌘-Tab; drop back to a menu-bar accessory
        // when it's hidden. Also keeps state.json's hudVisible fresh.
        hud.onVisibilityChange = { [weak self] _ in
            self?.updateActivationPolicy()
            self?.writeState()
        }

        // Audio playback state can change asynchronously (web player events),
        // so refresh the state file whenever it does.
        audio.onStateChange = { [weak self] in self?.writeState() }

        // Let the video menu's "Change Track" submenu list favorites.
        audio.bindFavorites(favorites)

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

    // MARK: - Dock presence

    /// Match the app's activation policy to what's on screen: a regular Dock app
    /// (so the HUD has an icon and is ⌘-Tab-able) whenever the HUD or an
    /// auxiliary window is visible, dropping back to a menu-bar accessory when
    /// nothing is shown. `excluding` skips a window that's mid-close (its
    /// `isVisible` is still true inside `windowWillClose`).
    private func updateActivationPolicy(excluding closing: NSWindow? = nil) {
        func visible(_ window: NSWindow?) -> Bool {
            guard let window, window !== closing else { return false }
            return window.isVisible
        }
        let wantsDock = hud.isShown || visible(settingsWindow) || visible(statsWindow)
        NSApp.setActivationPolicy(wantsDock ? .regular : .accessory)
    }

    /// Clicking the Dock icon (present only while the HUD is up) re-summons the HUD.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        hud.show()
        return true
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
        case .audioNext:   audio.next()
        case .audioPrev:   audio.previous()
        case .login:       audio.signIn()
        case .importCookies(let browser, let profile): audio.importCookies(browser: browser, profile: profile)
        case .logout: audio.clearLogin()
        case .selectAccount(let index): audio.setAccount(index)
        case .videoShow:   audio.setVideoVisible(true)
        case .videoHide:   audio.setVideoVisible(false)
        case .videoToggle: audio.toggleVideo()
        case .videoBrowser: audio.openInBrowser()
        case .favoriteAdd(let url, let title):
            favorites.add(url: url, title: title)
        case .favoritePlay(let index):
            if let favorite = favorites.item(at: index) { playFavorite(favorite) }
        case .favoriteRemove(let index):
            favorites.remove(at: index)
        case .favoritesList:
            break // state (with favorites) is written below
        case .setIntent(let text): model.setIntent(text)
        case .shortcuts(let visible):
            hud.show()
            hud.chrome.showShortcuts = visible ?? !hud.chrome.showShortcuts
        case .openStats:   showStats()
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
            intent: model.intent,
            watchface: settings.watchface.rawValue,
            hudVisible: hud.isShown,
            audioPlaying: audio.isPlaying,
            audioURL: audio.currentURL.isEmpty ? settings.audioURL : audio.currentURL,
            audioEngine: audio.engineName,
            favorites: favorites.items,
            focusToday: history.focusCountToday(),
            focusTotal: history.totalFocusCount,
            streakDays: history.currentStreak()
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
            account: audio.account,
            onClose: { [weak self] in self?.settingsWindow?.close() },
            onAudioPlay: { [weak self] url in self?.audio.play(urlString: url) },
            onAudioPause: { [weak self] in self?.audio.pause() },
            onAudioStop: { [weak self] in self?.audio.stop() },
            onSignIn: { [weak self] in self?.audio.signIn() },
            onSignOut: { [weak self] in self?.audio.clearLogin() },
            onImportLogin: { [weak self] in self?.audio.showImportLogin() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Pomo Settings"
        // Resizable, with a transparent full-height titlebar so the sidebar runs
        // to the top (System-Settings style). The view follows the system
        // light/dark appearance via `AppPalette`, so we don't force one here.
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 720, height: 560))
        window.contentMinSize = NSSize(width: 640, height: 480)
        // A settings window shouldn't persist/restore its transient UI state
        // (e.g. the selected tab); always open fresh on General.
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // The audio URL field is the window's only text input, so AppKit makes it
        // first responder and selects-all on open. Clear focus so nothing is
        // highlighted on load — now (sync become-key) and next tick (async
        // become-key after activation), so it sticks either way.
        window.makeFirstResponder(nil)
        DispatchQueue.main.async { [weak window] in window?.makeFirstResponder(nil) }
    }

    private func showStats() {
        // Same accessory→regular dance as Settings so the window is focusable.
        NSApp.setActivationPolicy(.regular)

        if let statsWindow {
            NSApp.activate(ignoringOtherApps: true)
            statsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let view = StatsView(
            history: history,
            onClose: { [weak self] in self?.statsWindow?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Pomo Stats"
        // Frosted, chromeless treatment to match the HUD: keep `.titled` (for the
        // rounded-corner mask + window management) but hide the bar, let the
        // content fill it, drop the standard buttons, and make it transparent so
        // the SwiftUI behind-window frost shows through. Drag anywhere to move;
        // close with the Done button or Esc.
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        // Force dark appearance so the behind-window frost renders as dark glass
        // (like the menu popover), not a milky light-gray in Light Mode.
        window.appearance = NSAppearance(named: .darkAqua)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        statsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              closing === settingsWindow || closing === statsWindow else { return }
        // Re-evaluate Dock presence as this window closes: stay regular while the
        // HUD or the other auxiliary window is still on screen, else go accessory.
        updateActivationPolicy(excluding: closing)
    }
}
