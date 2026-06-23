import AppKit
import SwiftUI
import HudsonUI
import HudsonShell

/// The SwiftUI content hosted inside the floating panel: a frosted, rounded HUD
/// card rendering whichever watchface is selected. Reads `settings` so cycling
/// the face or changing opacity updates live.
struct HUDRootView: View {
    let model: TimerModel
    let settings: PomoSettings
    let audio: AudioController
    let favorites: FavoritesStore
    let size: CGSize
    /// Dismiss the HUD (right-click → Hide). Wired by HUDController.
    var onHide: (() -> Void)? = nil

    /// The two on-face audio buttons show once a station is configured or
    /// something is playing. Reading `audio`/`settings` here keeps them live.
    private var audioFaceControls: AudioFaceControls {
        AudioFaceControls(
            enabled: !settings.audioURL.isEmpty || audio.isPlaying || !audio.currentURL.isEmpty,
            isPlaying: audio.isPlaying,
            drawerOpen: audio.videoOpen,
            togglePlay: {
                if audio.isPlaying { audio.pause() }
                else { audio.resume(stored: settings.audioURL) }
            },
            toggleDrawer: {
                // Opening with nothing loaded yet? Kick off the saved station so
                // the drawer has something to show.
                if !audio.videoOpen, !audio.isPlaying, audio.currentURL.isEmpty,
                   !settings.audioURL.isEmpty {
                    audio.play(urlString: settings.audioURL)
                }
                audio.toggleVideo()
            }
        )
    }

    // The Blueprint face reads as a drafting sheet, so it wants hard, near-square
    // corners; every other face keeps the soft frosted-HUD radius.
    private var baseRadius: CGFloat {
        settings.watchface == .blueprint ? 0 : 12
    }

    // When the video drawer is docked, square the two corners on its side so the
    // HUD and drawer read as one continuous block rather than two cards kissing.
    private var cornerRadii: RectangleCornerRadii {
        let r = baseRadius
        guard audio.videoOpen, settings.watchface != .blueprint else {
            return RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r)
        }
        switch audio.videoEdge {
        case .right: return RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: 0, topTrailing: 0)
        case .left:  return RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: r, topTrailing: r)
        case .below: return RectangleCornerRadii(topLeading: r, bottomLeading: 0, bottomTrailing: 0, topTrailing: r)
        case .above: return RectangleCornerRadii(topLeading: 0, bottomLeading: r, bottomTrailing: r, topTrailing: 0)
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
    }

    var body: some View {
        ZStack {
            // Tunable backdrop blur of the desktop behind the panel — true
            // CSS-`backdrop-filter` semantics: it softens the layer *behind*,
            // hiding detail, with no light tint. Strength is user-controllable
            // (Settings → Background blur).
            BackdropBlurView(radius: settings.backgroundBlur * 32)

            // Dark scrim over the blur so text contrast stays constant no matter
            // what (light or dark) sits behind the panel. Keeps the frosted depth
            // at the edges while guaranteeing legibility for the watchfaces.
            LinearGradient(
                colors: [Color.black.opacity(0.46), Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )

            WatchfaceView(face: settings.watchface, model: model)

            // Quick-entry fields (press `i` for intent, `v` to paste a link).
            // Dims the watchface behind a single focused input; shared across
            // every face so it's one implementation and looks identical.
            QuickEntryOverlay(model: model, settings: settings, audio: audio, favorites: favorites)

            // Music + video drawer buttons, parked in the bottom-right corner so
            // they're out of the way of the centered transport. Only while a
            // station is configured/playing and not mid-edit.
            if audioFaceControls.enabled, model.quickField == .none {
                audioCornerControls
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(panelShape)
        .overlay(
            panelShape
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .overlay(
            panelShape
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .blendMode(.plusDarker)
                .padding(0.5)
        )
        // Panel-level opacity is applied to the window's alphaValue by
        // HUDController (so it composes with the summon/dismiss fade).
        .environment(\.hudTheme, .default)
        .environment(\.audioControls, audioFaceControls)
        // Right-click anywhere on the HUD for the quick-entry actions.
        .contextMenu { hudContextMenu }
    }

    /// Music + video buttons docked to the panel's bottom-right corner, neutral
    /// (face-agnostic) so they read the same on every watchface.
    private var audioCornerControls: some View {
        let a = audioFaceControls
        return VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: HudSpacing.sm) {
                    cornerButton(
                        systemName: a.isPlaying ? "pause.fill" : "music.note",
                        help: a.isPlaying ? "Pause music" : "Play music",
                        action: a.togglePlay
                    )
                    cornerButton(
                        systemName: a.drawerOpen ? "rectangle.fill" : "play.rectangle",
                        help: a.drawerOpen ? "Hide video" : "Show video",
                        action: a.toggleDrawer
                    )
                }
            }
        }
        .padding(HudSpacing.sm)
    }

    private func cornerButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .frame(width: 28, height: 28)   // matches the transport's secondary buttons
                .background(Circle().fill(Color.white.opacity(0.06)))
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// Context menu shown on a right-click / control-click of the HUD. Mirrors
    /// the menu-bar Intent submenu, kept close to where you're already looking.
    @ViewBuilder
    private var hudContextMenu: some View {
        let hasIntent = !model.intent.isEmpty
        Button(hasIntent ? "Change Intent…" : "Set Intent…") {
            model.beginEditing(.intent)
        }
        if hasIntent {
            Button("Clear Intent") { model.setIntent("") }
        }

        let recents = settings.recentIntents
            .filter { $0.caseInsensitiveCompare(model.intent) != .orderedSame }
        if !recents.isEmpty {
            Menu("Recent Intents") {
                ForEach(recents, id: \.self) { intent in
                    Button(intent) { model.setIntent(intent) }
                }
            }
        }

        Divider()

        Button("Paste Audio / Video Link…") { model.beginEditing(.video) }

        Divider()

        Button("Hide HUD") { onHide?() }
        // You can't right-click a hidden HUD, so remind them how to bring it back.
        Button("Reopen with \(settings.hotkeyDisplay)") {}
            .disabled(true)
    }
}

