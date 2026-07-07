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
    /// Shared HUD chrome (keyboard cheat sheet), driven by HUDController's key monitor.
    let chrome: HUDChrome
    /// Dismiss the HUD (right-click → Hide). Wired by HUDController.
    var onHide: (() -> Void)? = nil
    var onSetTinyMode: ((Bool) -> Void)? = nil
    var onToggleVideoDrawer: (() -> Void)? = nil
    /// Editing a quick field → make the panel fully opaque so the card is crisp
    /// rather than bleeding the face + desktop through the panel's translucency.
    var onEditingChange: ((Bool) -> Void)? = nil

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
                if let onToggleVideoDrawer {
                    onToggleVideoDrawer()
                    return
                }
                // Opening with nothing loaded yet? Kick off the saved station so
                // the drawer has something to show.
                if !audio.videoVisible, !audio.isPlaying, audio.currentURL.isEmpty,
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
        if chrome.isTiny { return 10 }
        return settings.watchface == .blueprint ? 0 : 12
    }

    // When the video drawer is docked, square the two corners on its side so the
    // HUD and drawer read as one continuous block rather than two cards kissing.
    private var cornerRadii: RectangleCornerRadii {
        let r = baseRadius
        guard !chrome.isTiny, audio.videoOpen, settings.watchface != .blueprint else {
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
        hudContent
        .animation(.easeOut(duration: 0.12), value: chrome.showShortcuts)
        .animation(.easeOut(duration: 0.16), value: chrome.isTiny)
        .frame(width: chrome.panelSize.width, height: chrome.panelSize.height)
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

    @ViewBuilder
    private var hudContent: some View {
        if chrome.isTiny {
            TinyHUDView(
                model: model,
                settings: settings,
                onExpand: { onSetTinyMode?(false) }
            )
        } else {
            fullHUDContent
        }
    }

    private var fullHUDContent: some View {
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
            QuickEntryOverlay(model: model, settings: settings, audio: audio, favorites: favorites, onEditingChange: onEditingChange)

            // Music + video drawer buttons, parked in the bottom-right corner so
            // they're out of the way of the centered transport. Only while a
            // station is configured/playing and not mid-edit.
            if audioFaceControls.enabled, model.quickField == .none {
                audioCornerControls
            }

            // Keyboard cheat sheet, toggled with `?` (or the right-click menu).
            // Sits above everything; tap / `?` / Esc to dismiss.
            if chrome.showShortcuts {
                ShortcutsOverlay(onClose: { chrome.showShortcuts = false })
                    .transition(.opacity)
            }
        }
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
            beginEditing(.intent)
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

        Button("Paste Audio / Video Link…") { beginEditing(.video) }

        Divider()

        Button(chrome.isTiny ? "Full Size HUD" : "Tiny HUD") {
            onSetTinyMode?(!chrome.isTiny)
        }
        Button("Keyboard Shortcuts") {
            if chrome.isTiny { onSetTinyMode?(false) }
            chrome.showShortcuts = true
        }

        Divider()

        Button("Hide HUD") { onHide?() }
        // You can't right-click a hidden HUD, so remind them how to bring it back.
        Button("Reopen with \(settings.hotkeyDisplay)") {}
            .disabled(true)
    }

    private func beginEditing(_ field: TimerModel.QuickField) {
        if chrome.isTiny { onSetTinyMode?(false) }
        model.beginEditing(field)
    }
}

/// A purpose-built small face for parking the HUD in a monitor corner. It keeps
/// only the at-a-glance controls that survive at this size.
private struct TinyHUDView: View {
    let model: TimerModel
    let settings: PomoSettings
    var onExpand: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var effectiveScheme: ColorScheme {
        settings.appearanceMode.colorScheme ?? scheme
    }

    private var face: Watchface { settings.watchface }
    private var isLight: Bool { effectiveScheme == .light }
    private var pal: AppPalette { .resolve(effectiveScheme) }

    private var accent: Color {
        switch face {
        case .minimal:
            if isLight, model.sessionType == .focus { return Color(hex: 0x79720F) }
            return model.sessionType.accentColor
        case .terminal:
            return Color(red: 0.35, green: 1.0, blue: 0.55)
        case .neon:
            return Color(red: 0.25, green: 0.95, blue: 1.0)
        case .retroDigital:
            return Color(red: 1.0, green: 0.78, blue: 0.18)
        case .rolodex, .chronograph:
            return model.sessionType.accentColor
        case .blueprint:
            return model.sessionType.accentColor
        }
    }

