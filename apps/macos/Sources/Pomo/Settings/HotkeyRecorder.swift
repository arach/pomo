import SwiftUI
import AppKit
import Carbon
import HudsonUI

/// A small control that captures a global hotkey. Click "Change", press a
/// modifier+key combination, and it reports the Carbon key code + modifier mask
/// + a display string back to the caller.
struct HotkeyRecorder: View {
    let display: String
    let onCapture: (UInt32, UInt32, String) -> Void

    @State private var recording = false
    @State private var monitor = KeyMonitorHolder()

    var body: some View {
        HStack(spacing: HudSpacing.md) {
            Text(recording ? "Recording…" : display)
                .font(HudFont.mono(HudTextSize.sm, weight: .semibold))
                .foregroundStyle(recording ? HudPalette.accent : HudPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 108, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(HudPalette.bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .stroke(recording ? HudPalette.accent : HudPalette.border, lineWidth: 1)
                        )
                )

            HudButton(recording ? "Cancel" : "Change", style: .secondary) {
                recording.toggle()
            }
            .fixedSize()
        }
        .onChange(of: recording) { _, isRecording in
            if isRecording {
                monitor.start { keyCode, modifiers, label in
                    onCapture(keyCode, modifiers, label)
                    recording = false
                }
            } else {
                monitor.stop()
            }
        }
        .onDisappear { monitor.stop() }
    }
}

/// Holds a local key-down monitor for the duration of a recording session.
@MainActor
final class KeyMonitorHolder {
    private var monitor: Any?

    func start(_ onCapture: @escaping (UInt32, UInt32, String) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Require a non-shift modifier so the hotkey can't collide with typing.
            let hasPrimaryModifier = flags.contains(.command)
                || flags.contains(.option)
                || flags.contains(.control)
            guard hasPrimaryModifier else { return nil } // swallow, keep waiting

            let carbon = HotkeyTranslation.carbonModifiers(from: flags)
            let label = HotkeyTranslation.display(flags: flags, event: event)
            onCapture(UInt32(event.keyCode), carbon, label)
            self?.stop()
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// NSEvent ⇄ Carbon translation helpers.
enum HotkeyTranslation {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    static func display(flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols + keyLabel(for: event)
    }

    private static func keyLabel(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                return chars.uppercased()
            }
            return "Key\(event.keyCode)"
        }
    }
}
