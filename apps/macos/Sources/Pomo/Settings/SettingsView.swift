import SwiftUI
import HudsonUI

/// The Settings window — a resizable, two-pane surface (sidebar nav + detail)
/// that follows the system light/dark appearance via `AppPalette`. Native
/// controls dressed in adaptive tokens, grouped into cards. Opened from the
/// menu bar or ⌘, in the HUD.
struct SettingsView: View {
    @Bindable var settings: PomoSettings
    @Bindable var favorites: FavoritesStore
    var account: AccountStatus
    var onClose: () -> Void
    var onAudioPlay: (String) -> Void = { _ in }
    var onAudioPause: () -> Void = {}
    var onAudioStop: () -> Void = {}
    var onSignIn: () -> Void = {}
    var onSignOut: () -> Void = {}
    var onImportLogin: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @State private var tab: SettingsTab = .general
    @State private var newFavoriteURL = ""
    @State private var newFavoriteTitle = ""

    private var pal: AppPalette { .resolve(scheme) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(pal.hairline).frame(width: 1)
            detail
        }
        .frame(minWidth: 640, idealWidth: 720, maxWidth: .infinity,
               minHeight: 480, idealHeight: 560, maxHeight: .infinity)
        .background(pal.bg)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: HudSpacing.sm) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.accent)
                Text("Pomo")
                    .font(HudFont.mono(HudTextSize.md, weight: .semibold))
                    .foregroundStyle(pal.ink)
            }
            // Clear the window's traffic-light controls (transparent titlebar).
            .padding(.top, 34)
            .padding(.horizontal, HudSpacing.lg)
            .padding(.bottom, HudSpacing.lg)

            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { item in
                    navRow(item)
                }
            }
            .padding(.horizontal, HudSpacing.sm)

            Spacer(minLength: HudSpacing.lg)

            if let version = Self.appVersion {
                Text("Version \(version)")
                    .font(HudFont.mono(HudTextSize.micro))
                    .foregroundStyle(pal.dim)
                    .padding(.horizontal, HudSpacing.lg)
                    .padding(.bottom, HudSpacing.lg)
            }
        }
        .frame(width: 190)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(pal.sidebar)
    }

    private func navRow(_ item: SettingsTab) -> some View {
        let selected = item == tab
        return Button { tab = item } label: {
            HStack(spacing: HudSpacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? pal.action : pal.muted)
                Text(item.title)
                    .font(HudFont.ui(HudTextSize.sm, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? pal.ink : pal.muted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HudSpacing.md)
            .padding(.vertical, HudSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.standard)
                    .fill(selected ? pal.surfaceHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(spacing: 0) {
            hero
            Rectangle().fill(pal.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: HudSpacing.xl) {
                    switch tab {
                    case .general:    generalTab
                    case .appearance: appearanceTab
                    case .audio:      audioTab
                    case .shortcuts:  shortcutsTab
                    }
                }
                .padding(HudSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pal.bg)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: HudSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(HudFont.mono(HudTextSize.lg, weight: .semibold))
                    .foregroundStyle(pal.ink)
                Text(tab.subtitle)
                    .font(HudFont.ui(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
            }
            Spacer()
            button("Done", kind: .primary) { onClose() }
        }
        .padding(.horizontal, HudSpacing.xxl)
        .padding(.top, 30)
        .padding(.bottom, HudSpacing.lg)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            group("DURATIONS") {
                row("Focus") { stepperControl(settings.binding(\.focusMinutes), suffix: "min") }
                rowDivider
                row("Short break") { stepperControl(settings.binding(\.shortBreakMinutes), suffix: "min") }
                rowDivider
                row("Long break") { stepperControl(settings.binding(\.longBreakMinutes), suffix: "min") }
                rowDivider
                row("Long break every") { stepperControl(settings.binding(\.longBreakInterval), suffix: "sessions", range: 2...8) }
                rowDivider
                row("Auto-start next session") { toggle(settings.binding(\.autoStartNext)) }
            }

            group("SOUND") {
                row("Completion chime") { toggle(settings.binding(\.soundEnabled)) }
                rowDivider
                row("Volume") { sliderControl(settings.binding(\.volume)) }
                    .opacity(settings.soundEnabled ? 1 : 0.4)
                    .disabled(!settings.soundEnabled)
            }
        }
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            group("WATCHFACE") {
                row("Style") {
                    Picker("", selection: settings.binding(\.watchface)) {
                        ForEach(Watchface.allCases) { face in
                            Text(face.displayName).tag(face)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 160)
                }
            }

            group("HUD") {
                row("Opacity") { sliderControl(settings.binding(\.panelOpacity), range: 0.4...1.0) }
                rowDivider
                row("Background blur") { sliderControl(settings.binding(\.backgroundBlur), range: 0.0...1.0) }
            }
        }
    }

    private var audioTab: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            group("BACKGROUND AUDIO") {
                VStack(alignment: .leading, spacing: HudSpacing.lg) {
                    BrandTextField(
                        text: settings.binding(\.audioURL),
                        placeholder: "Paste a YouTube link…",
                        textColor: pal.ink,
                        selectionColor: pal.action
                    )
                    .padding(.horizontal, HudSpacing.md)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: HudRadius.standard)
                            .fill(pal.inset)
                            .overlay(
                                RoundedRectangle(cornerRadius: HudRadius.standard)
                                    .stroke(pal.border, lineWidth: 1)
                            )
                    )

                    HStack(spacing: HudSpacing.sm) {
                        button("Play", icon: "play.fill", kind: .primary) { onAudioPlay(settings.audioURL) }
                        button("Pause", icon: "pause.fill") { onAudioPause() }
                        button("Stop") { onAudioStop() }
                        Spacer()
                    }

                    HStack(spacing: HudSpacing.sm) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(pal.dim)
                        Slider(value: settings.binding(\.audioVolume), in: 0...1)
                            .controlSize(.small)
                            .tint(pal.action)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(pal.dim)
                    }

                    Text("Audio only — no video. Works with playlists & live streams.")
                        .font(HudFont.ui(HudTextSize.xs))
                        .foregroundStyle(pal.dim)
                }
                .padding(HudSpacing.lg)
            }

            group("PLAYLIST") {
                VStack(alignment: .leading, spacing: 0) {
                    if favorites.items.isEmpty {
                        HStack(spacing: HudSpacing.md) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(pal.dim)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No saved videos")
                                    .font(HudFont.ui(HudTextSize.sm, weight: .medium))
                                    .foregroundStyle(pal.ink)
                                Text("Add YouTube links here to populate the menu player.")
                                    .font(HudFont.ui(HudTextSize.xs))
                                    .foregroundStyle(pal.dim)
                            }
                            Spacer()
                        }
                        .padding(HudSpacing.lg)
                    } else {
                        ForEach(Array(favorites.items.enumerated()), id: \.element.id) { index, favorite in
                            playlistRow(favorite, index: index)
                            if index < favorites.items.count - 1 { rowDivider }
                        }
                    }

                    rowDivider

                    VStack(alignment: .leading, spacing: HudSpacing.md) {
                        BrandTextField(
                            text: $newFavoriteURL,
                            placeholder: "YouTube URL…",
                            textColor: pal.ink,
                            selectionColor: pal.action
                        )
                        .padding(.horizontal, HudSpacing.md)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .fill(pal.inset)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HudRadius.standard)
                                        .stroke(pal.border, lineWidth: 1)
                                )
                        )

                        HStack(spacing: HudSpacing.sm) {
                            BrandTextField(
                                text: $newFavoriteTitle,
                                placeholder: "Optional title…",
                                textColor: pal.ink,
                                selectionColor: pal.action
                            )
                            .padding(.horizontal, HudSpacing.md)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: HudRadius.standard)
                                    .fill(pal.inset)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HudRadius.standard)
                                            .stroke(pal.border, lineWidth: 1)
                                    )
                            )

                            button("Add", icon: "plus", kind: .primary) { addFavoriteFromFields() }
                                .disabled(newFavoriteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(newFavoriteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                        }
                    }
                    .padding(HudSpacing.lg)
                }
            }

            group("YOUTUBE ACCOUNT") {
                HStack(spacing: HudSpacing.md) {
                    accountAvatar
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(pal.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.signedIn ? (account.name ?? "Signed in") : "Not signed in")
                            .font(HudFont.ui(HudTextSize.sm, weight: .medium))
                            .foregroundStyle(pal.ink)
                        Text(account.signedIn ? "Ad-free with Premium" : "Sign in to skip ads")
                            .font(HudFont.ui(HudTextSize.xs))
                            .foregroundStyle(pal.dim)
                    }
                    Spacer()
                    if account.signedIn {
                        button("Sign out") { onSignOut() }
                    } else {
                        button("Sign in", icon: "person.crop.circle", kind: .primary) { onSignIn() }
                    }
                }
                .padding(HudSpacing.lg)

                rowDivider

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import login from browser")
                            .font(HudFont.ui(HudTextSize.sm))
                            .foregroundStyle(pal.ink)
                        Text("Reuse a YouTube session you're already signed into.")
                            .font(HudFont.ui(HudTextSize.xs))
                            .foregroundStyle(pal.dim)
                    }
                    Spacer()
                    button("Import…") { onImportLogin() }
                }
                .padding(HudSpacing.lg)
            }
        }
    }

    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            group("SUMMON HUD") {
                row("Shortcut", subtitle: "Press a combination including ⌘, ⌥, or ⌃.") {
                    HotkeyRecorder(display: settings.hotkeyDisplay) { keyCode, modifiers, label in
                        settings.setHotkey(keyCode: keyCode, modifiers: modifiers, display: label)
                    }
                }
            }

            Text("The HUD floats above your work; summon and dismiss it with \(settings.hotkeyDisplay).")
                .font(HudFont.ui(HudTextSize.xs))
                .foregroundStyle(pal.dim)
                .padding(.horizontal, HudSpacing.xs)
        }
    }

    // MARK: - Playlist

    private func playlistRow(_ favorite: Favorite, index: Int) -> some View {
        HStack(spacing: HudSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.title)
                    .font(HudFont.ui(HudTextSize.sm, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(favorite.url)
                    .font(HudFont.ui(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: HudSpacing.md)
            settingsIconButton("play.fill", help: "Play") {
                settings.audioURL = favorite.url
                settings.saveNow()
                onAudioPlay(favorite.url)
            }
            settingsIconButton("chevron.up", help: "Move up", enabled: index > 0) {
                favorites.move(from: index + 1, to: index)
            }
            settingsIconButton("chevron.down", help: "Move down", enabled: index < favorites.items.count - 1) {
                favorites.move(from: index + 1, to: index + 2)
            }
            settingsIconButton("trash", help: "Remove") {
                favorites.remove(at: index + 1)
            }
        }
        .padding(.horizontal, HudSpacing.lg)
        .padding(.vertical, HudSpacing.md)
    }

    private func addFavoriteFromFields() {
        let url = newFavoriteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = newFavoriteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard favorites.add(url: url, title: title.isEmpty ? nil : title) else { return }
        if settings.audioURL.isEmpty {
            settings.audioURL = url
            settings.saveNow()
        }
        newFavoriteURL = ""
        newFavoriteTitle = ""
    }

    // MARK: - Account avatar

    @ViewBuilder private var accountAvatar: some View {
        if let img = account.avatar {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: account.signedIn ? "person.crop.circle.fill" : "person.crop.circle")
                .resizable().aspectRatio(contentMode: .fit)
                .foregroundStyle(account.signedIn ? pal.action : pal.dim)
        }
    }

    // MARK: - Building blocks

    /// A titled group: a dim mono eyebrow over a bordered card.
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            Text(title)
                .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(pal.dim)
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.card).fill(pal.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.card).stroke(pal.border, lineWidth: 1)
                )
        }
    }

    /// A label (+ optional subtitle) on the left, a control on the right.
    private func row<Trailing: View>(
        _ label: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: HudSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(HudFont.ui(HudTextSize.sm))
                    .foregroundStyle(pal.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(HudFont.ui(HudTextSize.xs))
                        .foregroundStyle(pal.dim)
                }
            }
            Spacer(minLength: HudSpacing.lg)
            trailing()
        }
        .padding(.horizontal, HudSpacing.lg)
        .padding(.vertical, HudSpacing.md)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(pal.hairline)
            .frame(height: 1)
            .padding(.leading, HudSpacing.lg)
    }

    private func stepperControl(_ value: Binding<Int>, suffix: String, range: ClosedRange<Int> = 1...99) -> some View {
        HStack(spacing: HudSpacing.sm) {
            Text("\(value.wrappedValue) \(suffix)")
                .font(HudFont.mono(HudTextSize.sm, weight: .medium))
                .foregroundStyle(pal.muted)
                .frame(minWidth: 86, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    private func toggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(pal.action)
    }

    private func sliderControl(_ value: Binding<Double>, range: ClosedRange<Double> = 0.0...1.0) -> some View {
        HStack(spacing: HudSpacing.md) {
            Slider(value: value, in: range)
                .frame(width: 170)
                .controlSize(.small)
                .tint(pal.action)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(HudFont.mono(HudTextSize.xs, weight: .medium))
                .foregroundStyle(pal.muted)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private enum ButtonKind { case primary, secondary }

    private func button(_ title: String, icon: String? = nil, kind: ButtonKind = .secondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: HudSpacing.xs) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                }
                Text(title).font(HudFont.mono(HudTextSize.xs, weight: .semibold))
            }
            .foregroundStyle(kind == .primary ? Color.black.opacity(0.82) : pal.ink)
            .padding(.horizontal, HudSpacing.md)
            .padding(.vertical, HudSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.standard)
                    .fill(kind == .primary ? pal.action : pal.inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: HudRadius.standard)
                            .stroke(kind == .primary ? Color.clear : pal.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func settingsIconButton(
        _ symbol: String,
        help: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(enabled ? pal.muted : pal.dim)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(pal.inset)
                        .overlay(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .stroke(pal.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .help(help)
    }

    private static let appVersion: String? =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
}

/// Settings navigation sections.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, audio, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .audio:      return "Audio"
        case .shortcuts:  return "Shortcuts"
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gauge.with.dots.needle.50percent"
        case .appearance: return "paintbrush"
        case .audio:      return "music.note"
        case .shortcuts:  return "command"
        }
    }

    var subtitle: String {
        switch self {
        case .general:    return "Session lengths, auto-start, and the completion chime."
        case .appearance: return "Watchface and HUD panel treatment."
        case .audio:      return "Background audio and your YouTube account."
        case .shortcuts:  return "The global hotkey that summons the HUD."
        }
    }
}
