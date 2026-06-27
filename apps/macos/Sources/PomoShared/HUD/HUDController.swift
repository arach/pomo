import AppKit
import Observation
import SwiftUI

/// HUD-only presentation chrome the SwiftUI content reacts to but the AppKit key
/// monitor drives — currently just the keyboard cheat sheet toggled with `?`.
@MainActor
@Observable
final class HUDChrome {
    var showShortcuts = false
}

/// Owns the floating HUD panel: lazy construction, summon/dismiss with a fade,
/// first-summon positioning (respecting later drags), and the in-panel keyboard
/// shortcuts that are live only while the HUD is visible.
@MainActor
final class HUDController {
    private let model: TimerModel
    private let settings: PomoSettings
    private let audio: AudioController
    private let favorites: FavoritesStore

    /// Opens the settings window (⌘,). Wired by AppDelegate.
    var onOpenSettings: (() -> Void)?

    /// Fired after the HUD is summoned/dismissed so the app can match its Dock
    /// presence to HUD visibility (a regular Dock app while shown — so it's
    /// ⌘-Tab-able — dropping back to a menu-bar accessory when hidden).
    var onVisibilityChange: ((Bool) -> Void)?

    /// HUD-only chrome (keyboard cheat sheet) shared with the SwiftUI content.
    let chrome = HUDChrome()

    private let contentSize = NSSize(width: 352, height: 268)
    private var panel: HUDPanel?
    private var keyMonitor: Any?
    private var hasPositioned = false
    private(set) var isShown = false

    init(model: TimerModel, settings: PomoSettings, audio: AudioController, favorites: FavoritesStore) {
        self.model = model
        self.settings = settings
        self.audio = audio
        self.favorites = favorites
    }

    // MARK: - Panel lifecycle

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let panel = HUDPanel(contentSize: contentSize)
        panel.onKeyDown = { [weak self] event in
            self?.handle(event) ?? false
        }
        let hosting = NSHostingView(
            rootView: HUDRootView(
                model: model, settings: settings, audio: audio, favorites: favorites,
                chrome: chrome,
                size: contentSize,
                onHide: { [weak self] in self?.hide() },
                onEditingChange: { [weak self] editing in self?.setEditingFocus(editing) }
            )
        )
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.panel = panel
        return panel
    }

    // MARK: - Summon / dismiss

    func toggle() {
        if isShown { hide() } else { show() }
    }

    func show() {
        let panel = ensurePanel()
        if !hasPositioned {
            positionOnActiveScreen(panel)
            hasPositioned = true
        }
        isShown = true
        installKeyMonitor()

        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = CGFloat(settings.panelOpacity)
        }
        // Dock the video drawer to the panel (slides back out if it was open).
        audio.attachDrawer(to: panel)
        onVisibilityChange?(true)
    }

    func hide() {
        guard let panel, isShown else { return }
        isShown = false
        // Don't leave a quick field armed — or the cheat sheet up — for next summon.
        model.cancelEditing()
        chrome.showShortcuts = false
        removeKeyMonitor()
        audio.detachDrawer()
        onVisibilityChange?(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    /// Keep the live alpha in sync when the opacity preference changes.
    func applyOpacity() {
        guard isShown, let panel else { return }
        panel.alphaValue = CGFloat(settings.panelOpacity)
    }

    /// While a quick field is open, ramp the panel to full opacity so the editor
    /// card is crisp; restore the user's opacity when it closes.
    private func setEditingFocus(_ editing: Bool) {
        guard isShown, let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = editing ? 1.0 : CGFloat(settings.panelOpacity)
        }
    }

    private func positionOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2 + frame.height * 0.06
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    // MARK: - In-panel keyboard shortcuts

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns true if the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // While a quick-entry field is open, the text field owns the keyboard:
        // let every key through to it (so paste/typing works), except Escape,
        // which closes the field rather than hiding the whole HUD.
        if model.isEditingQuickField {
            if event.keyCode == 53 { model.cancelEditing(); return true }
            return false
        }

        // While the cheat sheet is up, Escape closes the sheet (not the whole HUD).
        if chrome.showShortcuts, event.keyCode == 53 {
            chrome.showShortcuts = false
            return true
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let onlyShiftOrNone = flags.subtracting([.shift, .numericPad, .function]).isEmpty

        // Command shortcuts
        if command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case ",": onOpenSettings?(); return true
            case "w": hide(); return true
            default: return false
            }
        }

        // Special keys (layout-independent)
        switch event.keyCode {
        case 49: model.toggle(); return true                 // space
        case 53: hide(); return true                         // escape
        case 123 where onlyShiftOrNone: audio.previousTimestampSection(); return true // left arrow
        case 124 where onlyShiftOrNone: audio.nextTimestampSection(); return true     // right arrow
        case 126: model.adjustMinutes(shift ? 5 : 1); return true   // up arrow
        case 125: model.adjustMinutes(shift ? -5 : -1); return true // down arrow
        default: break
        }

        guard onlyShiftOrNone else { return false }

        // Letter / digit shortcuts
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "s": model.start(); return true
        case "p": model.pause(); return true
        case "r": model.reset(); return true
        case "n": model.skip(); return true
        case "c": model.cycleSessionType(); return true
        case "i": model.beginEditing(.intent); return true
        case "v":
            if shift { toggleVideoDrawer() }            // ⇧V: show / hide the video drawer
            else { model.beginEditing(.video) }         // v: paste an audio / video link
            return true
        case "m": toggleMusic(); return true            // play/pause background music
        case "?", "/": chrome.showShortcuts.toggle(); return true  // keyboard cheat sheet
        case "q": hide(); return true
        case "t":
            settings.watchface = settings.watchface.next
            settings.saveNow()
            return true
        case let other?:
            if let digit = Int(other), (1...9).contains(digit) {
                model.setMinutes(digit * 5)
                return true
            }
            return false
        default:
            return false
        }
    }

    // MARK: - Music

    private func toggleMusic() {
        if audio.isPlaying { audio.pause() }
        else { audio.resume(stored: preferredAudioURL()) }
    }

    /// Show / hide the docked video drawer. Mirrors the on-face button: if nothing
    /// is loaded yet, kick off the saved station so the drawer has something to show.
    private func toggleVideoDrawer() {
        if !audio.videoVisible, !audio.isPlaying, audio.currentURL.isEmpty, !settings.audioURL.isEmpty {
            audio.play(urlString: settings.audioURL)
        }
        audio.toggleVideo()
    }

    /// Best URL to (re)start when toggling music from the HUD: whatever's already
    /// loaded, then the saved station, then the first favorite.
    private func preferredAudioURL() -> String {
        if !audio.currentURL.isEmpty { return audio.currentURL }
        if !settings.audioURL.isEmpty { return settings.audioURL }
        return favorites.items.first?.url ?? ""
    }
}
