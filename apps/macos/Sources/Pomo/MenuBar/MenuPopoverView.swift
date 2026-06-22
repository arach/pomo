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

    private var session: SessionType { model.sessionType }
    private var tint: HudTint { session.tint }

    // MARK: - Adaptive theme

    /// Hudson's static `HudPalette` / `HudSurface` colours are fixed-dark and do
    /// not follow `\.hudTheme`, so we read the theme palette directly and pick
    /// light vs dark off the system appearance. (`lightDraft` is Hudson's light
    /// palette; `default` is the dark HUD palette.)
    private var theme: HudTheme { scheme == .light ? .lightDraft : .default }
    private var pal: HudThemePalette { scheme == .light ? .lightDraft : .default }

    /// Scheme-aware inset / tinted surfaces for the chips + icon buttons, since
    /// `HudSurface` is dark-only. In light mode we derive subtle on-light fills.
    private var insetFill: Color { scheme == .light ? Color.black.opacity(0.05) : HudSurface.inset }
    private func tintFill(_ c: Color) -> Color { scheme == .light ? c.opacity(0.16) : HudSurface.tintFill(c) }
    private func tintBorder(_ c: Color) -> Color { scheme == .light ? c.opacity(0.55) : HudSurface.tintBorder(c) }

    var body: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            header
            timer
            section("INTENT") { intentField }
            transport
            section("SESSION") { sessionPills }
            section("WATCHFACE") { watchfaceChips }
            section("AUDIO") { audioControls }
            footer
        }
        .padding(HudSpacing.xxl)
        .frame(width: 288)
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
                    ? [Color.white.opacity(0.45), Color.white.opacity(0.24)]
                    : [Color.black.opacity(0.46), Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("POMO")
                .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                .tracking(2)
                .foregroundStyle(pal.dim)
            Spacer()
            HudBadge(session.label, tint: tint.color, dot: true)
        }
    }

    // MARK: - Countdown + progress

    private var timer: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            Text(model.clock)
                .font(HudFont.mono(HudTextSize.hero, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(pal.ink)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.ink.opacity(0.10))
                    Capsule()
                        .fill(tint.color)
                        .frame(width: max(0, geo.size.width * model.progress))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Intent

    /// Free-text "what am I focusing on" field. Writes straight to the model
    /// (which persists it + shows it on the HUD). Editable in any phase.
    private var intentField: some View {
        TextField(
            "What are you focusing on?",
            text: Binding(get: { model.intent }, set: { model.setIntent($0) })
        )
        .textFieldStyle(.plain)
        .font(HudFont.mono(HudTextSize.sm))
        .foregroundStyle(pal.ink)
        .padding(.horizontal, HudSpacing.lg)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard)
                .fill(pal.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(pal.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: HudSpacing.md) {
            HudButton(
                primaryTitle,
                icon: model.isRunning ? "pause.fill" : "play.fill",
                style: .primary(tint)
            ) { model.toggle() }
                .frame(maxWidth: .infinity)

            iconButton("arrow.counterclockwise", help: "Reset") { model.reset() }
            iconButton("forward.end.fill", help: "Skip to next") { model.skip() }
        }
    }

    private var primaryTitle: String {
        if model.isRunning { return "Pause" }
        return model.isPaused ? "Resume" : "Start"
    }

    // MARK: - Session pills

    private var sessionPills: some View {
        HStack(spacing: HudSpacing.sm) {
            ForEach(SessionType.allCases) { type in
                chip(
                    label: pillLabel(type),
                    selected: type == session,
                    tint: type.tint.color,
                    enabled: model.isIdle
                ) { model.setSessionType(type) }
            }
        }
    }

    private func pillLabel(_ type: SessionType) -> String {
        switch type {
        case .focus:      return "Focus"
        case .shortBreak: return "Break"
        case .longBreak:  return "Long"
        }
    }

    // MARK: - Watchface chips

    private var watchfaceChips: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: HudSpacing.sm),
            count: 3
        )
        return LazyVGrid(columns: columns, spacing: HudSpacing.sm) {
            ForEach(Watchface.allCases) { face in
                chip(
                    label: face.displayName,
                    selected: face == settings.watchface,
                    tint: pal.accent,
                    enabled: true
                ) {
                    settings.watchface = face
                    settings.saveNow()
                }
            }
        }
    }

    // MARK: - Audio

    private var audioControls: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            HStack(spacing: HudSpacing.md) {
                iconButton(
                    audio.isPlaying ? "pause.fill" : "play.fill",
                    help: audio.isPlaying ? "Pause" : "Play",
                    active: audio.isPlaying || !audio.currentURL.isEmpty
                ) { onToggleAudio() }
                iconButton("stop.fill", help: "Stop") { onStopAudio() }

                VStack(alignment: .leading, spacing: 1) {
                    Text(nowPlayingTitle)
                        .font(HudFont.mono(HudTextSize.xs, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(audio.currentURL.isEmpty ? pal.dim : pal.ink)
                    Text(nowPlayingSubtitle)
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(audio.isPlaying ? tint.color : pal.dim)
                }
                Spacer(minLength: 0)
            }

            if !favorites.items.isEmpty {
                let columns = Array(repeating: GridItem(.flexible(), spacing: HudSpacing.sm), count: 2)
                LazyVGrid(columns: columns, spacing: HudSpacing.sm) {
                    ForEach(favorites.items) { favorite in
                        chip(
                            label: favorite.title,
                            selected: favorite.url == audio.currentURL,
                            tint: pal.accent,
                            enabled: true
                        ) { onPlayFavorite(favorite) }
                    }
                }
            }

            HStack(spacing: HudSpacing.sm) {
                Image(systemName: "speaker.fill")
                    .font(HudFont.ui(HudTextSize.micro))
                    .foregroundStyle(pal.dim)
                Slider(value: settings.binding(\.audioVolume), in: 0...1)
                    .controlSize(.mini)
                    .tint(tint.color)
                Image(systemName: "speaker.wave.3.fill")
                    .font(HudFont.ui(HudTextSize.micro))
                    .foregroundStyle(pal.dim)
            }
        }
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
            Divider().overlay(pal.border)
            HStack(spacing: HudSpacing.md) {
                HudButton("Show HUD", icon: "macwindow", style: .secondary, action: onShowHUD)
                Text(settings.hotkeyDisplay)
                    .font(HudFont.mono(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
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

    // MARK: - Reusable bits

    /// Labelled section: a dim mono kicker over arbitrary content.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            Text(title)
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(pal.dim)
            content()
        }
    }

    /// A selectable, tintable chip used for both sessions and watchfaces.
    private func chip(
        label: String,
        selected: Bool,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(HudFont.mono(HudTextSize.xs, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HudSpacing.sm)
                .foregroundStyle(selected ? tint : pal.muted)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(selected ? tintFill(tint) : insetFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .stroke(selected ? tintBorder(tint) : pal.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }

    /// A square, chrome-styled icon button for secondary transport / footer actions.
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
                    RoundedRectangle(cornerRadius: HudRadius.standard).fill(insetFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.standard).stroke(pal.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
