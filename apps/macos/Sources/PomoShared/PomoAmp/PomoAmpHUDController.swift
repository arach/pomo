import AppKit
import SwiftUI

@MainActor
final class PomoAmpHUDController {
    private static let compactDeckSize = NSSize(width: 386, height: 198)
    private static let bigDeckSize = NSSize(width: 640, height: 360)
    private static let compactSize = NSSize(width: compactDeckSize.width, height: compactDeckSize.height + PomoAmpChrome.titleBarHeight)
    private static let bigSize = NSSize(width: bigDeckSize.width, height: bigDeckSize.height + PomoAmpChrome.titleBarHeight)
    private static let compactRolledUpSize = NSSize(width: compactDeckSize.width, height: PomoAmpChrome.shadeBarHeight)
    private static let bigRolledUpSize = NSSize(width: bigDeckSize.width, height: PomoAmpChrome.shadeBarHeight)
    private static let vizInspectorWidth: CGFloat = 268
    private static let savedPanelFrameKey = "pomo.amp.hud.panelFrame"

    private let settings: PomoSettings
    private let audio: AudioController
    private let favorites: FavoritesStore
    private let skin: PomoAmpSkin?
    private var panel: HUDPanel?
    private var keyMonitor: Any?
    private var panelFrameObserverTokens: [NSObjectProtocol] = []
    private(set) var isShown = false

    let chrome: PomoAmpChrome

    var onVisibilityChange: ((Bool) -> Void)?
    var onOpenPomo: (() -> Void)?
    var isBig: Bool { chrome.isBig }
    var isCompactMode: Bool { chrome.isRolledUp }

    init(settings: PomoSettings, audio: AudioController, favorites: FavoritesStore) {
        self.settings = settings
        self.audio = audio
        self.favorites = favorites
        self.skin = PomoAmpSkinStore.firstInstalledSkin()
        self.chrome = PomoAmpChrome(panelSize: Self.compactSize)
    }

    func toggle() {
        isShown ? hide() : show()
    }

    func show() {
        let panel = ensurePanel()
        isShown = true
        installKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
        keepPanelVisible(panel)
        panel.makeKeyAndOrderFront(nil)
        if chrome.isRolledUp {
            audio.setVisualizerActive(false)
            audio.detachDrawer()
        } else {
            audio.setVisualizerActive(true)
            audio.attachDrawer(to: panel)
        }
        onVisibilityChange?(true)
    }

    func hide() {
        guard let panel else { return }
        isShown = false
        chrome.showShortcuts = false
        savePanelFrame(panel.frame)
        removeKeyMonitor()
        audio.detachDrawer()
        audio.setVisualizerActive(false)
        panel.orderOut(nil)
        onVisibilityChange?(false)
    }

    func applyOpacity() {
        panel?.alphaValue = CGFloat(settings.panelOpacity)
    }

    func toggleBigMode() {
        toggleBig()
    }

    func toggleCompactMode() {
        toggleRolledUp()
    }

    func toggleVideoPageMode() {
        if audio.videoExpanded {
            showVideoPlayer()
        } else {
            showVideoPage()
        }
    }

    func showVideo() {
        show()
        showDrawer()
    }

    func hideVideo() {
        hideDrawer()
    }

    func toggleVideo() {
        audio.videoVisible ? hideVideo() : showVideo()
    }

    func showVideoPageMode() {
        show()
        showVideoPage()
    }

    func showVideoPlayerMode() {
        show()
        showVideoPlayer()
    }

