import AppKit
import Observation
import SwiftUI

/// HUD-only presentation chrome the SwiftUI content reacts to but the AppKit key
/// monitor drives: keyboard cheat sheet, tiny/full mode, and live panel size.
@MainActor
@Observable
final class HUDChrome {
    var showShortcuts = false
    var isTiny: Bool
    var panelSize: CGSize

    init(panelSize: CGSize, isTiny: Bool = false) {
        self.panelSize = panelSize
        self.isTiny = isTiny
    }
}

/// Owns the floating HUD panel: lazy construction, summon/dismiss with a fade,
/// first-summon positioning (respecting later drags), and the in-panel keyboard
/// shortcuts that are live only while the HUD is visible.
@MainActor
final class HUDController {
    private static let fullContentSize = NSSize(width: 352, height: 268)
    private static let tinyContentSize = NSSize(width: 188, height: 86)
    private static let fullSavedPanelFrameKey = "pomo.hud.panelFrame.full"
    private static let tinySavedPanelFrameKey = "pomo.hud.panelFrame.tiny"

    private let model: TimerModel
    private let settings: PomoSettings
    private let audio: AudioController
    private let favorites: FavoritesStore

    /// Opens the settings window (⌘,). Wired by AppDelegate.
    var onOpenSettings: (() -> Void)?

    /// Lets Pomo hand video drawer commands to Pomo Amp when the music app is
    /// already running, while preserving the local drawer fallback otherwise.
    var onVideoCommand: ((PomoCommand) -> Bool)?

    /// Fired after the HUD is summoned/dismissed so the app can match its Dock
    /// presence to HUD visibility (a regular Dock app while shown — so it's
    /// ⌘-Tab-able — dropping back to a menu-bar accessory when hidden).
    var onVisibilityChange: ((Bool) -> Void)?

    /// HUD-only chrome shared with the SwiftUI content.
    let chrome: HUDChrome

    private var panel: HUDPanel?
    private var keyMonitor: Any?
    private var panelFrameObserverTokens: [NSObjectProtocol] = []
    private(set) var isShown = false

    init(model: TimerModel, settings: PomoSettings, audio: AudioController, favorites: FavoritesStore) {
        self.model = model
        self.settings = settings
        self.audio = audio
        self.favorites = favorites
        self.chrome = HUDChrome(
            panelSize: settings.hudTinyMode ? Self.tinyContentSize : Self.fullContentSize,
            isTiny: settings.hudTinyMode
        )
    }

    // MARK: - Panel lifecycle

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let initialSize = effectivePanelSize()
        chrome.panelSize = initialSize
        let panel = HUDPanel(contentSize: initialSize)
        panel.onKeyDown = { [weak self] event in
            self?.handle(event) ?? false
        }
        let hosting = NSHostingView(
            rootView: HUDRootView(
                model: model, settings: settings, audio: audio, favorites: favorites,
                chrome: chrome,
                onHide: { [weak self] in self?.hide() },
                onSetTinyMode: { [weak self] tiny in self?.setTinyMode(tiny) },
                onToggleVideoDrawer: { [weak self] in self?.toggleVideoDrawer() },
                onEditingChange: { [weak self] editing in self?.setEditingFocus(editing) }
            )
        )
        hosting.frame = NSRect(origin: .zero, size: initialSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        if let restored = restoredPanelFrame(size: initialSize, for: panel, tiny: chrome.isTiny) {
            panel.setFrame(restored, display: false)
        } else {
            positionOnActiveScreen(panel)
            savePanelFrame(panel.frame, tiny: chrome.isTiny)
        }
        installPanelFrameObservers(panel)
        panel.alphaValue = CGFloat(settings.panelOpacity)
        self.panel = panel
        return panel
    }

    // MARK: - Summon / dismiss

    func toggle() {
        if isShown { hide() } else { show() }
    }