    private var secondaryAccent: Color {
        switch face {
        case .neon:
            return Color(red: 1.0, green: 0.18, blue: 0.85)
        case .retroDigital:
            return Color(red: 0.70, green: 0.38, blue: 0.08)
        case .blueprint:
            return Color(red: 0.604, green: 0.639, blue: 0.682)
        default:
            return accent.opacity(0.7)
        }
    }

    private var glassGradient: [Color] {
        switch face {
        case .minimal:
            return isLight
                ? [Color.white.opacity(0.70), Color(hex: 0xEEF0F3).opacity(0.54)]
                : [Color.black.opacity(0.34), Color.black.opacity(0.18)]
        case .terminal:
            return [Color.black.opacity(0.78), Color(red: 0.00, green: 0.08, blue: 0.035).opacity(0.62)]
        case .neon:
            return [Color(red: 0.05, green: 0.015, blue: 0.09).opacity(0.84), Color(red: 0.02, green: 0.04, blue: 0.10).opacity(0.62)]
        case .retroDigital:
            return [Color(red: 0.11, green: 0.075, blue: 0.025).opacity(0.86), Color.black.opacity(0.68)]
        case .rolodex:
            return [Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.86), Color.black.opacity(0.58)]
        case .chronograph:
            return [Color(white: 0.12).opacity(0.84), Color.black.opacity(0.62)]
        case .blueprint:
            return [Color(red: 0.102, green: 0.122, blue: 0.149).opacity(0.86), Color(red: 0.035, green: 0.047, blue: 0.063).opacity(0.70)]
        }
    }

    private var labelColor: Color {
        switch face {
        case .minimal: return isLight ? pal.dim : Color.white.opacity(0.78)
        case .terminal: return accent.opacity(0.52)
        case .neon: return accent
        case .retroDigital: return accent.opacity(0.66)
        case .rolodex: return Color.white.opacity(0.62)
        case .chronograph: return Color.white.opacity(0.66)
        case .blueprint: return secondaryAccent
        }
    }

    private var clockColor: Color {
        switch face {
        case .minimal: return isLight ? pal.ink : Color.white.opacity(0.94)
        case .terminal: return accent
        case .neon, .retroDigital: return accent
        case .rolodex, .chronograph: return Color.white.opacity(0.94)
        case .blueprint: return Color(red: 0.910, green: 0.922, blue: 0.937)
        }
    }

    private var trackColor: Color {
        switch face {
        case .minimal: return isLight ? Color.black.opacity(0.11) : Color.white.opacity(0.13)
        case .terminal: return accent.opacity(0.18)
        case .retroDigital: return accent.opacity(0.12)
        case .blueprint: return Color(red: 0.227, green: 0.259, blue: 0.302)
        default: return Color.white.opacity(0.13)
        }
    }

    private var buttonFill: Color {
        switch face {
        case .minimal: return isLight ? Color.white.opacity(0.66) : Color.white.opacity(0.08)
        case .terminal: return accent.opacity(0.08)
        case .retroDigital: return accent.opacity(0.10)
        case .blueprint: return Color(red: 0.165, green: 0.192, blue: 0.227).opacity(0.86)
        default: return Color.white.opacity(0.08)
        }
    }

    private var buttonStroke: Color {
        switch face {
        case .minimal: return isLight ? Color.black.opacity(0.11) : Color.white.opacity(0.14)
        case .terminal, .retroDigital, .blueprint: return accent.opacity(0.22)
        default: return Color.white.opacity(0.14)
        }
    }

    private var buttonIconColor: Color {
        switch face {
        case .minimal: return isLight ? Color.black.opacity(0.64) : Color.white.opacity(0.82)
        case .terminal, .retroDigital, .blueprint: return accent.opacity(0.88)
        default: return Color.white.opacity(0.82)
        }
    }

    private var clockFont: Font {
        switch face {
        case .rolodex:
            return .system(size: 30, weight: .heavy, design: .rounded)
        case .blueprint:
            return HudFont.mono(29, weight: .medium)
        default:
            return HudFont.mono(30, weight: .bold)
        }
    }

    private var faceLabel: String {
        switch face {
        case .minimal: return model.sessionType.shortLabel.uppercased()
        case .terminal: return "POMO ~/\(model.sessionType.rawValue.uppercased())"
        case .neon: return "NEON \(model.sessionType.shortLabel.uppercased())"
        case .retroDigital: return "LCD \(model.sessionType.shortLabel.uppercased())"
        case .rolodex: return "FLIP \(model.sessionType.shortLabel.uppercased())"
        case .chronograph: return "CHRONO \(model.sessionType.shortLabel.uppercased())"
        case .blueprint: return "SHEET 01 · \(model.sessionType.shortLabel.uppercased())"
        }
    }

    private var statusText: String {
        switch face {
        case .terminal:
            if model.isRunning { return "RUN" }
            return model.isPaused ? "PAUSE" : "IDLE"
        case .retroDigital:
            if model.isRunning { return "RUN" }
            return model.isPaused ? "HOLD" : "SET"
        case .blueprint:
            if model.isRunning { return "RUN" }
            return model.isPaused ? "HOLD" : "STBY"
        case .neon:
            if model.isRunning { return "LIVE" }
            return model.isPaused ? "PAUSE" : "READY"
        default:
            if model.isRunning { return "RUN" }
            if model.isPaused { return "PAUSE" }
            return "READY"
        }
    }

    private var digits: [Int] {
        let seconds = max(0, model.remainingSeconds)
        let minutes = min(99, seconds / 60)
        let secs = seconds % 60
        return [minutes / 10, minutes % 10, secs / 10, secs % 10]
    }

    var body: some View {
        ZStack {
            BackdropBlurView(radius: settings.backgroundBlur * 26)
            LinearGradient(
                colors: glassGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(face == .minimal && isLight ? 0.48 : 0.08))
                    .frame(height: 1)
            }
            faceTexture

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .shadow(color: accent.opacity(isLight ? 0.20 : 0.45), radius: 4)

                    Text(faceLabel)
                        .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(statusText)
                        .font(HudFont.mono(8, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(accent.opacity(0.9))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    tinyIconButton(
                        systemName: "arrow.up.left.and.arrow.down.right",
                        help: "Full size HUD",
                        action: onExpand
                    )
                }
                .frame(height: 18)

                HStack(alignment: .center, spacing: 8) {
                    clockReadout
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    tinyIconButton(
                        systemName: model.isRunning ? "pause.fill" : "play.fill",
                        help: model.isRunning ? "Pause" : "Start",
                        size: 26,
                        action: { model.toggle() }
                    )
                }
                .frame(height: 34)

                progressStrip
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onExpand)
    }

    @ViewBuilder
    private var faceTexture: some View {
        switch face {
        case .terminal:
            TinyScanlines(color: Color.black.opacity(0.28))
        case .neon:
            ZStack {
                Circle()
                    .fill(secondaryAccent.opacity(0.18))
                    .blur(radius: 20)
                    .offset(x: -58, y: 8)
                Circle()
                    .fill(accent.opacity(0.15))
                    .blur(radius: 16)
                    .offset(x: 62, y: -18)
            }
        case .retroDigital:
            TinyScanlines(color: Color.black.opacity(0.16), step: 4)
        case .rolodex:
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .frame(height: 1)
        case .chronograph:
            TinyChronoTexture(progress: model.progress, accent: accent)
                .opacity(0.72)
        case .blueprint:
            TinyBlueprintGrid(accent: accent)
        case .minimal:
            EmptyView()
        }
    }

    @ViewBuilder
    private var clockReadout: some View {
        switch face {
        case .retroDigital:
            TinyLCDClock(digits: digits, on: accent, off: accent.opacity(0.11))
                .frame(height: 31)
                .shadow(color: accent.opacity(0.42), radius: 5)
        case .rolodex:
            TinyFlipClock(digits: digits)
                .frame(height: 31)
        default:
            Text(model.clock)
                .font(clockFont)
                .foregroundStyle(clockColor)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()
                .shadow(color: clockShadowColor, radius: clockShadowRadius)
        }
    }

    private var clockShadowColor: Color {
        switch face {
        case .terminal, .retroDigital, .neon:
            return accent.opacity(0.55)
        default:
            return .clear
        }
    }

    private var clockShadowRadius: CGFloat {
        switch face {
        case .terminal, .retroDigital: return 5
        case .neon: return 9
        default: return 0
        }
    }

    private var progressStrip: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: progressRadius, style: .continuous)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: progressRadius, style: .continuous)
                    .fill(accent.opacity(0.92))
                    .frame(width: max(0, proxy.size.width * model.progress))
            }
        }
        .frame(height: 3)
    }

    private var progressRadius: CGFloat {
        switch face {
        case .terminal, .retroDigital, .blueprint: return 0
        default: return 2
        }
    }

    private func tinyIconButton(
        systemName: String,
        help: String,
        size: CGFloat = 22,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size > 22 ? 11 : 9, weight: .semibold))
                .foregroundStyle(buttonIconColor)
                .frame(width: size, height: size)
                .background(Circle().fill(buttonFill))
                .overlay(Circle().stroke(buttonStroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct TinyScanlines: View {
    var color: Color
    var step: CGFloat = 3

    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(color)
                )
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TinyLCDClock: View {
    let digits: [Int]
    let on: Color
    let off: Color

    var body: some View {
        HStack(spacing: 3) {
            SevenSegmentDigit(value: digits[0], on: on, off: off)
                .frame(width: 14, height: 30)
            SevenSegmentDigit(value: digits[1], on: on, off: off)
                .frame(width: 14, height: 30)
            TinySegmentColon(color: on)
            SevenSegmentDigit(value: digits[2], on: on, off: off)
                .frame(width: 14, height: 30)
            SevenSegmentDigit(value: digits[3], on: on, off: off)
                .frame(width: 14, height: 30)
        }
    }
}

private struct TinySegmentColon: View {
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Circle().fill(color).frame(width: 4, height: 4)
            Circle().fill(color).frame(width: 4, height: 4)
        }
        .frame(width: 6, height: 28)
        .shadow(color: color.opacity(0.5), radius: 3)
    }
}