    func showShortcutsOverlay() {
        show()
        chrome.showShortcuts = true
    }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let initialSize = effectivePanelSize()
        chrome.panelSize = initialSize
        let panel = HUDPanel(contentSize: initialSize)
        panel.title = "Pomo Amp"
        panel.sharingType = .readOnly
        panel.isExcludedFromWindowsMenu = false
        panel.collectionBehavior.formUnion(.participatesInCycle)
        panel.onKeyDown = { [weak self] event in
            self?.handle(event) ?? false
        }
        let view = PomoAmpHUDRootView(
            settings: settings,
            audio: audio,
            favorites: favorites,
            chrome: chrome,
            htmlSkin: skin,
            onHide: { [weak self] in self?.hide() },
            onOpenPomo: { [weak self] in self?.onOpenPomo?() },
            onPasteURL: { [weak self] in self?.pasteAndPlay() },
            onToggleAudio: { [weak self] in self?.toggleAudio() },
            onToggleDrawer: { [weak self] in self?.toggleDrawer() },
            onExpandVideo: { [weak self] in self?.showVideoPage() },
            onMinimizeVideo: { [weak self] in self?.showVideoPlayer() },
            onShowVideoPage: { [weak self] in self?.showVideoPage() },
            onShowVideoPlayer: { [weak self] in self?.showVideoPlayer() },
            onToggleBig: { [weak self] in self?.toggleBig() },
            onToggleRolledUp: { [weak self] in self?.toggleRolledUp() },
            onSetBig: { [weak self] isBig in self?.setBig(isBig) },
            onToggleVizInspector: { [weak self] in self?.toggleVizInspector() },
            onPreviousSection: { [weak self] in self?.audio.previousTimestampSection() },
            onNextSection: { [weak self] in self?.audio.nextTimestampSection() }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: initialSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        if let restored = restoredPanelFrame(size: initialSize, for: panel) {
            panel.setFrame(restored, display: false)
        } else {
            positionOnActiveScreen(panel)
            savePanelFrame(panel.frame)
        }
        installPanelFrameObservers(panel)
        panel.alphaValue = CGFloat(settings.panelOpacity)
        self.panel = panel
        return panel
    }

