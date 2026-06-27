import AppKit
import Carbon

/// Minimal Carbon global-hotkey wrapper (no accessibility permission required),
/// adapted from openscout's ScoutHUD HotkeyManager. Used for the system-wide
/// "summon the HUD" shortcut.
@MainActor private var hotkeyCallbacks: [UInt32: () -> Void] = [:]
@MainActor private var eventHandlerInstalled = false

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    private init() {}

    private func ensureEventHandler() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                let id = hotkeyID.id
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { hotkeyCallbacks[id]?() }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    @discardableResult
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> Bool {
        ensureEventHandler()

        if let existing = hotKeyRefs[id] {
            UnregisterEventHotKey(existing)
            hotKeyRefs.removeValue(forKey: id)
        }
        hotkeyCallbacks[id] = callback

        let hotKeyID = EventHotKeyID(signature: OSType(0x504F4D4F), id: id) // "POMO"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if let ref, status == noErr {
            hotKeyRefs[id] = ref
            return true
        }
        return false
    }

    func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: id)
            hotkeyCallbacks.removeValue(forKey: id)
        }
    }
}

/// Carbon modifier masks. `hyper` = ⌃⌥⇧⌘ (matches the Tauri app's Hyperkey+P).
enum CarbonModifier {
    static let hyper: UInt32 = UInt32(controlKey | optionKey | shiftKey | cmdKey)
}

/// Virtual key codes from HIToolbox/Events.h that we reference by name.
enum CarbonKeyCode {
    static let p: UInt32 = 35 // kVK_ANSI_P
    static let y: UInt32 = 16 // kVK_ANSI_Y
}