private struct TinyFlipClock: View {
    let digits: [Int]

    var body: some View {
        HStack(spacing: 3) {
            TinyFlipDigit(value: digits[0])
            TinyFlipDigit(value: digits[1])
            TinyFlipColon()
            TinyFlipDigit(value: digits[2])
            TinyFlipDigit(value: digits[3])
        }
    }
}

private struct TinyFlipDigit: View {
    let value: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.25), Color(white: 0.11)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("\(value)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .id(value)
                .transition(.push(from: .top).combined(with: .opacity))
        }
        .frame(width: 20, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .animation(.snappy(duration: 0.16, extraBounce: 0.0), value: value)
    }
}

private struct TinyFlipColon: View {
    var body: some View {
        VStack(spacing: 6) {
            Circle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 4)
            Circle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 4)
        }
        .frame(width: 5, height: 28)
    }
}

private struct TinyChronoTexture: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width * 0.18, y: size.height * 0.58)
                let radius = min(size.width, size.height) * 0.38
                for i in 0..<30 {
                    let major = i % 5 == 0
                    let angle = CGFloat(i) / 30 * 2 * .pi - .pi / 2
                    let outer = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let innerRadius = radius - (major ? 7 : 4)
                    let inner = CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    )
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    ctx.stroke(path, with: .color(.white.opacity(major ? 0.34 : 0.18)), lineWidth: major ? 1.3 : 1)
                }

                let handAngle = CGFloat(progress) * 2 * .pi - .pi / 2
                var hand = Path()
                hand.move(to: center)
                hand.addLine(to: CGPoint(
                    x: center.x + cos(handAngle) * (radius - 8),
                    y: center.y + sin(handAngle) * (radius - 8)
                ))
                ctx.stroke(hand, with: .color(accent.opacity(0.78)), lineWidth: 2)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(accent))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

