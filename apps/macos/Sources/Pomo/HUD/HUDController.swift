import AppKit
import SwiftUI

/// Owns the floating HUD panel: lazy construction, summon/dismiss with a fade,
/// first-summon positioning (respecting later drags), and the in-panel keyboard
/// shortcuts that are live only while the HUD is visible.
@MainActor
final class HUDController {
    private let model: TimerModel
    private let settings: PomoSettings
    private let audio: AudioController

    /// Opens the settings window (⌘,). Wired by AppDelegate.
    var onOpenSettings: (() -> Void)?

    private let contentSize = NSSize(width: 352, height: 244)
    private var panel: HUDPanel?
    private var keyMonitor: Any?
    private var hasPositioned = false
    private(set) var isShown = false

    init(model: TimerModel, settings: PomoSettings, audio: AudioController) {
        self.model = model
        self.settings = settings
        self.audio = audio
    }

    // MARK: - Panel lifecycle

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let panel = HUDPanel(contentSize: contentSize)
        let hosting = NSHostingView(
            rootView: HUDRootView(model: model, settings: settings, audio: audio, size: contentSize)
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
    }

    func hide() {
        guard let panel, isShown else { return }
        isShown = false
        removeKeyMonitor()
        audio.detachDrawer()
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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let onlyShiftOrNone = flags.subtracting(.shift).isEmpty

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
}