    func show() {
        let panel = ensurePanel()
        applyPresentationSettings()
        keepPanelVisible(panel)
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
        if chrome.isTiny {
            audio.detachDrawer()
        } else {
            audio.attachDrawer(to: panel)
        }
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

    /// Keep mode + opacity in sync with persisted settings edits.
    func applyPresentationSettings() {
        setTinyMode(settings.hudTinyMode, persist: false)
        applyOpacity()
    }

    func toggleTinyMode() {
        setTinyMode(!chrome.isTiny)
    }

    func setTinyMode(_ tiny: Bool) {
        setTinyMode(tiny, persist: true)
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

    private func setTinyMode(_ tiny: Bool, persist: Bool) {
        if chrome.isTiny == tiny {
            if persist, settings.hudTinyMode != tiny {
                settings.hudTinyMode = tiny
                settings.saveNow()
            }
            return
        }

        if let panel {
            savePanelFrame(panel.frame, tiny: chrome.isTiny)
        }

        chrome.isTiny = tiny
        chrome.panelSize = effectivePanelSize()

        if tiny {
            chrome.showShortcuts = false
            model.cancelEditing()
            audio.detachDrawer()
        }

        if persist, settings.hudTinyMode != tiny {
            settings.hudTinyMode = tiny
            settings.saveNow()
        }

        guard let panel else { return }
        let size = effectivePanelSize()
        let old = panel.frame
        let fallback: NSRect
        if tiny {
            fallback = NSRect(x: old.maxX - size.width, y: old.maxY - size.height, width: size.width, height: size.height)
        } else {
            fallback = NSRect(x: old.midX - size.width / 2, y: old.midY - size.height / 2, width: size.width, height: size.height)
        }
        let target = restoredPanelFrame(size: size, for: panel, tiny: tiny)
            ?? clampedFrame(fallback, for: panel)

        panel.contentView?.setFrameSize(size)
        panel.setFrame(target, display: true)
        savePanelFrame(target, tiny: tiny)

        if isShown, !tiny {
            audio.attachDrawer(to: panel)
        }
    }

    private func effectivePanelSize() -> NSSize {
        chrome.isTiny ? Self.tinyContentSize : Self.fullContentSize
    }

    private func installPanelFrameObservers(_ panel: NSPanel) {
        let center = NotificationCenter.default
        panelFrameObserverTokens.forEach(center.removeObserver)
        panelFrameObserverTokens = [
            center.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self, weak panel] _ in
                guard let panel else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.savePanelFrame(panel.frame, tiny: self.chrome.isTiny)
                }
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self, weak panel] _ in
                guard let panel else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.savePanelFrame(panel.frame, tiny: self.chrome.isTiny)
                }
            }
        ]
    }

    private func restoredPanelFrame(size: NSSize, for panel: NSPanel, tiny: Bool) -> NSRect? {
        guard let raw = UserDefaults.standard.string(forKey: savedPanelFrameKey(tiny: tiny)) else { return nil }
        let saved = NSRectFromString(raw)
        guard saved.width > 1, saved.height > 1 else { return nil }
        let target = NSRect(
            x: saved.minX,
            y: saved.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return clampedFrame(target, for: panel)
    }

    private func savePanelFrame(_ frame: NSRect, tiny: Bool) {
        guard frame.width > 1, frame.height > 1 else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: savedPanelFrameKey(tiny: tiny))
    }

    private func savedPanelFrameKey(tiny: Bool) -> String {
        tiny ? Self.tinySavedPanelFrameKey : Self.fullSavedPanelFrameKey
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

    private func keepPanelVisible(_ panel: NSPanel) {
        let frame = panel.frame
        let clamped = clampedFrame(frame, for: panel)
        if clamped != frame {
            panel.setFrame(clamped, display: false)
            savePanelFrame(clamped, tiny: chrome.isTiny)
        }
    }

    private func clampedFrame(_ frame: NSRect, for panel: NSPanel) -> NSRect {
        let bounds = bestScreen(for: frame, fallback: panel)?.visibleFrame ?? frame
        var frame = frame
        frame.size.width = min(frame.width, bounds.width)
        frame.size.height = min(frame.height, bounds.height)
        if frame.minX < bounds.minX { frame.origin.x = bounds.minX }
        if frame.maxX > bounds.maxX { frame.origin.x = bounds.maxX - frame.width }
        if frame.minY < bounds.minY { frame.origin.y = bounds.minY }
        if frame.maxY > bounds.maxY { frame.origin.y = bounds.maxY - frame.height }
        return frame
    }

    private func bestScreen(for frame: NSRect, fallback panel: NSPanel) -> NSScreen? {
        let screens = NSScreen.screens
        let best = screens
            .map { screen in (screen, intersectionArea(screen.visibleFrame, frame)) }
            .max { lhs, rhs in lhs.1 < rhs.1 }
        if let best, best.1 > 0 { return best.0 }

        let center = NSPoint(x: frame.midX, y: frame.midY)
        let nearest = screens.min { lhs, rhs in
            distance(from: center, to: lhs.visibleFrame) < distance(from: center, to: rhs.visibleFrame)
        }
        if let nearest { return nearest }

        return panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
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
        case "i":
            if chrome.isTiny { setTinyMode(false) }
            model.beginEditing(.intent)
            return true
        case "v":
            if shift { toggleVideoDrawer() }            // ⇧V: show / hide the video drawer
            else {
                if chrome.isTiny { setTinyMode(false) }
                model.beginEditing(.video)              // v: paste an audio / video link
            }
            return true
        case "m": toggleMusic(); return true            // play/pause background music
        case "y": toggleTinyMode(); return true         // tiny/full HUD
        case "?", "/":
            if chrome.isTiny { setTinyMode(false) }
            chrome.showShortcuts.toggle()
            return true                                 // keyboard cheat sheet
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
        if onVideoCommand?(.videoToggle) == true { return }
        if chrome.isTiny { setTinyMode(false) }
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
