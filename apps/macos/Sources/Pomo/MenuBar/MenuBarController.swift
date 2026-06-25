import AppKit
import SwiftUI

/// The menu-bar presence: a status item that shows the live countdown when a
/// session is active. **Left-click** opens a frosted SwiftUI popover with the
/// transport + pickers (`MenuPopoverView`); **right-click / control-click**
/// opens a small native utility menu. The HUD stays hotkey-driven — the popover
/// carries a "Show HUD" affordance for discoverability.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let model: TimerModel
    private let settings: PomoSettings
    private let audio: AudioController
    private let favorites: FavoritesStore
    private var popover: NSPopover?
    private var rightClickMonitor: Any?

    var onShowHUD: (() -> Void)?
    var onToggleHUD: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenStats: (() -> Void)?
    var onSetIntent: (() -> Void)?
    var onQuit: (() -> Void)?
    var onToggleAudio: (() -> Void)?
    var onStopAudio: (() -> Void)?
    var onPlayFavorite: ((Favorite) -> Void)?

    init(model: TimerModel, settings: PomoSettings, audio: AudioController, favorites: FavoritesStore) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.model = model
        self.settings = settings
        self.audio = audio
        self.favorites = favorites
        super.init()
        configureButton()
        refresh()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarController.ringMarkImage()
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp])     // left = popover; right handled below

        // Status-item right-clicks aren't reliably delivered as the button's
        // action, so catch the right mouse-down ourselves and show the menu.
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button, event.window === button.window else { return event }
                self.menuLog("right-mouse-down → showMenu")
                self.showMenu()
                return nil
            }
        }
    }

    private func menuLog(_ line: String) {
        let entry = "[pomo-menu] \(line)\n"
        let url = URL(fileURLWithPath: "/tmp/pomo-menu.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(entry.data(using: .utf8) ?? Data()); try? handle.close()
        } else { try? entry.data(using: .utf8)?.write(to: url) }
    }

    /// The Pomo ring mark, drawn as a template image so the menu bar tints it
    /// to match the system appearance. Mirrors the website / app logo: a faint
    /// ring, a brighter top-right progress arc, a 12 o'clock tick, a centre dot.
    private static func ringMarkImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let center = NSPoint(x: 9, y: 9)
            let radius: CGFloat = 6.0

            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            ring.lineWidth = 1.3
            NSColor.black.withAlphaComponent(0.5).setStroke()
            ring.stroke()

            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 0, clockwise: true)
            arc.lineWidth = 1.7
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()

            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: center.x, y: center.y + radius + 1.8))
            tick.line(to: NSPoint(x: center.x, y: center.y + radius - 0.4))
            tick.lineWidth = 1.5
            tick.lineCapStyle = .round
            NSColor.black.setStroke()
            tick.stroke()

            let dotRadius: CGFloat = 1.4
            let dotRect = NSRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                 width: dotRadius * 2, height: dotRadius * 2)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }
        image.isTemplate = true
        return image
    }

    /// Update the countdown title. Called from `TimerModel.onTick`.
    func refresh() {
        guard let button = statusItem.button else { return }
        if model.isIdle {
            button.title = ""
        } else {
            let prefix = model.isPaused ? "❚❚ " : ""
            button.title = " \(prefix)\(model.clock)"
        }
    }

    @objc private func handleClick() {
        menuLog("left-click action; control=\(NSApp.currentEvent?.modifierFlags.contains(.control) == true)")
        if NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            showMenu()             // control-click → menu, like a right-click
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover (left-click)

    /// Programmatic open/close (e.g. `pomo://menu`).
    func toggleMenu() { togglePopover() }

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
        // Match the popover chrome (arrow + border) and its behind-window frost —
        // which sample at the window level — to Pomo's appearance override, so a
        // forced Light/Dark popover doesn't show a system-coloured arrow or a
        // mistinted frosted panel. Set on every open so it tracks live changes.
        popover.appearance = popoverAppearance()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // An accessory app isn't active by default, so make the popover's window
        // key — otherwise its buttons/toggles won't take the first click.
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makePopover() -> NSPopover {
        if let popover { return popover }
        let host = NSHostingController(
            rootView: MenuPopoverView(
                model: model,
                settings: settings,
                audio: audio,
                favorites: favorites,
                onShowHUD: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onShowHUD?()
                },
                onOpenSettings: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onOpenSettings?()
                },
                onOpenStats: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onOpenStats?()
                },
                onToggleAudio: { [weak self] in self?.onToggleAudio?() },
                onStopAudio: { [weak self] in self?.onStopAudio?() },
                onPlayFavorite: { [weak self] favorite in self?.onPlayFavorite?(favorite) }
            )
        )
        host.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.contentViewController = host
        popover.behavior = .transient
        // No forced appearance — the popover sits against the user's desktop, so
        // it follows the system light/dark setting (MenuPopoverView themes itself
        // off `colorScheme`). The HUD stays dark; the menu popover adapts.
        popover.delegate = self
        self.popover = popover
        return popover
    }

    /// The popover's window appearance for the current override. `nil` follows
    /// the system (Auto); `.aqua` / `.darkAqua` pin it to match the Settings
    /// Light / Dark choice.
    private func popoverAppearance() -> NSAppearance? {
        switch settings.appearanceMode {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Native menu (right-click) — a small utility surface

    /// Show the right-click utility menu, dropping it just below the status item
    /// (the previous code anchored it *above* the bar, off-screen).
    private func showMenu() {
        guard let button = statusItem.button else { return }
        popover?.performClose(nil)
        let menu = buildMenu()
        menuLog("popUp menu with \(menu.items.count) items")
        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.minX, y: button.bounds.minY - 4), in: button)
    }

    /// The right-click menu is the "old-school list" way to change config —
    /// session, timer length, watchface, sound — mirroring the visual popover.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        // Manage enablement ourselves so "idle only" items grey out correctly
        // (autoenable would otherwise re-enable anything with a valid target).
        menu.autoenablesItems = false

        let toggle = NSMenuItem(title: "Show / Hide HUD", action: #selector(toggleHUD), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let hint = NSMenuItem(title: "    \(settings.hotkeyDisplay)", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        menu.addItem(intentItem())

        menu.addItem(.separator())

        menu.addItem(sessionItem())
        menu.addItem(durationItem())
        menu.addItem(watchfaceItem())

        let sound = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        sound.target = self
        sound.state = settings.soundEnabled ? .on : .off
        menu.addItem(sound)

        menu.addItem(.separator())

        let stats = NSMenuItem(title: "Stats…", action: #selector(openStats), keyEquivalent: "")
        stats.target = self
        menu.addItem(stats)

        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let quit = NSMenuItem(title: "Quit Pomo", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func subMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        return m
    }

    /// Intent ▸ — set / clear "what you're working on", and re-pick a recent
    /// one. The title reflects the live intent so it reads at a glance.
    private func intentItem() -> NSMenuItem {
        let hasIntent = !model.intent.isEmpty
        let title = hasIntent ? "Intent: \(truncated(model.intent))" : "Intent: none"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = subMenu()

        let set = NSMenuItem(title: hasIntent ? "Change…" : "Set Intent…",
                             action: #selector(setIntent), keyEquivalent: "i")
        set.target = self
        sub.addItem(set)

        let clear = NSMenuItem(title: "Clear Intent", action: #selector(clearIntent), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = hasIntent
        sub.addItem(clear)

        // Recently used intents — one click to bring one back.
        let recents = settings.recentIntents.filter { $0.caseInsensitiveCompare(model.intent) != .orderedSame }
        if !recents.isEmpty {
            sub.addItem(.separator())
            let header = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
            header.isEnabled = false
            sub.addItem(header)
            for intent in recents {
                let row = NSMenuItem(title: truncated(intent), action: #selector(selectRecentIntent(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = intent
                sub.addItem(row)
            }
        }

        item.submenu = sub
        return item
    }

    private func truncated(_ text: String, max: Int = 40) -> String {
        text.count > max ? String(text.prefix(max - 1)) + "…" : text
    }

    /// Session ▸ — pick the interval (only meaningful while idle).
    private func sessionItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Session", action: nil, keyEquivalent: "")
        item.isEnabled = model.isIdle
        let sub = subMenu()
        for type in SessionType.allCases {
            let row = NSMenuItem(title: type.shortLabel, action: #selector(selectSession(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = type.rawValue
            row.state = (type == model.sessionType) ? .on : .off
            row.isEnabled = model.isIdle
            sub.addItem(row)
        }
        item.submenu = sub
        return item
    }

    /// Duration ▸ — quick-set the current session's length (persists; idle only).
    private func durationItem() -> NSMenuItem {
        let current = settings.minutes(for: model.sessionType)
        let item = NSMenuItem(title: "Duration: \(current) min", action: nil, keyEquivalent: "")
        item.isEnabled = model.isIdle
        let sub = subMenu()
        let presets = [5, 10, 15, 20, 25, 30, 45, 60]
        let values = Array(Set(presets + [current])).sorted()
        for minutes in values {
            let row = NSMenuItem(title: "\(minutes) min", action: #selector(selectDuration(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = minutes
            row.state = (minutes == current) ? .on : .off
            row.isEnabled = model.isIdle
            sub.addItem(row)
        }
        item.submenu = sub
        return item
    }

    /// Watchface ▸ — switch the face (always available).
    private func watchfaceItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Watchface", action: nil, keyEquivalent: "")
        let sub = subMenu()
        for face in Watchface.allCases {
            let row = NSMenuItem(title: face.displayName, action: #selector(selectFace(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = face.rawValue
            row.state = (face == settings.watchface) ? .on : .off
            sub.addItem(row)
        }
        item.submenu = sub
        return item
    }

    // MARK: - Actions

    @objc private func toggleHUD() { onToggleHUD?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openStats() { onOpenStats?() }
    @objc private func quit() { onQuit?() }

    @objc private func toggleSound() {
        settings.soundEnabled.toggle()
        settings.saveNow()
    }

    @objc private func setIntent() { onSetIntent?() }

    @objc private func clearIntent() { model.setIntent("") }

    @objc private func selectRecentIntent(_ sender: NSMenuItem) {
        guard let intent = sender.representedObject as? String else { return }
        model.setIntent(intent)
    }

    @objc private func selectSession(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let type = SessionType(rawValue: raw) else { return }
        model.setSessionType(type)
        refresh()
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        settings.setMinutes(minutes, for: model.sessionType)
    }

    @objc private func selectFace(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let face = Watchface(rawValue: raw) else { return }
        settings.watchface = face
        settings.saveNow()
    }
}