    private func restoredPanelFrame(size: NSSize, for panel: NSPanel) -> NSRect? {
        guard let raw = UserDefaults.standard.string(forKey: Self.savedPanelFrameKey) else { return nil }
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

    private func installPanelFrameObservers(_ panel: NSPanel) {
        let center = NotificationCenter.default
        panelFrameObserverTokens.forEach(center.removeObserver)
        panelFrameObserverTokens = [
            center.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.savePanelFrame(panel.frame) }
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.savePanelFrame(panel.frame) }
            }
        ]
    }

    private func savePanelFrame(_ frame: NSRect) {
        guard frame.width > 1, frame.height > 1 else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.savedPanelFrameKey)
    }

    private func positionOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: (frame.midX - panel.frame.width / 2).rounded(),
            y: (frame.midY - panel.frame.height / 2 + frame.height * 0.05).rounded()
        ))
    }

    private func keepPanelVisible(_ panel: NSPanel) {
        let frame = panel.frame
        let clamped = clampedFrame(frame, for: panel)
        if clamped != frame {
            panel.setFrame(clamped, display: false)
            savePanelFrame(clamped)
        }
    }

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

    private func handle(_ event: NSEvent) -> Bool {
        if chrome.showShortcuts, event.keyCode == 53 {
            chrome.showShortcuts = false
            return true
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let onlyShiftOrNone = flags.subtracting([.shift, .numericPad, .function]).isEmpty

        if command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "w": hide(); return true
            case "q":
                PomoAmpDebugLog.write("keyboard quit command-q")
                NSApp.terminate(nil)
                return true
            default: return false
            }
        }

        switch event.keyCode {
        case 49: toggleAudio(); return true
        case 53: hide(); return true
        case 123 where onlyShiftOrNone: audio.previousTimestampSection(); return true
        case 124 where onlyShiftOrNone: audio.nextTimestampSection(); return true
        default: break
        }

        guard onlyShiftOrNone else { return false }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "m": toggleAudio(); return true
        case "b": toggleBig(); return true
        case "c": toggleRolledUp(); return true
        case "p": toggleVideoPageMode(); return true
        case "v":
            if shift { toggleDrawer() }
            else { pasteAndPlay() }
            return true
        case "t":
            settings.pomoAmpFace = settings.pomoAmpFace.next
            settings.saveNow()
            return true
        case "?", "/": chrome.showShortcuts.toggle(); return true
        case "q": hide(); return true
        default: return false
        }
    }

    private func toggleBig() {
        setBig(!chrome.isBig)
    }

    private func setBig(_ isBig: Bool) {
        guard chrome.isBig != isBig || panel == nil else { return }
        chrome.isBig = isBig
        let size = effectivePanelSize()
        chrome.panelSize = size

        guard let panel else { return }
        let old = panel.frame
        let targetFrame = chrome.isRolledUp
            ? NSRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height)
            : NSRect(x: old.midX - size.width / 2, y: old.midY - size.height / 2, width: size.width, height: size.height)
        let target = clampedFrame(targetFrame, for: panel)

        panel.contentView?.setFrameSize(size)
        panel.setFrame(target, display: true)
        savePanelFrame(target)
        audio.attachDrawer(to: panel)
    }

    private func toggleRolledUp() {
        setRolledUp(!chrome.isRolledUp)
    }

    private func setRolledUp(_ rolledUp: Bool) {
        guard chrome.isRolledUp != rolledUp || panel == nil else { return }
        chrome.isRolledUp = rolledUp
        if rolledUp {
            chrome.showShortcuts = false
        }
        let size = effectivePanelSize()
        chrome.panelSize = size

        guard let panel else { return }
        let old = panel.frame
        let target = clampedFrame(
            NSRect(
                x: old.minX,
                y: old.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            for: panel
        )

        panel.contentView?.setFrameSize(size)
        panel.setFrame(target, display: true)
        savePanelFrame(target)
        if rolledUp {
            audio.setVisualizerActive(false)
        } else {
            audio.setVisualizerActive(true)
        }
        audio.attachDrawer(to: panel)
    }

    private func toggleVizInspector() {
        #if DEBUG
        chrome.showVizInspector.toggle()
        let size = effectivePanelSize()
        chrome.panelSize = size

        guard let panel else { return }
        let old = panel.frame
        let target = clampedFrame(
            NSRect(
                x: old.minX,
                y: old.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            for: panel
        )
        panel.contentView?.setFrameSize(size)
        panel.setFrame(target, display: true)
        savePanelFrame(target)
        audio.attachDrawer(to: panel)
        #endif
    }

    private func effectivePanelSize() -> NSSize {
        var size: NSSize
        if chrome.isRolledUp {
            size = chrome.isBig ? Self.bigRolledUpSize : Self.compactRolledUpSize
        } else {
            size = chrome.isBig ? Self.bigSize : Self.compactSize
        }
        #if DEBUG
        if !chrome.isRolledUp, chrome.showVizInspector {
            size.width += Self.vizInspectorWidth
        }
        #endif
        return size
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

    private func toggleAudio() {
        if audio.isPlaying {
            audio.pause()
        } else {
            audio.resume(stored: preferredAudioURL())
        }
    }

    private func toggleDrawer() {
        PomoAmpDebugLog.write("hud controller toggleDrawer begin videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        defer {
            PomoAmpDebugLog.write("hud controller toggleDrawer end videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        }
        if audio.videoVisible {
            hideDrawer()
        } else {
            showDrawer()
        }
    }

    private func showDrawer() {
        PomoAmpDebugLog.write("hud controller showDrawer begin videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        if chrome.isRolledUp {
            setRolledUp(false)
        }
        ensureAudioLoadedForVideo()
        audio.attachDrawer(to: panel)
        audio.setVideoVisible(true)
        PomoAmpDebugLog.write("hud controller showDrawer end videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
    }

    private func hideDrawer() {
        PomoAmpDebugLog.write("hud controller hideDrawer begin videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        audio.setVideoVisible(false)
        PomoAmpDebugLog.write("hud controller hideDrawer end videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
    }

    private func showVideoPage() {
        PomoAmpDebugLog.write("hud controller showVideoPage begin videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        showDrawer()
        audio.setOriginalPageVisible(true)
        PomoAmpDebugLog.write("hud controller showVideoPage end videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
    }

    private func showVideoPlayer() {
        PomoAmpDebugLog.write("hud controller showVideoPlayer begin videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
        showDrawer()
        audio.setOriginalPageVisible(false)
        PomoAmpDebugLog.write("hud controller showVideoPlayer end videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded)")
    }

    private func ensureAudioLoadedForVideo() {
        guard !audio.isPlaying, audio.currentURL.isEmpty else { return }
        let url = preferredAudioURL()
        if !url.isEmpty { audio.play(urlString: url) }
    }

    private func pasteAndPlay() {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              WebAudioPlayer.isPlayableSource(raw)
        else { return }
        settings.audioURL = raw
        settings.saveNow()
        audio.play(urlString: raw)
    }

    private func preferredAudioURL() -> String {
        if !audio.currentURL.isEmpty { return audio.currentURL }
        if !settings.audioURL.isEmpty { return settings.audioURL }
        return favorites.items.first?.url ?? ""
    }
}
