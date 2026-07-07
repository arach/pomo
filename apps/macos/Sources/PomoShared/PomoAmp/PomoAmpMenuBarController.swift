import AppKit
import SwiftUI

@MainActor
final class PomoAmpMenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: PomoSettings
    private let audio: AudioController
    private let favorites: FavoritesStore
    private var popover: NSPopover?
    private var rightClickMonitor: Any?

    var onToggleHUD: (() -> Void)?
    var onToggleAudio: (() -> Void)?
    var onPasteURL: (() -> Void)?
    var onToggleDrawer: (() -> Void)?
    var onPreviousSection: (() -> Void)?
    var onNextSection: (() -> Void)?
    var onTogglePageMode: (() -> Void)?
    var onToggleBig: (() -> Void)?
    var onToggleCompactMode: (() -> Void)?
    var onShowShortcuts: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?
    var onOpenPomo: (() -> Void)?
    var isBig: (() -> Bool)?
    var isCompactMode: (() -> Bool)?
    var onQuit: (() -> Void)?

    init(settings: PomoSettings, audio: AudioController, favorites: FavoritesStore) {
        self.settings = settings
        self.audio = audio
        self.favorites = favorites
        super.init()
        configureButton()
        refresh()
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = PomoStatusIcon.ampPlayClock(active: audio.isPlaying, size: 18)
        button.toolTip = audio.isPlaying ? "Playing" : "Music"
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        statusItem.length = NSStatusItem.squareLength
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp])

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self, weak button] event in
            guard let button,
                  event.window === button.window
            else { return event }
            Task { @MainActor [weak self] in
                self?.showMenu()
            }
            return nil
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isContextClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isContextClick {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        let popover = makePopover()
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makePopover() -> NSPopover {
        if let popover { return popover }
        let host = NSHostingController(
            rootView: PomoAmpMenuPopoverView(
                settings: settings,
                audio: audio,
                favorites: favorites,
                onShowDeck: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onToggleHUD?()
                },
                onToggleAudio: { [weak self] in self?.onToggleAudio?() },
                onPreviousTrack: { [weak self] in self?.audio.previous() },
                onNextTrack: { [weak self] in self?.audio.next() },
                onPreviousSection: { [weak self] in self?.onPreviousSection?() },
                onNextSection: { [weak self] in self?.onNextSection?() },
                onPasteURL: { [weak self] in self?.onPasteURL?() },
                onToggleVideo: { [weak self] in self?.onToggleDrawer?() },
                onTogglePageMode: { [weak self] in self?.onTogglePageMode?() },
                onOpenInBrowser: { [weak self] in self?.onOpenInBrowser?() },
                onToggleBig: { [weak self] in self?.onToggleBig?() },
                onToggleCompactMode: { [weak self] in self?.onToggleCompactMode?() },
                onShowShortcuts: { [weak self] in self?.onShowShortcuts?() },
                onTogglePomo: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onOpenPomo?()
                },
                onPlayFavorite: { [weak self] favorite in
                    self?.audio.play(urlString: favorite.url)
                    self?.settings.audioURL = favorite.url
                    self?.settings.saveNow()
                }
            )
        )
        host.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.contentViewController = host
        popover.behavior = .transient
        popover.delegate = self
        self.popover = popover
        return popover
    }

    private func showMenu() {
        guard let button = statusItem.button else { return }
        popover?.performClose(nil)
        let menu = NSMenu()
        menu.autoenablesItems = false

        addItem("Show / Hide Pomo Amp", to: menu, action: #selector(toggleHUD))
        addItem("Show / Hide Pomo", to: menu, action: #selector(openPomo), image: PomoStatusIcon.timerRing(size: 16))
        menu.addItem(.separator())
        addItem(audio.isPlaying ? "Pause" : "Play", to: menu, action: #selector(toggleAudio))
        addItem("Previous Timestamp Section", to: menu, action: #selector(previousSection))
        addItem("Next Timestamp Section", to: menu, action: #selector(nextSection))
        addItem("Paste URL", to: menu, action: #selector(pasteURL))
        addItem(audio.videoOpen ? "Hide Video" : "Show Video", to: menu, action: #selector(toggleDrawer))
        addItem(audio.videoExpanded ? "Show Player" : "Show Page", to: menu, action: #selector(togglePageMode))
        addItem((isCompactMode?() ?? false) ? "Expand" : "Compact Mode", to: menu, action: #selector(toggleCompactMode))
        addItem((isBig?() ?? false) ? "Normal Size" : "Big", to: menu, action: #selector(toggleBig))
        addItem("Keyboard Shortcuts", to: menu, action: #selector(showShortcuts))
        menu.addItem(.separator())
        menu.addItem(faceItem())
        menu.addItem(visualizerModeItem())
        menu.addItem(.separator())
        addItem("Quit Pomo Amp", to: menu, action: #selector(quit), keyEquivalent: "q")

        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.minX, y: button.bounds.minY - 4), in: button)
    }

    private func addItem(_ title: String, to menu: NSMenu, action: Selector, keyEquivalent: String = "", image: NSImage? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.image = image
        menu.addItem(item)
    }

    private func faceItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Face", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for face in PomoAmpFace.allCases {
            let row = NSMenuItem(title: face.displayName, action: #selector(selectFace(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = face.rawValue
            row.state = face == settings.pomoAmpFace ? .on : .off
            submenu.addItem(row)
        }
        item.submenu = submenu
        return item
    }

    private func visualizerModeItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Visualizer FPS", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for mode in PomoAmpVisualizerMode.allCases {
            let row = NSMenuItem(title: mode.displayName, action: #selector(selectVisualizerMode(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = mode.rawValue
            row.state = mode == settings.pomoAmpVisualizerMode ? .on : .off
            submenu.addItem(row)
        }
        item.submenu = submenu
        return item
    }

    @objc private func toggleHUD() { onToggleHUD?() }
    @objc private func toggleAudio() { onToggleAudio?() }
    @objc private func pasteURL() { onPasteURL?() }
    @objc private func toggleDrawer() { onToggleDrawer?() }
    @objc private func previousSection() { onPreviousSection?() }
    @objc private func nextSection() { onNextSection?() }
    @objc private func togglePageMode() { onTogglePageMode?() }
    @objc private func toggleBig() { onToggleBig?() }
    @objc private func toggleCompactMode() { onToggleCompactMode?() }
    @objc private func showShortcuts() { onShowShortcuts?() }
    @objc private func openPomo() { onOpenPomo?() }
    @objc private func quit() { onQuit?() }

    @objc private func selectFace(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let face = PomoAmpFace(rawValue: raw)
        else { return }
        settings.pomoAmpFace = face
        settings.saveNow()
        refresh()
    }

    @objc private func selectVisualizerMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = PomoAmpVisualizerMode(rawValue: raw)
        else { return }
        settings.pomoAmpVisualizerMode = mode
        settings.saveNow()
        refresh()
    }
}