private struct TinyBlueprintGrid: View {
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let grid = Color(red: 0.165, green: 0.192, blue: 0.227)
            let line = Color(red: 0.227, green: 0.259, blue: 0.302)
            func stroke(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat = 1) {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                ctx.stroke(path, with: .color(color), lineWidth: width)
            }

            var x: CGFloat = 0
            var xi = 0
            while x <= size.width {
                stroke(CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height), xi % 6 == 0 ? line.opacity(0.62) : grid.opacity(0.54))
                x += 12
                xi += 1
            }

            var y: CGFloat = 0
            var yi = 0
            while y <= size.height {
                stroke(CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y), yi % 6 == 0 ? line.opacity(0.62) : grid.opacity(0.54))
                y += 12
                yi += 1
            }

            let frame = CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12)
            ctx.stroke(Path(frame), with: .color(line.opacity(0.78)), lineWidth: 1)
            stroke(CGPoint(x: 0, y: size.height - 12), CGPoint(x: size.width * CGFloat(0.22 + 0.74), y: size.height - 12), accent.opacity(0.55), 1.4)
        }
        .allowsHitTesting(false)
    }
}

/// A translucent reference card of the HUD's keyboard shortcuts. Toggled with
/// `?` (or the right-click menu); dismissed with `?` again, Escape, or a tap.
/// Two compact columns so it fits the panel without scrolling.
private struct ShortcutsOverlay: View {
    var onClose: () -> Void

