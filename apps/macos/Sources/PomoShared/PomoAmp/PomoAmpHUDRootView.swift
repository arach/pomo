import AppKit
import SwiftUI
import HudsonUI

struct PomoAmpHUDRootView: View {
    let settings: PomoSettings
    let audio: AudioController
    let favorites: FavoritesStore
    let chrome: PomoAmpChrome
    let htmlSkin: PomoAmpSkin?
    var onHide: (() -> Void)?
    var onOpenPomo: () -> Void
    var onPasteURL: () -> Void
    var onToggleAudio: () -> Void
    var onToggleDrawer: () -> Void
    var onExpandVideo: () -> Void
    var onMinimizeVideo: () -> Void
    var onShowVideoPage: () -> Void
    var onShowVideoPlayer: () -> Void
    var onToggleBig: () -> Void
    var onToggleRolledUp: () -> Void
    var onSetBig: (Bool) -> Void
    var onToggleVizInspector: () -> Void
    var onPreviousSection: () -> Void
    var onNextSection: () -> Void

    private var face: PomoAmpFace { settings.pomoAmpFace }
    private var accent: Color { face.accent }
    private var secondary: Color { face.secondary }
    private var visualizerProfile: PomoAmpVisualizerProfile { settings.pomoAmpVisualizerMode.profile }
    private var deckSize: CGSize {
        chrome.isBig ? CGSize(width: 640, height: 360) : CGSize(width: 386, height: 198)
    }
    private var surfaceSize: CGSize {
        CGSize(width: deckSize.width, height: deckSize.height + PomoAmpChrome.titleBarHeight)
    }
    private var skinFrameInterval: TimeInterval {
        audio.isPlaying ? visualizerProfile.skinFrameInterval : 1.0
    }
    private var inspectorFrameInterval: TimeInterval {
        audio.isPlaying ? visualizerProfile.inspectorFrameInterval : 1.0
    }
    private var isDevBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            deckSurface

