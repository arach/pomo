import SwiftUI
import HudsonUI
import HudsonShell

/// The frosted control surface shown when the menu-bar item is **left-clicked**.
/// A compact, HUD-flavoured panel: live countdown + progress, transport
/// controls, session and watchface pickers, and a "Show HUD" affordance.
///
/// Unlike the HUD (which is always a dark frosted panel), the menu-bar popover
/// **follows the system appearance** — it sits against the user's desktop, so a
/// forced-dark panel reads as out of place on a light Mac. We drive Hudson's
/// theme + a scheme-aware palette off `colorScheme` so the popover is a clean
/// light panel in light mode and the familiar dark HUD surface in dark mode.
///
/// Right-clicking the menu-bar item opens a small native menu instead
/// (Settings / Quit) — see `MenuBarController`. The HUD itself stays
/// hotkey-driven.
struct MenuPopoverView: View {
    let model: TimerModel
    let settings: PomoSettings
    let audio: AudioController
    let favorites: FavoritesStore
    var onShowHUD: () -> Void
    var onOpenSettings: () -> Void
    var onOpenStats: () -> Void
    var onToggleAudio: () -> Void
    var onStopAudio: () -> Void
    var onPlayFavorite: (Favorite) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var editingIntent = false
    @State private var hoveringIntent = false
    @State private var hoveredCarouselCaret: String?
    @State private var playlistScrollOffset: CGFloat = 0
    @State private var playlistContentHeight: CGFloat = 0
    @State private var audioPlayerHeight: CGFloat = 0

    private var session: SessionType { model.sessionType }
    private var accent: Color { session.accentColor }

    // MARK: - Adaptive theme

    /// Hudson controls still need a theme, while the popover shell uses Pomo's
    /// app palette so light mode feels native instead of like a tinted HUD copy.
    private var theme: HudTheme { scheme == .light ? .lightDraft : .default }
    private var pal: AppPalette { .resolve(scheme) }

    private var insetFill: Color {
        scheme == .light ? Color(hex: 0xECEEF1).opacity(0.82) : Color.white.opacity(0.07)
    }

    private var controlFill: Color {
        scheme == .light ? Color.white.opacity(0.70) : Color.white.opacity(0.08)
    }

    private var fieldFill: Color {
        scheme == .light ? Color.white.opacity(0.86) : Color.white.opacity(0.06)
    }

    private var dividerColor: Color {
        scheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }

    private func tintFill(_ c: Color) -> Color { c.opacity(scheme == .light ? 0.20 : 0.15) }
    private func tintBorder(_ c: Color) -> Color { c.opacity(scheme == .light ? 0.34 : 0.28) }

