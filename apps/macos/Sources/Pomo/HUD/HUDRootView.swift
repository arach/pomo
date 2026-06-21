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
    let size: CGSize

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
    }
}
