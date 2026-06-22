import SwiftUI
import HudsonUI

/// Compact settings surface, opened from the menu bar (or ⌘, in the HUD). Native
/// controls dressed in Hudson tokens for a consistent look.
struct SettingsView: View {
    @Bindable var settings: PomoSettings
    var account: AccountStatus
    var onClose: () -> Void
    var onAudioPlay: (String) -> Void = { _ in }
    var onAudioPause: () -> Void = {}
    var onAudioStop: () -> Void = {}
    var onSignIn: () -> Void = {}
    var onSignOut: () -> Void = {}
    var onImportLogin: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HudSpacing.xxl) {
                header

                section("DURATIONS") {
                    stepperRow("Focus", value: settings.binding(\.focusMinutes), suffix: "min")
                    stepperRow("Short break", value: settings.binding(\.shortBreakMinutes), suffix: "min")
                    stepperRow("Long break", value: settings.binding(\.longBreakMinutes), suffix: "min")
                    stepperRow("Long break every", value: settings.binding(\.longBreakInterval), suffix: "sessions", range: 2...8)
                    toggleRow("Auto-start next session", isOn: settings.binding(\.autoStartNext))
                }

                section("APPEARANCE") {
                    HStack {
                        rowLabel("Watchface")
                        Spacer()
                        Picker("", selection: settings.binding(\.watchface)) {
                            ForEach(Watchface.allCases) { face in
                                Text(face.displayName).tag(face)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    sliderRow("Opacity", value: settings.binding(\.panelOpacity), range: 0.4...1.0)
                    sliderRow("Background blur", value: settings.binding(\.backgroundBlur), range: 0.0...1.0)
                }

                section("SOUND") {
                    toggleRow("Completion chime", isOn: settings.binding(\.soundEnabled))
                    sliderRow("Volume", value: settings.binding(\.volume), range: 0.0...1.0)
                        .opacity(settings.soundEnabled ? 1 : 0.4)
                        .disabled(!settings.soundEnabled)
                }

                section("BACKGROUND AUDIO") {
                    BrandTextField(
                        text: settings.binding(\.audioURL),
                        placeholder: "Paste a YouTube link…",
                        textColor: HudPalette.ink,
                        selectionColor: PomoBrand.accent
                    )
                        .padding(.horizontal, HudSpacing.lg)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .fill(HudPalette.bg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HudRadius.standard)
                                        .stroke(HudPalette.border, lineWidth: 1)
                                )
                        )

                    HStack(spacing: HudSpacing.md) {
                        HudButton("Play", icon: "play.fill", style: .primary(.green)) {
                            onAudioPlay(settings.audioURL)
                        }
                        HudButton("Pause", icon: "pause.fill", style: .secondary) { onAudioPause() }
                        HudButton("Stop", style: .secondary) { onAudioStop() }
                        Spacer()
                    }

                    sliderRow("Volume", value: settings.binding(\.audioVolume), range: 0.0...1.0)

                    Text("Audio only — no video. Works with playlists & live streams.")
                        .font(HudFont.mono(HudTextSize.xs))
                        .foregroundStyle(HudPalette.dim)
                }

                section("YOUTUBE ACCOUNT") {
                    HStack(spacing: HudSpacing.md) {
                        accountAvatar
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(HudPalette.border, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.signedIn ? (account.name ?? "Signed in") : "Not signed in")
                                .font(HudFont.mono(HudTextSize.sm))
                                .foregroundStyle(HudPalette.ink)
                            Text(account.signedIn ? "Ad-free with Premium" : "Sign in to skip ads")
                                .font(HudFont.mono(HudTextSize.xs))
                                .foregroundStyle(HudPalette.dim)
                        }
                        Spacer()
                        if account.signedIn {
                            HudButton("Sign out", style: .secondary, action: onSignOut)
                        } else {
                            HudButton("Sign in", icon: "person.crop.circle", style: .primary(.green), action: onSignIn)
                        }
                    }
                    HStack {
                        HudButton("Import login from browser", style: .secondary, action: onImportLogin)
                        Spacer()
                    }
                }

                section("SHORTCUT") {
                    HStack {
                        rowLabel("Summon HUD")
                        Spacer()
                        HotkeyRecorder(display: settings.hotkeyDisplay) { keyCode, modifiers, label in
                            settings.setHotkey(keyCode: keyCode, modifiers: modifiers, display: label)
                        }
                    }
                    Text("Press a combination including ⌘, ⌥, or ⌃.")
                        .font(HudFont.mono(HudTextSize.xs))
                        .foregroundStyle(HudPalette.dim)
                }

                Divider().overlay(HudPalette.border)

                HStack {
                    Text("Summon the HUD with \(settings.hotkeyDisplay)")
                        .font(HudFont.mono(HudTextSize.xs))
                        .foregroundStyle(HudPalette.dim)
                    Spacer()
                    HudButton("Done", style: .primary(.green)) { onClose() }
                }
            }
            .padding(HudSpacing.huge)
        }
        .frame(width: 380, height: 740)
        .background(HudPalette.bg)
        .environment(\.hudTheme, .default)
    }

    private var header: some View {
        HStack(spacing: HudSpacing.md) {
            Image(systemName: "hourglass")
                .foregroundStyle(HudPalette.accent)
            Text("Pomo")
                .font(HudFont.mono(HudTextSize.lg, weight: .semibold))
                .foregroundStyle(HudPalette.ink)
            Spacer()
            Text("Settings")
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .tracking(2)
                .foregroundStyle(HudPalette.muted)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder private var accountAvatar: some View {
        if let img = account.avatar {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: account.signedIn ? "person.crop.circle.fill" : "person.crop.circle")
                .resizable().aspectRatio(contentMode: .fit)
                .foregroundStyle(account.signedIn ? PomoBrand.accent : HudPalette.dim)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.lg) {
            Text(title)
                .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                .tracking(2)
                .foregroundStyle(HudPalette.dim)
            VStack(alignment: .leading, spacing: HudSpacing.md) {
                content()
            }
            .padding(HudSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.card)
                    .fill(HudPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: HudRadius.card)
                            .stroke(HudPalette.border, lineWidth: 1)
                    )
            )
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(HudFont.ui(HudTextSize.sm))
            .foregroundStyle(HudPalette.ink)
    }

    private func stepperRow(_ label: String, value: Binding<Int>, suffix: String, range: ClosedRange<Int> = 1...99) -> some View {
        HStack {
            rowLabel(label)
            Spacer()
            Text("\(value.wrappedValue) \(suffix)")
                .font(HudFont.mono(HudTextSize.sm, weight: .medium))
                .foregroundStyle(HudPalette.muted)
                .frame(minWidth: 92, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            rowLabel(label)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(HudPalette.accent)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            rowLabel(label)
            Spacer()
            Slider(value: value, in: range)
                .frame(width: 180)
                .tint(HudPalette.accent)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(HudFont.mono(HudTextSize.xs, weight: .medium))
                .foregroundStyle(HudPalette.muted)
                .frame(width: 38, alignment: .trailing)
        }
    }
}