    private func accentText(for type: SessionType) -> Color {
        if scheme == .light, type == .focus { return Color(hex: 0x686313) }
        return type.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            timer
            section("SESSION") { sessionStrip }
            section("WATCHFACE") { watchfacePicker }
            section("AUDIO") { audioControls }
            footer
        }
        .padding(HudSpacing.xxl)
        .frame(width: 320)
        .background(frostedBackground)
        .environment(\.hudTheme, theme)
    }

    // MARK: - Background (frosted card that follows the system appearance)

    private var frostedBackground: some View {
        ZStack {
            HudVisualEffectView(
                material: scheme == .light ? .popover : .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            LinearGradient(
                colors: scheme == .light
                    ? [pal.surface.opacity(0.92), Color(hex: 0xF2F3F5).opacity(0.82)]
                    : [Color(hex: 0x19191D).opacity(0.84), Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(scheme == .light ? 0.34 : 0.05))
                    .frame(height: 1)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("POMO")
                .font(HudFont.ui(HudTextSize.xxs, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(pal.dim)
            Spacer()
            Text(settings.hotkeyDisplay)
                .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                .foregroundStyle(pal.dim)
                .padding(.horizontal, HudSpacing.sm)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(controlFill)
                        .overlay(Capsule().stroke(dividerColor, lineWidth: 1))
                )
        }
    }

    // MARK: - Countdown

    private var timer: some View {
        VStack(spacing: 6) {
            intentEyebrow

            Text(model.clock)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pal.ink)
                .frame(maxWidth: .infinity)

            transport
        }
    }

    private var timerEyebrow: String {
        let intent = model.intent.trimmingCharacters(in: .whitespacesAndNewlines)
        return intent.isEmpty ? session.shortLabel.uppercased() : intent
    }

    // MARK: - Intent

    private var intentEyebrow: some View {
        Group {
            if editingIntent {
                HStack(spacing: 6) {
                    TextField(
                        "What are you focusing on?",
                        text: Binding(get: { model.intent }, set: { model.setIntent($0) })
                    )
                    .textFieldStyle(.plain)
                    .font(HudFont.ui(HudTextSize.xs, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .onSubmit { editingIntent = false }

                    Button { editingIntent = false } label: {
                        Image(systemName: "checkmark")
                            .font(HudFont.ui(HudTextSize.xs, weight: .semibold))
                            .foregroundStyle(pal.muted)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Done editing intent")
                }
                .padding(.leading, 10)
                .padding(.trailing, 3)
                .frame(width: 168, height: 24)
                .background(
                    Capsule()
                        .fill(fieldFill)
                        .overlay(
                            Capsule()
                                .stroke(dividerColor, lineWidth: 1)
                        )
                )
            } else {
                Button { editingIntent = true } label: {
                    HStack(spacing: 4) {
                        Text(timerEyebrow)
                            .font(HudFont.ui(HudTextSize.micro, weight: .bold))
                            .tracking(model.intent.isEmpty ? 1.1 : 0.2)
                            .foregroundStyle(accentText(for: session))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if hoveringIntent {
                            Image(systemName: "pencil")
                                .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
                                .foregroundStyle(pal.dim)
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveringIntent = $0 }
                .help("Edit intent")
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: HudSpacing.sm) {
            Spacer(minLength: 0)
            iconButton("arrow.counterclockwise", help: "Reset") { model.reset() }
            Button { model.toggle() } label: {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                    .font(HudFont.ui(HudTextSize.sm, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(width: 40, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: HudRadius.standard)
                            .fill(accent)
                    )
            }
            .buttonStyle(.plain)
            .help(primaryTitle)
            iconButton("forward.end.fill", help: "Skip to next") { model.skip() }
            Spacer(minLength: 0)
        }
    }

    private var primaryTitle: String {
        if model.isRunning { return "Pause" }
        return model.isPaused ? "Resume" : "Start"
    }

    // MARK: - Session

    private var sessionStrip: some View {
        HStack(spacing: HudSpacing.sm) {
            ForEach(SessionType.allCases) { type in
                segment(
                    label: pillLabel(type),
                    detail: "\(settings.minutes(for: type))m",
                    selected: type == session,
                    tint: type.accentColor,
                    selectedText: accentText(for: type),
                    enabled: model.isIdle,
                    symbol: type.symbolName
                ) { model.setSessionType(type) }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard)
                .fill(insetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(dividerColor, lineWidth: 1)
                )
        )
    }

    private func pillLabel(_ type: SessionType) -> String {
        switch type {
        case .focus:      return "Focus"
        case .shortBreak: return "Break"
        case .longBreak:  return "Long"
        }
    }

    // MARK: - Watchface

    /// Visual carousel: enough face preview to recognize the style, with arrows
    /// for quick cycling and horizontal scroll when the list grows.
    private var watchfacePicker: some View {
        HStack(spacing: 4) {
            carouselCaret("chevron.left", help: "Previous watchface") { cycleWatchface(-1) }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Watchface.allCases) { face in
                            watchfaceTile(face)
                                .id(face.id)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(height: 70)
                .onAppear {
                    proxy.scrollTo(settings.watchface.id, anchor: .center)
                }
                .onChange(of: settings.watchface) { _, face in
                    withAnimation(.snappy(duration: 0.22, extraBounce: 0.0)) {
                        proxy.scrollTo(face.id, anchor: .center)
                    }
                }
            }

            carouselCaret("chevron.right", help: "Next watchface") { cycleWatchface(1) }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard)
                .fill(insetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(dividerColor, lineWidth: 1)
                )
        )
    }

    private func cycleWatchface(_ delta: Int) {
        let all = Watchface.allCases
        guard let i = all.firstIndex(of: settings.watchface) else { return }
        setWatchface(all[(i + delta + all.count) % all.count])
    }

    private func setWatchface(_ face: Watchface) {
        settings.watchface = face
        settings.saveNow()
    }

    private func watchfaceTile(_ face: Watchface) -> some View {
        let selected = face == settings.watchface
        let faceAccent = selected ? accent : previewAccent(for: face)
        return Button { setWatchface(face) } label: {
            VStack(spacing: 5) {
                watchfaceMiniature(face, accent: faceAccent)
                    .frame(width: 62, height: 39)
                    .clipShape(RoundedRectangle(cornerRadius: HudRadius.standard - 2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: HudRadius.standard - 2, style: .continuous)
                            .stroke(Color.white.opacity(scheme == .light ? 0.55 : 0.12), lineWidth: 1)
                    )
                Text(face.displayName)
                    .font(HudFont.ui(HudTextSize.micro, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? pal.ink : pal.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(5)
            .frame(width: 72, height: 68)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                    .fill(selected ? tintFill(faceAccent) : controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                    .stroke(selected ? tintBorder(faceAccent) : dividerColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(face.displayName)
    }

    @ViewBuilder
    private func watchfaceMiniature(_ face: Watchface, accent: Color) -> some View {
        switch face {
        case .minimal:
            VStack(alignment: .leading, spacing: 5) {
                miniLine(width: 22, color: Color.white.opacity(0.38))
                Text("25:00")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.90))
                miniProgress(accent)
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: 0x25262B), Color(hex: 0x111115)], startPoint: .top, endPoint: .bottom))

        case .terminal:
            VStack(alignment: .leading, spacing: 4) {
                Text("> focus")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: 0x80F28E))
                miniLine(width: 44, color: Color(hex: 0x80F28E).opacity(0.72))
                miniLine(width: 30, color: Color(hex: 0x80F28E).opacity(0.42))
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(hex: 0x07120A))

        case .neon:
            ZStack {
                Color(hex: 0x070712)
                Circle().stroke(Color(hex: 0x29F4FF).opacity(0.75), lineWidth: 2).frame(width: 28, height: 28)
                Circle().stroke(Color(hex: 0xFF45D6).opacity(0.55), lineWidth: 1).frame(width: 42, height: 42)
                Text("25")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

        case .retroDigital:
            HStack(spacing: 2) {
                ForEach(Array([2, 5, 0, 0].enumerated()), id: \.offset) { _, n in
                    Text("\(n)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: 0xFFB14A))
                        .frame(width: 10, height: 18)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.72)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [Color(hex: 0x3B2417), Color(hex: 0x160D09)], startPoint: .top, endPoint: .bottom))

        case .rolodex:
            HStack(spacing: 2) {
                ForEach(Array([2, 5, 0, 0].enumerated()), id: \.offset) { _, n in
                    Text("\(n)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 12, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(Rectangle().fill(Color.black.opacity(0.42)).frame(height: 1))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [Color(hex: 0x202027), Color(hex: 0x0D0D10)], startPoint: .top, endPoint: .bottom))

        case .chronograph:
            ZStack {
                Color(hex: 0x15161B)
                Circle().stroke(accent.opacity(0.72), lineWidth: 2).frame(width: 33, height: 33)
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1).frame(width: 21, height: 21)
                Rectangle().fill(accent).frame(width: 1, height: 14).offset(y: -5)
            }

        case .blueprint:
            ZStack {
                Color(hex: 0x17304D)
                BlueprintGrid(accent: Color(hex: 0x9ED8FF).opacity(0.34))
                RoundedRectangle(cornerRadius: 2).stroke(Color(hex: 0x9ED8FF).opacity(0.88), lineWidth: 1).padding(8)
                miniLine(width: 28, color: Color(hex: 0x9ED8FF).opacity(0.92))
            }
        }
    }

    private func miniProgress(_ color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.14))
            Capsule().fill(color).frame(width: 35)
        }
        .frame(height: 3)
    }

    private func miniLine(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: 3)
    }

    private func previewAccent(for face: Watchface) -> Color {
        switch face {
        case .minimal, .rolodex, .chronograph: return PomoBrand.accent
        case .terminal: return Color(hex: 0x80F28E)
        case .neon: return Color(hex: 0x29F4FF)
        case .retroDigital: return Color(hex: 0xFFB14A)
        case .blueprint: return Color(hex: 0x9ED8FF)
        }
    }

    // MARK: - Audio

    /// Small player: current track + transport on the left, playlist rail on the
    /// right so previous/next feel local to Pomo instead of mysterious.
    private var audioControls: some View {
        HStack(alignment: .top, spacing: AudioLayout.columnSpacing) {
            VStack(spacing: AudioLayout.playerStackSpacing) {
                thumbnail(
                    for: audio.currentURL,
                    width: AudioLayout.thumbnailWidth,
                    height: AudioLayout.thumbnailHeight,
                    iconSize: AudioLayout.thumbnailIconSize
                )
                VStack(spacing: 1) {
                    Text(nowPlayingTitle)
                        .font(HudFont.ui(HudTextSize.xs, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(audio.currentURL.isEmpty ? pal.dim : pal.ink)
                    Text(nowPlayingSubtitle)
                        .font(HudFont.ui(HudTextSize.micro, weight: .medium))
                        .foregroundStyle(audio.isPlaying ? accentText(for: session) : pal.dim)
                }
                .frame(width: AudioLayout.titleWidth)
                .frame(minHeight: AudioLayout.titleBlockHeight)
                audioTransport
            }
            .frame(width: AudioLayout.playerColumnWidth, alignment: .top)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: AudioPlayerHeightKey.self, value: geo.size.height)
                }
            )

            Rectangle()
                .fill(dividerColor)
                .frame(width: 1, height: playlistViewportHeight)

            playlistColumn
                .frame(width: AudioLayout.playlistColumnWidth)
        }
        .padding(AudioLayout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                .fill(insetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                        .stroke(dividerColor, lineWidth: 1)
                )
        )
        .onPreferenceChange(AudioPlayerHeightKey.self) { height in
            guard height > 0 else { return }
            audioPlayerHeight = height
        }
    }

    private var playlistColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if playlistItems.isEmpty {
                playlistPlaceholder
            } else {
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PlaylistScrollOffsetKey.self,
                                    value: geo.frame(in: .named("playlistRail")).minY
                                )
                            }
                            .frame(height: 0)

                            ForEach(Array(playlistItems.enumerated()), id: \.element.id) { index, favorite in
                                playlistTile(favorite)
                                if index < playlistItems.count - 1 {
                                    Rectangle()
                                        .fill(dividerColor)
                                        .frame(height: 1)
                                        .padding(.leading, 30)
                                }
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: PlaylistContentHeightKey.self, value: geo.size.height)
                            }
                        )
                    }
                    .coordinateSpace(name: "playlistRail")
                    .frame(height: playlistViewportHeight)
                    .onPreferenceChange(PlaylistScrollOffsetKey.self) { playlistScrollOffset = $0 }
                    .onPreferenceChange(PlaylistContentHeightKey.self) { playlistContentHeight = $0 }

                    VStack {
                        if canScrollPlaylistUp {
                            playlistEdgeCaret("chevron.up")
                        }
                        Spacer(minLength: 0)
                        if canScrollPlaylistDown {
                            playlistEdgeCaret("chevron.down")
                        }
                    }
                }
                .frame(height: playlistViewportHeight)
            }
        }
    }

    private var playlistViewportHeight: CGFloat {
        audioPlayerHeight > 0 ? audioPlayerHeight : AudioLayout.fallbackPlayerHeight
    }

    private var canScrollPlaylistUp: Bool {
        playlistScrollOffset < -1
    }

    private var canScrollPlaylistDown: Bool {
        playlistContentHeight + playlistScrollOffset > playlistViewportHeight + 1
    }

    private var audioTransport: some View {
        HStack(spacing: AudioLayout.transportSpacing) {
            playerButton("backward.end.fill", help: "Previous track", enabled: canStepAudio) {
                playAdjacentAudio(-1)
            }
            playerButton(
                audio.isPlaying ? "pause.fill" : "play.fill",
                help: audio.isPlaying ? "Pause" : "Play",
                prominent: true,
                enabled: canToggleAudio
            ) { toggleAudioFromPopover() }
            playerButton("forward.end.fill", help: "Next track", enabled: canStepAudio) {
                playAdjacentAudio(1)
            }
        }
    }

    private var canToggleAudio: Bool {
        audio.isPlaying || !audio.currentURL.isEmpty || !settings.audioURL.isEmpty || !favorites.items.isEmpty
    }

    private var canStepAudio: Bool {
        favorites.items.count > 1 || !audio.currentURL.isEmpty
    }

    private var currentFavoriteIndex: Int? {
        favorites.items.firstIndex { $0.url == audio.currentURL }
    }

    private var playlistItems: [Favorite] {
        let others = favorites.items.filter { $0.url != audio.currentURL }
        return others.isEmpty ? favorites.items : others
    }

    private func adjacentFavorite(_ delta: Int) -> Favorite? {
        let items = favorites.items
        guard !items.isEmpty else { return nil }
        let current = currentFavoriteIndex ?? (delta < 0 ? 0 : -1)
        let next = (current + delta + items.count) % items.count
        return items[next]
    }

    private func playAdjacentAudio(_ delta: Int) {
        if let favorite = adjacentFavorite(delta) {
            onPlayFavorite(favorite)
        } else if delta > 0 {
            audio.next()
        } else {
            audio.previous()
        }
    }

    private func toggleAudioFromPopover() {
        if audio.currentURL.isEmpty, settings.audioURL.isEmpty, let favorite = favorites.items.first {
            onPlayFavorite(favorite)
        } else {
            onToggleAudio()
        }
    }

    private var playlistPlaceholder: some View {
        HStack(spacing: 6) {
            thumbnail(for: "", size: 22, iconSize: 10)
            Text("No saved videos")
                .font(HudFont.ui(HudTextSize.micro, weight: .medium))
                .foregroundStyle(pal.dim)
                .lineLimit(2)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }

    private func playlistTile(_ favorite: Favorite) -> some View {
        Button { onPlayFavorite(favorite) } label: {
            HStack(spacing: 6) {
                thumbnail(for: favorite.url, size: 22, iconSize: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(favorite.title)
                        .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
                        .foregroundStyle(pal.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(3)
            .frame(maxWidth: .infinity, minHeight: 27)
        }
        .buttonStyle(.plain)
        .help(favorite.title)
    }

    /// Thumbnail of a YouTube poster, or a compact placeholder.
    @ViewBuilder private func thumbnail(for urlString: String, size: CGFloat, iconSize: CGFloat = 15) -> some View {
        thumbnail(for: urlString, width: size, height: size, iconSize: iconSize)
    }

    /// Thumbnail of a YouTube poster, or a compact placeholder.
    @ViewBuilder private func thumbnail(
        for urlString: String,
        width: CGFloat,
        height: CGFloat,
        iconSize: CGFloat = 15
    ) -> some View {
        let id = WebAudioPlayer.youTubeID(from: urlString)
        RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
            .fill(controlFill)
            .frame(width: width, height: height)
            .overlay {
                if let id, let url = URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg") {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note").font(.system(size: iconSize)).foregroundStyle(pal.dim)
                        }
                    }
                } else {
                    Image(systemName: "music.note").font(.system(size: iconSize)).foregroundStyle(pal.dim)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous).stroke(dividerColor, lineWidth: 1))
    }

    private var nowPlayingTitle: String {
        if audio.currentURL.isEmpty { return "Nothing playing" }
        if let favorite = favorites.items.first(where: { $0.url == audio.currentURL }) {
            return favorite.title
        }
        return Self.shortURL(audio.currentURL)
    }

    private var nowPlayingSubtitle: String {
        if audio.currentURL.isEmpty { return "pick a favorite below" }
        if audio.isPlaying { return audio.engineName == "native" ? "▶ ad-free" : "▶ stream" }
        return "paused"
    }

    private static func shortURL(_ string: String) -> String {
        if let id = WebAudioPlayer.youTubeID(from: string) { return "youtube · \(id)" }
        return URLComponents(string: string)?.host ?? string
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: HudSpacing.lg) {
            Divider().overlay(dividerColor)
            HStack(spacing: HudSpacing.md) {
                iconButton("macwindow", help: "Show HUD", action: onShowHUD)
                Spacer()
                iconButton(
                    settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    help: "Toggle completion chime",
                    active: settings.soundEnabled
                ) {
                    settings.soundEnabled.toggle()
                    settings.saveNow()
                }
                iconButton("chart.bar.fill", help: "Focus stats", action: onOpenStats)
                iconButton("gearshape.fill", help: "Settings", action: onOpenSettings)
            }
        }
    }

    /// Segmented session selector. During a running timer the strip stays legible
    /// but inactive, instead of fading into a broken-looking disabled row.
    private func segment(
        label: String,
        detail: String,
        selected: Bool,
        tint: Color,
        selectedText: Color,
        enabled: Bool,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
                    Text(label)
                        .font(HudFont.ui(HudTextSize.xs, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Text(detail)
                    .font(HudFont.ui(HudTextSize.micro, weight: .medium))
                    .foregroundStyle(selected ? selectedText.opacity(0.72) : pal.dim.opacity(0.82))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .foregroundStyle(selected ? selectedText : pal.dim)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.standard - 2)
                    .fill(selected ? tintFill(tint) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(enabled ? "Set \(label) session" : "Session can change when idle")
    }

    // MARK: - Reusable bits

    /// Labelled section: a dim kicker over arbitrary content.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            Text(title)
                .font(HudFont.ui(HudTextSize.micro, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(pal.dim)
            content()
        }
    }

    /// Narrow carousel caret so watchface previews get most of the row width.
    private func carouselCaret(
        _ symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        let hovered = hoveredCarouselCaret == symbol
        return Button(action: action) {
            Image(systemName: symbol)
                .font(HudFont.ui(HudTextSize.xs, weight: .semibold))
                .foregroundStyle(pal.muted)
                .frame(width: 16, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard - 2, style: .continuous)
                        .fill(hovered ? controlFill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard - 2, style: .continuous)
                        .stroke(hovered ? dividerColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { inside in hoveredCarouselCaret = inside ? symbol : nil }
        .help(help)
    }

    private func playlistEdgeCaret(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
            .foregroundStyle(pal.dim)
            .frame(width: 14, height: 14)
            .padding(.trailing, 1)
    }

    /// A square, chrome-styled icon button for secondary transport / footer actions.
    private func playerButton(
        _ symbol: String,
        help: String,
        prominent: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(HudFont.ui(HudTextSize.sm, weight: .semibold))
                .foregroundStyle(prominent ? Color.black.opacity(0.84) : (enabled ? pal.muted : pal.dim))
                .frame(
                    width: prominent ? AudioLayout.prominentButtonWidth : AudioLayout.compactButtonWidth,
                    height: AudioLayout.transportHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(prominent ? accent : controlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(prominent ? tintBorder(accent) : dividerColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .help(help)
    }

    private func iconButton(
        _ symbol: String,
        help: String,
        active: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(HudFont.ui(HudTextSize.sm, weight: .semibold))
                .foregroundStyle(active ? pal.muted : pal.dim)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard).fill(controlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard).stroke(dividerColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private enum AudioLayout {
    static let compactButtonWidth: CGFloat = 36
    static let prominentButtonWidth: CGFloat = 42
    static let transportHeight: CGFloat = 30
    static let transportSpacing: CGFloat = 6
    static let playerStackSpacing: CGFloat = 5
    static let columnSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 7
    static let thumbnailHeight: CGFloat = 68
    static let thumbnailIconSize: CGFloat = 17
    static let titleBlockHeight: CGFloat = 18
    static let playlistColumnWidth: CGFloat = 106

    static var thumbnailWidth: CGFloat {
        compactButtonWidth + prominentButtonWidth + compactButtonWidth + transportSpacing * 2
    }

    static var titleWidth: CGFloat {
        thumbnailWidth + 8
    }

    static var playerColumnWidth: CGFloat {
        titleWidth + 16
    }

    static var fallbackPlayerHeight: CGFloat {
        thumbnailHeight + titleBlockHeight + transportHeight + playerStackSpacing * 2
    }
}

private struct BlueprintGrid: View {
    var accent: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 8
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(accent), lineWidth: 0.5)
        }
    }
}

private struct PlaylistScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PlaylistContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AudioPlayerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
