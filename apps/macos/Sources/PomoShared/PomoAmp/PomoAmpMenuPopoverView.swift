import AppKit
import SwiftUI
import HudsonUI
import HudsonShell

struct PomoAmpMenuPopoverView: View {
    let settings: PomoSettings
    let audio: AudioController
    let favorites: FavoritesStore
    var onShowDeck: () -> Void
    var onToggleAudio: () -> Void
    var onPreviousTrack: () -> Void
    var onNextTrack: () -> Void
    var onPreviousSection: () -> Void
    var onNextSection: () -> Void
    var onPasteURL: () -> Void
    var onToggleVideo: () -> Void
    var onTogglePageMode: () -> Void
    var onOpenInBrowser: () -> Void
    var onToggleBig: () -> Void
    var onToggleCompactMode: () -> Void
    var onShowShortcuts: () -> Void
    var onTogglePomo: () -> Void
    var onPlayFavorite: (Favorite) -> Void

    private var face: PomoAmpFace { settings.pomoAmpFace }
    private var accent: Color { face.accent }
    private var secondary: Color { face.secondary }
    private var currentURL: String {
        if !audio.currentURL.isEmpty { return audio.currentURL }
        if !settings.audioURL.isEmpty { return settings.audioURL }
        return favorites.items.first?.url ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            nowPlaying
            transport
            section("LIBRARY") { youtubeControls }
            section("FAVORITES") { favoritesList }
            section("FACE") { faceStrip }
            footer
        }
        .padding(14)
        .frame(width: 326)
        .background(background)
        .environment(\.hudTheme, .default)
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            HudVisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            LinearGradient(
                colors: [Color(hex: 0x17191D).opacity(0.96), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
            }
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [accent.opacity(0.16), .clear],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .frame(height: 170)
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("POMO AMP")
                    .font(HudFont.mono(HudTextSize.xxs, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                Text(sourceLabel.uppercased())
                    .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            miniIconButton("questionmark", help: "Keyboard shortcuts") { onShowShortcuts() }
            pomoButton
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            thumbnail(for: currentURL, width: 92, height: 62, iconSize: 18)

            VStack(alignment: .leading, spacing: 7) {
                Text(nowPlayingTitle)
                    .font(HudFont.ui(15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    statusPill(audio.isPlaying ? "PLAYING" : currentURL.isEmpty ? "READY" : "PAUSED", active: audio.isPlaying)
                    Text(audio.videoOpen ? (audio.videoExpanded ? "PAGE" : "PLAYER") : "AUDIO")
                        .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.44))
                }

                progressBar
            }
        }
        .padding(9)
        .background(panelFill)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let duration = max(0, audio.mediaDuration)
            let progress = duration > 0 ? min(max(audio.estimatedMediaTime() / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [accent, secondary.opacity(0.80)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(duration > 0 ? 8 : 0, proxy.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 4)
    }

    private var transport: some View {
        HStack(spacing: 8) {
            transportButton("backward.end.fill", help: "Previous track") { onPreviousTrack() }
            Button(action: onToggleAudio) {
                HStack(spacing: 7) {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(audio.isPlaying ? "Pause" : "Play")
                        .font(HudFont.ui(HudTextSize.xs, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(width: 112, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent)
                        .shadow(color: accent.opacity(0.16), radius: 8, y: 2)
                )
            }
            .buttonStyle(.plain)
            .help(audio.isPlaying ? "Pause" : "Play")
            transportButton("forward.end.fill", help: "Next track") { onNextTrack() }
            Spacer(minLength: 0)
            transportButton("rectangle.stack", help: "Show deck") { onShowDeck() }
        }
    }

    private var youtubeControls: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                commandButton(audio.videoOpen ? "Hide Video" : "Show Video", symbol: audio.videoOpen ? "rectangle.slash" : "play.rectangle") {
                    onToggleVideo()
                }
                commandButton(audio.videoExpanded ? "Player" : "Page", symbol: audio.videoExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                    onTogglePageMode()
                }
                commandButton("Browser", symbol: "safari") {
                    onOpenInBrowser()
                }
            }
            HStack(spacing: 7) {
                commandButton("Paste URL", symbol: "doc.on.clipboard") {
                    onPasteURL()
                }
                commandButton("Prev Section", symbol: "arrow.left.to.line.compact") {
                    onPreviousSection()
                }
                commandButton("Next Section", symbol: "arrow.right.to.line.compact") {
                    onNextSection()
                }
            }
        }
    }

    private var favoritesList: some View {
        Group {
            if favorites.items.isEmpty {
                Text("No saved links")
                    .font(HudFont.ui(HudTextSize.xs, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(panelFill)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(favorites.items.prefix(8)) { favorite in
                            favoriteRow(favorite)
                        }
                    }
                    .padding(1)
                }
                .frame(maxHeight: favorites.items.count > 4 ? 158 : nil)
            }
        }
    }

    private func favoriteRow(_ favorite: Favorite) -> some View {
        Button { onPlayFavorite(favorite) } label: {
            HStack(spacing: 8) {
                thumbnail(for: favorite.url, width: 36, height: 26, iconSize: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.title)
                        .font(HudFont.ui(HudTextSize.xs, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .lineLimit(1)
                    Text(Self.shortURL(favorite.url))
                        .font(HudFont.mono(HudTextSize.micro, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.36))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: favorite.url == currentURL ? "speaker.wave.2.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(favorite.url == currentURL ? accent : Color.white.opacity(0.36))
            }
            .padding(7)
            .background(panelFill)
        }
        .buttonStyle(.plain)
        .help(favorite.title)
    }

    private var faceStrip: some View {
        HStack(spacing: 7) {
            ForEach(PomoAmpFace.allCases) { item in
                Button {
                    settings.pomoAmpFace = item
                    settings.saveNow()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.accent)
                            .frame(width: 7, height: 7)
                        Text(item.displayName)
                            .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                    }
                    .foregroundStyle(item == face ? Color.black.opacity(0.84) : Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(item == face ? item.accent : Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(item == face ? Color.white.opacity(0.20) : Color.white.opacity(0.09), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            commandButton("Big", symbol: "arrow.up.left.and.arrow.down.right") { onToggleBig() }
            commandButton("Shade", symbol: "rectangle.compress.vertical") { onToggleCompactMode() }
            Spacer(minLength: 0)
            pomoButton
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(HudFont.mono(HudTextSize.micro, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.38))
            content()
        }
    }

    private func transportButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent.opacity(0.95))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func commandButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(HudFont.ui(HudTextSize.micro, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(Color.white.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.065))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func miniIconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.66))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var pomoButton: some View {
        Button(action: onTogglePomo) {
            Image(nsImage: PomoStatusIcon.timerRing(size: 16))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(PomoBrand.accent)
                .frame(width: 16, height: 16)
            .frame(width: 30, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(PomoBrand.accent.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(PomoBrand.accent.opacity(0.30), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .help("Show / Hide Pomo")
    }

    private var panelFill: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.white.opacity(0.065))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
    }

    private func statusPill(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(HudFont.mono(HudTextSize.micro, weight: .black))
            .tracking(0.9)
            .foregroundStyle(active ? Color.black.opacity(0.84) : Color.white.opacity(0.50))
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(Capsule().fill(active ? accent : Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private func thumbnail(for urlString: String, width: CGFloat, height: CGFloat, iconSize: CGFloat) -> some View {
        let artwork = PlaybackSource.artworkURL(
            for: urlString,
            liveArtwork: urlString == currentURL ? audio.currentArtworkURL : ""
        )
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .frame(width: width, height: height)
            .overlay {
                if let artwork, let url = URL(string: artwork) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.34))
                        }
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var nowPlayingTitle: String {
        if let favorite = favorites.items.first(where: { $0.url == currentURL }) {
            return favorite.title
        }
        let title = audio.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        guard !currentURL.isEmpty else { return "Paste a YouTube or SoundCloud URL" }
        return Self.shortURL(currentURL)
    }

    private var sourceLabel: String {
        guard let host = URL(string: currentURL)?.host else { return "music deck" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private static func shortURL(_ raw: String) -> String {
        guard let url = URL(string: raw), let host = url.host else { return raw }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