/// A single, mode-switched quick field that floats over any watchface. Entry is
/// hotkey-first — `i` names the session, `v` pastes a YouTube/audio link — but
/// the field is also opened from the menu. It dims the HUD, focuses immediately,
/// commits on Return, and cancels on Escape or a tap outside.
private struct QuickEntryOverlay: View {
    let model: TimerModel
    let settings: PomoSettings
    let audio: AudioController
    let favorites: FavoritesStore

    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    private var field: TimerModel.QuickField { model.quickField }
    private var accent: Color { model.sessionType.tint.color }

    var body: some View {
        ZStack {
            if field != .none {
                // Scrim — tap anywhere outside the card to cancel.
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .contentShape(Rectangle())
                    .onTapGesture { model.cancelEditing() }

                card.padding(.horizontal, HudSpacing.xxl)
            }
        }
        .animation(.easeOut(duration: 0.15), value: field)
        .onChange(of: field) { _, newField in
            switch newField {
            case .none:
                fieldFocused = false
            case .intent:
                // Start empty (the current intent is shown on the HUD) so the
                // pre-filled text isn't select-all'd into a harsh highlight.
                draft = ""
                fieldFocused = true
            case .video:
                // Pre-fill from the clipboard when it holds a link, so a copied
                // YouTube URL is one Return away; otherwise show the current one.
                draft = clipboardURL() ?? settings.audioURL
                fieldFocused = true
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            Text(title)
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(HudPalette.dim)

            TextField(placeholder, text: $draft)
                .textFieldStyle(.plain)
                .font(HudFont.mono(15, weight: .medium))
                .foregroundStyle(HudPalette.ink)
                .tint(accent)
                .lineLimit(1)
                .focused($fieldFocused)
                .onSubmit(commit)
                .onExitCommand { model.cancelEditing() }

            Rectangle().fill(HudPalette.border).frame(height: 1)

            // Cancel on the left, the commit action on the right. Return also
            // commits (the field is focused) and Escape cancels.
            HStack(spacing: HudSpacing.sm) {
                pillButton("Cancel", fill: HudSurface.inset, stroke: HudPalette.border, text: HudPalette.muted) {
                    model.cancelEditing()
                }
                Spacer(minLength: 0)
                pillButton(primaryLabel, fill: accent, stroke: .clear, text: .black.opacity(0.85), action: commit)
            }
        }
        .padding(HudSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                .fill(HudSurface.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                .stroke(HudPalette.border, lineWidth: 1)
        )
    }

    // MARK: - Per-mode copy + behaviour

    private var title: String {
        switch field {
        case .video:           return "PASTE A YOUTUBE OR AUDIO LINK"
        case .intent, .none:   return "WHAT ARE YOU WORKING ON?"
        }
    }

    private var placeholder: String {
        switch field {
        case .video:           return "https://youtube.com/watch?v=…"
        case .intent, .none:   return "e.g. Writing the launch post"
        }
    }

    private var primaryLabel: String {
        switch field {
        case .video:         return "Play"
        case .intent, .none: return "Set"
        }
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .intent:
            // Empty submit keeps the current intent (clear it from the menu).
            if !text.isEmpty { model.setIntent(text) }
        case .video:
            if text.isEmpty { break }
            settings.audioURL = text
            settings.saveNow()
            favorites.add(url: text, title: nil)   // remember it (deduped, auto-titled)
            audio.play(urlString: text)
            audio.setVideoVisible(true)   // reveal the video for a link you set
        case .none:
            break
        }
        model.cancelEditing()
    }

    private func pillButton(_ title: String, fill: Color, stroke: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .foregroundStyle(text)
                .padding(.horizontal, HudSpacing.md)
                .padding(.vertical, HudSpacing.xs)
                .background(RoundedRectangle(cornerRadius: HudRadius.tight, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: HudRadius.tight, style: .continuous).stroke(stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func clipboardURL() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (text.hasPrefix("http://") || text.hasPrefix("https://")) ? text : nil
    }
}
