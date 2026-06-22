import SwiftUI
import Observation

/// Persisted user preferences. Stored as JSON in
/// `~/Library/Application Support/Pomo/settings.json`.
///
/// Mutations made through `binding(_:)` auto-save (debounced) and notify
/// `onChange`, which the app uses to keep an idle timer's duration in sync with
/// edited values.
@MainActor
@Observable
final class PomoSettings {
    // Durations (minutes)
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var longBreakInterval: Int = 4

    // Behaviour
    var autoStartNext: Bool = false

    // Presentation
    var watchface: Watchface = .minimal
    var panelOpacity: Double = 1.0
    // Strength of the behind-window frost (0 = clear glass, 1 = full blur).
    // Independent of `panelOpacity` so a see-through panel can still read as
    // frosted glass.
    var backgroundBlur: Double = 1.0

    // Sound
    var soundEnabled: Bool = true
    var volume: Double = 0.6

    // Background audio (YouTube / web link)
    var audioURL: String = ""
    var audioVolume: Double = 0.6

    // The current session intent, persisted so it survives a relaunch.
    var intent: String = ""

    // Most-recent intents (newest first) for one-click re-use from the menu.
    var recentIntents: [String] = []
    private static let maxRecentIntents = 6

    // Global summon hotkey. Stored as a Carbon key code + Carbon modifier mask,
    // plus a pre-rendered display string (e.g. "⌃⌥⇧⌘P"). Defaults to Hyper+P.
    var hotkeyKeyCode: Int = Int(CarbonKeyCode.p)
    var hotkeyModifiers: Int = Int(CarbonModifier.hyper)
    var hotkeyDisplay: String = "⌃⌥⇧⌘P"

    /// Carbon values for `HotkeyManager.register`.
    var hotkeyCarbon: (keyCode: UInt32, modifiers: UInt32) {
        (UInt32(hotkeyKeyCode), UInt32(hotkeyModifiers))
    }

    /// Record a newly captured hotkey, persist, and notify (re-registers it).
    func setHotkey(keyCode: UInt32, modifiers: UInt32, display: String) {
        hotkeyKeyCode = Int(keyCode)
        hotkeyModifiers = Int(modifiers)
        hotkeyDisplay = display
        saveNow()
        onChange?()
    }

    /// Persist the session intent (debounced). Doesn't fire `onChange` — intent
    /// isn't a timer/hotkey/audio setting, so nothing needs re-syncing.
    func updateIntent(_ text: String) {
        intent = text
        scheduleSave()
    }

    /// Remember a committed intent for quick re-use: de-dupe (case-insensitive),
    /// move to front, cap the list, persist. No `onChange` (nothing to re-sync).
    func noteRecentIntent(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentIntents.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentIntents.insert(trimmed, at: 0)
        if recentIntents.count > Self.maxRecentIntents {
            recentIntents = Array(recentIntents.prefix(Self.maxRecentIntents))
        }
        saveNow()
    }

    /// Called whenever a persisted value changes (after save).
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var saveWorkItem: DispatchWorkItem?

    init() {
        load()
    }

    /// Minutes configured for a given session type.
    func minutes(for type: SessionType) -> Int {
        switch type {
        case .focus:      return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak:  return longBreakMinutes
        }
    }

    /// Seconds configured for a given session type.
    func seconds(for type: SessionType) -> Int {
        max(60, minutes(for: type) * 60)
    }

    /// Set the persisted duration (minutes) for a session type, then persist and
    /// notify — `onChange` re-syncs an idle timer to the new length. Used by the
    /// menu-bar Duration list.
    func setMinutes(_ minutes: Int, for type: SessionType) {
        let clamped = max(1, min(99, minutes))
        switch type {
        case .focus:      focusMinutes = clamped
        case .shortBreak: shortBreakMinutes = clamped
        case .longBreak:  longBreakMinutes = clamped
        }
        saveNow()
        onChange?()
    }

    // MARK: - Bindings

    /// A write-through binding that persists and fires `onChange` on every set.
    /// Used by the settings UI so edits survive relaunch immediately.
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<PomoSettings, T>) -> Binding<T> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { newValue in
                self[keyPath: keyPath] = newValue
                self.scheduleSave()
                self.onChange?()
            }
        )
    }

    // MARK: - Persistence

    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pomo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()

    private struct DTO: Codable {
        var focusMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var longBreakInterval: Int
        var autoStartNext: Bool
        var watchface: Watchface
        var panelOpacity: Double
        var backgroundBlur: Double?
        var soundEnabled: Bool
        var volume: Double
        // Optional so settings files written before these fields still decode.
        var hotkeyKeyCode: Int?
        var hotkeyModifiers: Int?
        var hotkeyDisplay: String?
        var audioURL: String?
        var audioVolume: Double?
        var intent: String?
        var recentIntents: [String]?
    }

    private func snapshot() -> DTO {
        DTO(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            longBreakInterval: longBreakInterval,
            autoStartNext: autoStartNext,
            watchface: watchface,
            panelOpacity: panelOpacity,
            backgroundBlur: backgroundBlur,
            soundEnabled: soundEnabled,
            volume: volume,
            hotkeyKeyCode: hotkeyKeyCode,
            hotkeyModifiers: hotkeyModifiers,
            hotkeyDisplay: hotkeyDisplay,
            audioURL: audioURL,
            audioVolume: audioVolume,
            intent: intent,
            recentIntents: recentIntents
        )
    }

    private func apply(_ dto: DTO) {
        focusMinutes = max(1, dto.focusMinutes)
        shortBreakMinutes = max(1, dto.shortBreakMinutes)
        longBreakMinutes = max(1, dto.longBreakMinutes)
        longBreakInterval = max(1, dto.longBreakInterval)
        autoStartNext = dto.autoStartNext
        watchface = dto.watchface
        panelOpacity = min(1.0, max(0.3, dto.panelOpacity))
        if let blur = dto.backgroundBlur { backgroundBlur = min(1.0, max(0.0, blur)) }
        soundEnabled = dto.soundEnabled
        volume = min(1.0, max(0.0, dto.volume))
        if let code = dto.hotkeyKeyCode { hotkeyKeyCode = code }
        if let mods = dto.hotkeyModifiers { hotkeyModifiers = mods }
        if let display = dto.hotkeyDisplay, !display.isEmpty { hotkeyDisplay = display }
        if let url = dto.audioURL { audioURL = url }
        if let vol = dto.audioVolume { audioVolume = min(1.0, max(0.0, vol)) }
        if let intent = dto.intent { self.intent = intent }
        if let intents = dto.recentIntents {
            recentIntents = Array(intents.prefix(Self.maxRecentIntents))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let dto = try? JSONDecoder().decode(DTO.self, from: data)
        else { return }
        apply(dto)
    }

    /// Debounced write so dragging a slider doesn't hammer the disk.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func saveNow() {
        let dto = snapshot()
        guard let data = try? JSONEncoder().encode(dto) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