    private let left: [(String, String)] = [
        ("Space", "Start / Pause"),
        ("S", "Start"),
        ("P", "Pause"),
        ("R", "Reset"),
        ("N", "Skip session"),
        ("C", "Cycle type"),
        ("T", "Next face"),
        ("↑ ↓", "±1 min · ⇧5"),
    ]
    private let right: [(String, String)] = [
        ("1–9", "Set 5–45 min"),
        ("I", "Set intent"),
        ("V", "Paste link"),
        ("⇧V", "Show/hide video"),
        ("M", "Music play/pause"),
        ("Y", "Tiny mode"),
        ("← →", "Timestamp section"),
        ("⌘ ,", "Settings"),
        ("Esc Q", "Hide HUD"),
    ]

    var body: some View {
        ZStack {
            // Tap anywhere to dismiss.
            Rectangle()
                .fill(Color.black.opacity(0.86))
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: HudSpacing.md) {
                HStack {
                    Text("KEYBOARD")
                        .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(HudPalette.dim)
                    Spacer(minLength: HudSpacing.sm)
                    Text("? or esc to close")
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(HudPalette.dim.opacity(0.7))
                }

                HStack(alignment: .top, spacing: HudSpacing.lg) {
                    column(left)
                    column(right)
                }
            }
            .padding(HudSpacing.xl)
        }
    }

    private func column(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.xs) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: HudSpacing.sm) {
                    keyCap(rows[i].0)
                    Text(rows[i].1)
                        .font(HudFont.mono(HudTextSize.xxs))
                        .foregroundStyle(HudPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keyCap(_ key: String) -> some View {
        Text(key)
            .font(HudFont.mono(HudTextSize.xxs, weight: .semibold))
            .foregroundStyle(HudPalette.ink)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(minWidth: 40)
            .background(RoundedRectangle(cornerRadius: HudRadius.tight, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: HudRadius.tight, style: .continuous).stroke(HudPalette.border, lineWidth: 1))
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
    var onEditingChange: ((Bool) -> Void)? = nil

    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    private var field: TimerModel.QuickField { model.quickField }
    private var accent: Color { model.sessionType.tint.color }

    var body: some View {
        ZStack {
            if field != .none {
                // Scrim — tap anywhere outside the card to cancel. Near-opaque so
                // the face (and desktop) don't read through behind the editor.
                Rectangle()
                    .fill(Color.black.opacity(0.82))
                    .contentShape(Rectangle())
                    .onTapGesture { model.cancelEditing() }

                card.padding(.horizontal, HudSpacing.xxl)
            }
        }
        .animation(.easeOut(duration: 0.15), value: field)
        .onChange(of: field) { _, newField in
            // Drive the panel opaque while editing so the card is crisp.
            onEditingChange?(newField != .none)
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
                .fill(Color(white: 0.13))   // solid, not the frosted inset
        )
        .overlay(
            RoundedRectangle(cornerRadius: HudRadius.standard, style: .continuous)
                .stroke(HudPalette.border, lineWidth: 1)
        )
    }

    // MARK: - Per-mode copy + behaviour

    private var title: String {
        switch field {
        case .video:           return "PASTE A YOUTUBE, SOUNDCLOUD, OR AUDIO LINK"
        case .intent, .none:   return "WHAT ARE YOU WORKING ON?"
        }
    }

    private var placeholder: String {
        switch field {
        case .video:           return "https://youtube.com/… or soundcloud.com/…"
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