            if !chrome.isRolledUp, isDevBuild, chrome.showVizInspector {
                TimelineView(.periodic(from: Date(), by: inspectorFrameInterval)) { _ in
                    PomoAmpVizInspectorView(viz: vizData())
                }
                .frame(width: 268, height: chrome.panelSize.height)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: chrome.panelSize.width, height: chrome.panelSize.height, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: chrome.showVizInspector)
        .task(id: visualizerProfile.scopeFrameIntervalMilliseconds) {
            audio.setVisualizerScopeFrameInterval(milliseconds: visualizerProfile.scopeFrameIntervalMilliseconds)
        }
    }

    private var deckSurface: some View {
        VStack(spacing: 0) {
            titleBar

            if !chrome.isRolledUp {
                ZStack {
                    if let htmlSkin {
                        TimelineView(.periodic(from: Date(), by: skinFrameInterval)) { _ in
                            PomoAmpSkinWebView(
                                skin: htmlSkin,
                                state: skinState,
                                viz: vizData(),
                                profile: visualizerProfile,
                                onAction: { action in handleSkinAction(action) }
                            )
                            .id(htmlSkin.id)
                            .background(Color.black)
                        }
                    } else {
                        nativeDeck
                    }

                    if chrome.showShortcuts {
                        PomoAmpShortcutsOverlay(onClose: { chrome.showShortcuts = false })
                    }
                }
                .frame(width: deckSize.width, height: deckSize.height)
            }
        }
        .frame(width: chrome.isRolledUp ? chrome.panelSize.width : surfaceSize.width, height: chrome.panelSize.height)
        .background(Color.black.opacity(htmlSkin == nil ? 0.2 : 0.72))
        .clipShape(RoundedRectangle(cornerRadius: chrome.isRolledUp ? 8 : 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: chrome.isRolledUp ? 8 : 10, style: .continuous).stroke(htmlSkin == nil ? accent.opacity(0.34) : Color.white.opacity(0.16), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: chrome.isRolledUp ? 8 : 10, style: .continuous).stroke(Color.black.opacity(0.46), lineWidth: 1).padding(0.5))
        .environment(\.hudTheme, .default)
        .contextMenu { contextMenu }
    }

    private var nativeDeck: some View {
        ZStack {
            BackdropBlurView(radius: settings.backgroundBlur * 28)

            LinearGradient(colors: face.background, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Color.black.opacity(0.24))

            VStack(spacing: 10) {
                header
                display
                transport
                faceStrip
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var titleBar: some View {
        if chrome.isRolledUp {
            shadeBar
        } else {
            fullTitleBar
        }
    }

    private var shadeBar: some View {
        VStack(spacing: 3) {
            shadeTitleRow
            shadeControlRow
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(height: PomoAmpChrome.shadeBarHeight)
        .background(titleBarBackground)
        .overlay(alignment: .bottom) {
            shadeProgressEdge
        }
    }

    private var shadeTitleRow: some View {
        ZStack {
            PomoAmpWindowDragHandle(onMiddleClick: onToggleRolledUp)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(nowPlayingTitle)
                .font(HudFont.ui(HudTextSize.sm, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 66)
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false)

            HStack(spacing: 5) {
                chromeButton("power", help: "Quit Pomo Amp", tone: .danger) {
                    PomoAmpDebugLog.write("shade bar quit")
                    NSApp.terminate(nil)
                }
                chromeButton("minus", help: "Hide Pomo Amp") {
                    onHide?()
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 22)
        .help("Drag Pomo Amp; middle-click to expand")
    }

    private var shadeControlRow: some View {
        ZStack {
            HStack(spacing: 5) {
                chromeButton("link", help: "Paste YouTube URL") {
                    onPasteURL()
                }
                openPomoButton()
                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                chromeButton("backward.end.fill", help: "Previous timestamp section") {
                    onPreviousSection()
                }
                chromeButton(audio.isPlaying ? "pause.fill" : "play.fill", help: audio.isPlaying ? "Pause" : "Play", tone: .primary) {
                    onToggleAudio()
                }
                chromeButton("forward.end.fill", help: "Next timestamp section") {
                    onNextSection()
                }
            }

            HStack(spacing: 5) {
                Spacer(minLength: 0)
                chromeButton(audio.videoOpen ? "rectangle.fill" : "play.rectangle", help: audio.videoOpen ? "Hide video" : "Show video") {
                    onToggleDrawer()
                }
                chromeButton(
                    chrome.isBig ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    help: chrome.isBig ? "Normal size" : "Big"
                ) {
                    onToggleBig()
                }
                chromeButton("chevron.down", help: "Expand") {
                    onToggleRolledUp()
                }
            }
        }
        .frame(height: 22)
    }

    private var shadeProgressEdge: some View {
        GeometryReader { proxy in
            let duration = max(0, audio.mediaDuration)
            let progress = duration > 0 ? min(max(audio.estimatedMediaTime() / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.09))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.78), secondary.opacity(0.58)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 2)
        .allowsHitTesting(false)
    }

    private var fullTitleBar: some View {
        HStack(spacing: 6) {
            chromeButton("power", help: "Quit Pomo Amp", tone: .danger) {
                PomoAmpDebugLog.write("title bar quit")
                NSApp.terminate(nil)
            }

            chromeButton("minus", help: "Hide Pomo Amp") {
                onHide?()
            }

            openPomoButton()

            dragTitle

            chromeButton(audio.videoOpen ? "rectangle.fill" : "play.rectangle", help: audio.videoOpen ? "Hide video" : "Show video") {
                onToggleDrawer()
            }

            chromeButton(
                audio.videoExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                help: audio.videoExpanded ? "Show player" : "Show page"
            ) {
                if audio.videoExpanded {
                    onShowVideoPlayer()
                } else {
                    onShowVideoPage()
                }
            }

            if isDevBuild {
                chromeButton("waveform.path.ecg.rectangle", help: chrome.showVizInspector ? "Hide viz data" : "Show viz data") {
                    onToggleVizInspector()
                }
            }

            chromeButton("chevron.up", help: "Shade") {
                onToggleRolledUp()
            }

            chromeButton(
                chrome.isBig ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                help: chrome.isBig ? "Normal size" : "Big"
            ) {
                onToggleBig()
            }
        }
        .padding(.horizontal, 7)
        .frame(height: PomoAmpChrome.titleBarHeight)
        .background(titleBarBackground)
    }

    private var shadeDragTitle: some View {
        ZStack {
            PomoAmpWindowDragHandle(onMiddleClick: onToggleRolledUp)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(nowPlayingTitle)
                .font(HudFont.ui(HudTextSize.sm, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17)
        .help("Drag Pomo Amp; middle-click to expand")
    }

    private var dragTitle: some View {
        ZStack {
            PomoAmpWindowDragHandle(onMiddleClick: onToggleRolledUp)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.56))
                Text("POMO AMP")
                    .font(HudFont.mono(HudTextSize.micro, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(accent.opacity(0.9))
                Text(audio.videoOpen ? (audio.videoExpanded ? "PAGE" : "PLAYER") : "AUDIO")
                    .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.46))
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)
        .help("Drag Pomo Amp; middle-click to \(chrome.isRolledUp ? "expand" : "compact")")
    }

    private var titleBarBackground: some View {
        Rectangle()
            .fill(Color.black.opacity(htmlSkin == nil ? 0.18 : 0.54))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
    }

    private enum ChromeButtonTone {
        case normal
        case primary
        case danger
    }

    private func chromeButton(_ symbol: String, help: String, tone: ChromeButtonTone = .normal, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(chromeButtonForeground(tone))
                .frame(width: tone == .primary ? 28 : 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(chromeButtonFill(tone))
                        .shadow(color: Color.black.opacity(tone == .primary ? 0.24 : 0.16), radius: 3, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(chromeButtonStroke(tone), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func openPomoButton() -> some View {
        Button(action: onOpenPomo) {
            Group {
                if let icon = Self.pomoIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                } else {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(chromeButtonForeground(.normal))
                }
            }
            .frame(width: 14, height: 14)
            .frame(width: 24, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(chromeButtonFill(.normal))
                    .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(PomoBrand.accent.opacity(0.36), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Show / Hide Pomo")
    }

    private static let pomoIcon: NSImage? = {
        if let image = NSImage(named: "AppIcon") {
            return image
        }
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    private func chromeButtonFill(_ tone: ChromeButtonTone) -> AnyShapeStyle {
        switch tone {
        case .normal:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.045)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accent.opacity(0.96), accent.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .danger:
            return AnyShapeStyle(Color(red: 0.55, green: 0.22, blue: 0.19).opacity(0.44))
        }
    }

    private func chromeButtonForeground(_ tone: ChromeButtonTone) -> Color {
        switch tone {
        case .normal:
            return Color.white.opacity(0.80)
        case .primary:
            return Color.black.opacity(0.82)
        case .danger:
            return Color.white.opacity(0.84)
        }
    }

    private func chromeButtonStroke(_ tone: ChromeButtonTone) -> Color {
        switch tone {
        case .normal:
            return Color.white.opacity(0.16)
        case .primary:
            return accent.opacity(0.55)
        case .danger:
            return Color.white.opacity(0.14)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("POMO AMP")
                .font(HudFont.mono(HudTextSize.xs, weight: .black))
                .tracking(2)
                .foregroundStyle(accent)
            Text("YouTube deck")
                .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
            Spacer(minLength: 0)
            Text(face.displayName.uppercased())
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .foregroundStyle(secondary.opacity(0.88))
        }
    }

    private var display: some View {
        HStack(spacing: 12) {
            skinGlyph
                .frame(width: 72, height: 54)

            VStack(alignment: .leading, spacing: 7) {
                Text(nowPlayingTitle)
                    .font(HudFont.mono(15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    Text(audio.isPlaying ? "PLAYING" : "READY")
                        .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                        .foregroundStyle(audio.isPlaying ? accent : Color.white.opacity(0.42))
                    Text(sourceLabel)
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .lineLimit(1)
                }

                spectrum
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.34)))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private var skinGlyph: some View {
        switch face {
        case .classic:
            ZStack {
                RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.9), lineWidth: 1.4)
                Text("YT")
                    .font(HudFont.mono(20, weight: .black))
                    .foregroundStyle(accent)
            }
        case .cassette:
            ZStack {
                RoundedRectangle(cornerRadius: 6).stroke(secondary.opacity(0.72), lineWidth: 1.2)
                HStack(spacing: 14) {
                    Circle().stroke(accent.opacity(0.9), lineWidth: 2)
                    Circle().stroke(accent.opacity(0.9), lineWidth: 2)
                }
                Capsule().fill(Color.black.opacity(0.5)).frame(width: 38, height: 9)
            }
        case .spectrum:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index.isMultiple(of: 2) ? accent : secondary)
                        .frame(width: 4, height: CGFloat([12, 28, 18, 44, 24, 38, 16, 34, 22, 48][index]))
                }
            }
        }
    }

    private var spectrum: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<28, id: \.self) { index in
                Capsule()
                    .fill(index % 3 == 0 ? secondary.opacity(0.8) : accent.opacity(0.72))
                    .frame(width: 3, height: barHeight(index))
            }
        }
        .frame(height: 20, alignment: .bottom)
        .opacity(audio.isPlaying ? 1 : 0.42)
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [5, 9, 14, 7, 18, 11, 4, 16, 20, 8, 13, 6, 17, 10]
        return pattern[index % pattern.count]
    }

    private var transport: some View {
        HStack(spacing: 9) {
            deckButton("backward.end.fill", help: "Previous track") { playAdjacentTrack(-1) }
            deckButton(audio.isPlaying ? "pause.fill" : "play.fill", help: audio.isPlaying ? "Pause" : "Play", prominent: true) {
                onToggleAudio()
            }
            deckButton("forward.end.fill", help: "Next track") { playAdjacentTrack(1) }
            divider
            deckButton("doc.on.clipboard", help: "Paste YouTube URL") { onPasteURL() }
            deckButton(audio.videoOpen ? "rectangle.fill" : "play.rectangle", help: audio.videoOpen ? "Hide video" : "Show video") {
                onToggleDrawer()
            }
            Spacer(minLength: 0)
            deckButton("questionmark", help: "Keyboard shortcuts") { chrome.showShortcuts = true }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 2)
    }

    private func deckButton(_ symbol: String, help: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 13 : 11, weight: .bold))
                .foregroundStyle(prominent ? Color.black.opacity(0.82) : accent.opacity(0.92))
                .frame(width: prominent ? 34 : 28, height: prominent ? 34 : 28)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(prominent ? accent : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(prominent ? Color.white.opacity(0.22) : accent.opacity(0.26), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .help(help)
    }

    private var faceStrip: some View {
        HStack(spacing: 6) {
            ForEach(PomoAmpFace.allCases) { item in
                Button {
                    settings.pomoAmpFace = item
                    settings.saveNow()
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(item.accent).frame(width: 7, height: 7)
                        Text(item.displayName)
                            .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                    }
                    .foregroundStyle(item == face ? Color.black.opacity(0.82) : Color.white.opacity(0.58))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(item == face ? item.accent : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var contextMenu: some View {
        Group {
            Button(audio.isPlaying ? "Pause" : "Play") { onToggleAudio() }
            Button("Previous Timestamp Section") { onPreviousSection() }
            Button("Next Timestamp Section") { onNextSection() }
            Button("Paste YouTube URL") { onPasteURL() }
            Button(audio.videoOpen ? "Hide Video" : "Show Video") { onToggleDrawer() }
            Button(audio.videoExpanded ? "Show Player" : "Show Page") {
                if audio.videoExpanded {
                    onShowVideoPlayer()
                } else {
                    onShowVideoPage()
                }
            }
            Button(chrome.isRolledUp ? "Expand" : "Compact Mode") { onToggleRolledUp() }
            Button(chrome.isBig ? "Normal Size" : "Big") { onToggleBig() }
            if isDevBuild {
                Button(chrome.showVizInspector ? "Hide Viz Data" : "Show Viz Data") {
                    onToggleVizInspector()
                }
            }
            Divider()
            Menu("Face") {
                ForEach(PomoAmpFace.allCases) { item in
                    Button(item.displayName) {
                        settings.pomoAmpFace = item
                        settings.saveNow()
                    }
                }
            }
            Divider()
            Button("Keyboard Shortcuts") { chrome.showShortcuts = true }
            Button("Show / Hide Pomo") { onOpenPomo() }
            Button("Hide Pomo Amp") { onHide?() }
        }
    }

    private var skinState: PomoAmpSkinState {
        PomoAmpSkinState(
            isPlaying: audio.isPlaying,
            title: nowPlayingTitle,
            url: activeURL,
            thumbnailURL: thumbnailURL,
            source: sourceLabel,
            videoOpen: audio.videoOpen,
            videoExpanded: audio.videoExpanded,
            isBig: chrome.isBig,
            face: htmlSkin?.manifest.id ?? face.rawValue,
            shortcuts: [
                .init(key: "Space", label: "Play / pause"),
                .init(key: "B", label: "Big / normal"),
                .init(key: "C", label: "Compact mode"),
                .init(key: "P", label: "Page / player"),
                .init(key: "V", label: "Paste URL"),
                .init(key: "Shift+V", label: "Show / hide video"),
                .init(key: "Left / Right", label: "Timestamp section"),
                .init(key: "Middle click title", label: "Compact / expand"),
                .init(key: "?", label: "Shortcuts"),
                .init(key: "Esc", label: "Hide"),
            ]
        )
    }

    private func vizData() -> PomoAmpVizData {
        let hostTime = ProcessInfo.processInfo.systemUptime
        return PomoAmpVizAnalyzer.frame(
            isPlaying: audio.isPlaying,
            mediaTime: audio.estimatedMediaTime(at: hostTime),
            duration: audio.mediaDuration,
            playbackRate: audio.mediaPlaybackRate,
            hostTime: hostTime,
            scope: audio.audioScope,
            scopeError: audio.audioScopeError
        )
    }

    private func handleSkinAction(_ action: PomoAmpSkinAction) {
        PomoAmpDebugLog.write("hud root action begin action=\(action.rawValue) \(videoDebugState)")
        defer {
            PomoAmpDebugLog.write("hud root action end action=\(action.rawValue) \(videoDebugState)")
        }
        switch action {
        case .playPause:
            onToggleAudio()
        case .previousTrack:
            playAdjacentTrack(-1)
        case .nextTrack:
            playAdjacentTrack(1)
        case .previousSection:
            onPreviousSection()
        case .nextSection:
            onNextSection()
        case .toggleVideo:
            onToggleDrawer()
        case .showVideo:
            if !audio.videoVisible {
                onToggleDrawer()
            }
        case .hideVideo:
            if audio.videoVisible {
                onToggleDrawer()
            }
        case .expandVideo:
            onExpandVideo()
        case .minimizeVideo:
            onMinimizeVideo()
        case .showVideoPage:
            onShowVideoPage()
        case .showVideoPlayer:
            onShowVideoPlayer()
        case .pasteURL:
            onPasteURL()
        case .enableAudioScope:
            audio.requestAudioScopePermission()
        case .showShortcuts:
            chrome.showShortcuts = true
        case .minimizeWindow:
            onHide?()
        case .toggleBig:
            onToggleBig()
        case .enterBig:
            onSetBig(true)
        case .exitBig:
            onSetBig(false)
        case .hide:
            onHide?()
        case .nextNativeFace:
            settings.pomoAmpFace = settings.pomoAmpFace.next
            settings.saveNow()
        }
    }

    private var videoDebugState: String {
        "videoVisible=\(audio.videoVisible) videoOpen=\(audio.videoOpen) videoExpanded=\(audio.videoExpanded) isPlaying=\(audio.isPlaying) currentURL=\(audio.currentURL.isEmpty ? "<empty>" : audio.currentURL)"
    }

    private var activeURL: String {
        if !audio.currentURL.isEmpty { return audio.currentURL }
        if !settings.audioURL.isEmpty { return settings.audioURL }
        return favorites.items.first?.url ?? ""
    }

    private func playAdjacentTrack(_ delta: Int) {
        guard let favorite = adjacentFavorite(delta) else { return }
        audio.play(urlString: favorite.url)
    }

    private func adjacentFavorite(_ delta: Int) -> Favorite? {
        let items = favorites.items
        guard !items.isEmpty else { return nil }
        let currentIndex = items.firstIndex { $0.url == activeURL }
        let current = currentIndex ?? (delta < 0 ? 0 : -1)
        let next = (current + delta + items.count) % items.count
        return items[next]
    }

    private var nowPlayingTitle: String {
        if let favorite = favorites.items.first(where: { $0.url == activeURL }) {
            return favorite.title
        }
        let title = audio.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        guard !activeURL.isEmpty else { return "Paste a YouTube URL" }
        return Self.shortURL(activeURL)
    }

    private var sourceLabel: String {
        guard let host = URL(string: activeURL)?.host else { return "no source" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var thumbnailURL: String {
        guard let id = WebAudioPlayer.youTubeID(from: activeURL) else { return "" }
        return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
    }

    private static func shortURL(_ raw: String) -> String {
        guard let url = URL(string: raw) else { return raw }
        if let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return raw
    }
}

private struct PomoAmpShortcutsOverlay: View {
    var onClose: () -> Void

    private let rows: [(String, String)] = [
        ("Space", "Play / pause"),
        ("B", "Big / normal"),
        ("C", "Compact mode"),
        ("Middle click title", "Compact / expand"),
        ("P", "Page / player"),
        ("V", "Paste URL"),
        ("⇧V", "Show / hide video"),
        ("← →", "Timestamp section"),
        ("T", "Next face"),
        ("?", "Help"),
        ("Esc Q", "Hide"),
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.88))
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("POMO AMP KEYS")
                        .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(HudPalette.dim)
                    Spacer()
                    Text("? or esc")
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(HudPalette.dim.opacity(0.7))
                }
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(rows[index].0)
                            .font(HudFont.mono(HudTextSize.xxs, weight: .semibold))
                            .foregroundStyle(HudPalette.ink)
                            .frame(width: 58, alignment: .center)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)))
                        Text(rows[index].1)
                            .font(HudFont.mono(HudTextSize.xxs))
                            .foregroundStyle(HudPalette.muted)
                    }
                }
            }
            .padding(18)
        }
    }
}
