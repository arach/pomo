import SwiftUI
import HudsonUI
import UniformTypeIdentifiers

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
    @State private var playlistSearch = ""
    @State private var draggingFavorite: Favorite?
    @State private var dropTargetIndex: Int?

    /// The appearance actually in effect: a user-forced mode if one is set,
    /// otherwise the system scheme from the environment. Drives both the palette
    /// and `.preferredColorScheme`, so the two never disagree.
    private var effectiveScheme: ColorScheme {
        settings.appearanceMode.colorScheme ?? scheme
    }
    private var pal: AppPalette { .resolve(effectiveScheme) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(pal.hairline).frame(width: 1)
            detail
        }
        .frame(minWidth: 640, idealWidth: 720, maxWidth: .infinity,
               minHeight: 480, idealHeight: 560, maxHeight: .infinity)
        .background(pal.bg)
        // Pin the whole window — native controls and the titlebar's traffic
        // lights included — to the chosen theme (nil = follow the system).
        .preferredColorScheme(settings.appearanceMode.colorScheme)
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
        // Align the pane title with the sidebar "Pomo" logo across the divider.
        .padding(.top, 34)
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
            group("THEME") {
                VStack(alignment: .leading, spacing: HudSpacing.md) {
                    appearanceSegmented(settings.binding(\.appearanceMode))
                    Text("Auto follows your macOS appearance. Light and Dark pin Pomo's windows regardless of the system setting.")
                        .font(HudFont.ui(HudTextSize.xs))
                        .foregroundStyle(pal.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(HudSpacing.lg)
            }

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
                rowDivider
                row("Tiny mode") { toggle(settings.binding(\.hudTinyMode)) }
            }
        }
    }

    private var audioTab: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            group("BACKGROUND AUDIO") {
                VStack(alignment: .leading, spacing: HudSpacing.lg) {
                    inputSurface(icon: "link") {
                        BrandTextField(
                            text: settings.binding(\.audioURL),
                            placeholder: "Paste a YouTube link…",
                            textColor: pal.ink,
                            selectionColor: pal.action
                        )
                        .frame(maxWidth: .infinity)
                    }

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

            group("VISUALIZER") {
                row("FPS profile", subtitle: settings.pomoAmpVisualizerMode.detail) {
                    Picker("", selection: settings.binding(\.pomoAmpVisualizerMode)) {
                        ForEach(PomoAmpVisualizerMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 170)
                }
            }

            group("PLAYLIST", accessory: {
                if !favorites.items.isEmpty { countBadge(favorites.items.count) }
            }) {
                if showsPlaylistSearch {
                    inputSurface(icon: "magnifyingglass", height: 30) {
                        BrandTextField(
                            text: $playlistSearch,
                            placeholder: "Filter playlist…",
                            textColor: pal.ink,
                            selectionColor: pal.action
                        )
                        .frame(maxWidth: .infinity)
                        if !playlistSearch.isEmpty {
                            Button { playlistSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(pal.dim)
                            }
                            .buttonStyle(.plain)
                            .help("Clear filter")
                        }
                    }
                    .padding(.horizontal, HudSpacing.lg)
                    .padding(.top, HudSpacing.lg)
                    .padding(.bottom, HudSpacing.md)
                    rowDivider
                }

                if favorites.items.isEmpty {
                    playlistEmptyState
                } else if filteredFavorites.isEmpty {
                    playlistNoMatches
                } else {
                    ForEach(Array(filteredFavorites.enumerated()), id: \.element.id) { index, favorite in
                        playlistRow(favorite, index: index)
                        if index < filteredFavorites.count - 1 { rowDivider }
                    }
                    // A slim "drop at end" target, shown only mid-drag so the
                    // bottom slot is reachable without cluttering the resting list.
                    if draggingFavorite != nil, !isFiltering {
                        Color.clear
                            .frame(height: 14)
                            .overlay(alignment: .top) {
                                if dropTargetIndex == favorites.items.count {
                                    insertionLine
                                }
                            }
                            .onDrop(of: [UTType.text], delegate: PlaylistReorderDelegate(
                                index: favorites.items.count,
                                isDragging: draggingFavorite != nil,
                                setTarget: { dropTargetIndex = $0 },
                                commit: { commitReorderToEnd() }
                            ))
                    }
                }

                rowDivider
                addFavoriteSection
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

    /// Favorites filtered by the search field (only once the filter is shown).
    private var filteredFavorites: [Favorite] {
        guard isFiltering else { return favorites.items }
        let q = playlistSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return favorites.items.filter {
            $0.title.lowercased().contains(q) || $0.url.lowercased().contains(q)
        }
    }

    /// The filter only earns its keep once the list is long enough to scan poorly.
    private var showsPlaylistSearch: Bool { favorites.items.count >= 6 }

    private var isFiltering: Bool {
        showsPlaylistSearch &&
        !playlistSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func playlistRow(_ favorite: Favorite, index: Int) -> some View {
        let isActive = !favorite.url.isEmpty && favorite.url == settings.audioURL
        let reorderable = !isFiltering
        let isDropTarget = reorderable && dropTargetIndex == index

        return HStack(spacing: HudSpacing.md) {
            if reorderable {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pal.dim)
                    .frame(width: 16)
                    .help("Drag to reorder")
            }
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
            settingsIconButton(
                isActive ? "speaker.wave.2.fill" : "play.fill",
                help: isActive ? "Restart" : "Play",
                tint: isActive ? pal.action : nil
            ) {
                settings.audioURL = favorite.url
                settings.saveNow()
                onAudioPlay(favorite.url)
            }
            settingsIconButton("trash", help: "Remove") {
                if let i = favorites.items.firstIndex(of: favorite) {
                    favorites.remove(at: i + 1)
                }
            }
        }
        .padding(.horizontal, HudSpacing.lg)
        .padding(.vertical, HudSpacing.md)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle().fill(pal.action).frame(width: 3)
            }
        }
        .overlay(alignment: .top) {
            if isDropTarget { insertionLine }
        }
        .onDrag {
            guard reorderable else { return NSItemProvider() }
            draggingFavorite = favorite
            return NSItemProvider(object: favorite.url as NSString)
        }
        .onDrop(of: [UTType.text], delegate: PlaylistReorderDelegate(
            index: index,
            isDragging: draggingFavorite != nil,
            setTarget: { dropTargetIndex = $0 },
            commit: { commitReorder(before: favorite) }
        ))
    }

    /// The accent bar shown where a dragged row will land.
    private var insertionLine: some View {
        Rectangle()
            .fill(pal.action)
            .frame(height: 2)
            .padding(.horizontal, HudSpacing.lg)
    }

    private var playlistEmptyState: some View {
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
    }

    private var playlistNoMatches: some View {
        HStack(spacing: HudSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.dim)
                .frame(width: 28)
            Text("No videos match “\(playlistSearch)”.")
                .font(HudFont.ui(HudTextSize.sm))
                .foregroundStyle(pal.muted)
            Spacer()
        }
        .padding(HudSpacing.lg)
    }

    private var addFavoriteSection: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            inputSurface(icon: "link", height: 30) {
                BrandTextField(
                    text: $newFavoriteURL,
                    placeholder: "Paste a YouTube link to save…",
                    textColor: pal.ink,
                    selectionColor: pal.action
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: HudSpacing.sm) {
                inputSurface(height: 30) {
                    BrandTextField(
                        text: $newFavoriteTitle,
                        placeholder: "Optional title…",
                        textColor: pal.ink,
                        selectionColor: pal.action
                    )
                    .frame(maxWidth: .infinity)
                }

                button("Add", icon: "plus", kind: .primary) { addFavoriteFromFields() }
                    .disabled(addDisabled)
                    .opacity(addDisabled ? 0.45 : 1)
            }
        }
        .padding(HudSpacing.lg)
    }

    private var addDisabled: Bool {
        newFavoriteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reorder: drop the dragged favorite immediately *before* `target`.
    private func commitReorder(before target: Favorite) {
        defer { draggingFavorite = nil; dropTargetIndex = nil }
        guard let dragging = draggingFavorite, dragging != target else { return }
        var order = favorites.items
        guard let from = order.firstIndex(of: dragging) else { return }
        order.remove(at: from)
        guard let to = order.firstIndex(of: target) else { return }
        order.insert(dragging, at: to)
        favorites.replace(with: order)
    }

    /// Reorder: drop the dragged favorite at the end of the list.
    private func commitReorderToEnd() {
        defer { draggingFavorite = nil; dropTargetIndex = nil }
        guard let dragging = draggingFavorite else { return }
        var order = favorites.items
        guard let from = order.firstIndex(of: dragging) else { return }
        order.remove(at: from)
        order.append(dragging)
        favorites.replace(with: order)
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

    /// A titled group: a dim mono eyebrow (with an optional trailing accessory,
    /// e.g. a count) over a bordered card.
    private func group<Accessory: View, Content: View>(
        _ title: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            HStack(spacing: HudSpacing.sm) {
                Text(title)
                    .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(pal.dim)
                Spacer(minLength: 0)
                accessory()
            }
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.card).fill(pal.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.card).stroke(pal.border, lineWidth: 1)
                )
        }
    }

    /// A small count pill for a group eyebrow.
    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(HudFont.mono(HudTextSize.micro, weight: .bold))
            .foregroundStyle(pal.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(pal.inset)
                    .overlay(Capsule().stroke(pal.border, lineWidth: 1))
            )
    }

    /// A recessed input capsule with an optional leading glyph — the shared
    /// shell for URL / title / filter fields so they read consistently.
    private func inputSurface<Content: View>(
        icon: String? = nil,
        height: CGFloat = 32,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: HudSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(pal.dim)
            }
            content()
        }
        .padding(.horizontal, HudSpacing.md)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard)
                .fill(pal.inset)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(pal.border, lineWidth: 1)
                )
        )
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

    /// A bespoke segmented control — an inset track with a raised selected pill —
    /// matching the settings token language (native `.segmented` can't be tinted
    /// to the palette). Equal-width segments span the card. Drives the theme.
    private func appearanceSegmented(_ selection: Binding<AppearanceMode>) -> some View {
        HStack(spacing: 3) {
            ForEach(AppearanceMode.allCases) { mode in
                let on = selection.wrappedValue == mode
                Button { selection.wrappedValue = mode } label: {
                    HStack(spacing: HudSpacing.xs) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(mode.displayName)
                            .font(HudFont.ui(HudTextSize.sm, weight: on ? .semibold : .medium))
                    }
                    .foregroundStyle(on ? pal.ink : pal.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HudSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HudRadius.standard - 2)
                            .fill(on ? pal.surface : .clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: HudRadius.standard - 2)
                                    .stroke(on ? pal.border : .clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard)
                .fill(pal.inset)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(pal.border, lineWidth: 1)
                )
        )
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
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint ?? (enabled ? pal.muted : pal.dim))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(tint.map { $0.opacity(0.14) } ?? pal.inset)
                        .overlay(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .stroke(tint.map { $0.opacity(0.30) } ?? pal.border, lineWidth: 1)
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
        case .appearance: return "Theme, watchface, and HUD panel treatment."
        case .audio:      return "Background audio and your YouTube account."
        case .shortcuts:  return "The global hotkey that summons the HUD."
        }
    }
}

/// Drag-to-reorder for a single playlist row. Tracks which row the drag is over
/// (for the insertion indicator) and commits the move once, on drop — so the
/// favorites store is written to disk a single time per reorder.
private struct PlaylistReorderDelegate: DropDelegate {
    let index: Int
    let isDragging: Bool
    let setTarget: (Int?) -> Void
    let commit: () -> Void

    func validateDrop(info: DropInfo) -> Bool { isDragging }
    func dropEntered(info: DropInfo) { setTarget(index) }
    func dropExited(info: DropInfo) { setTarget(nil) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        commit()
        return true
    }
}
