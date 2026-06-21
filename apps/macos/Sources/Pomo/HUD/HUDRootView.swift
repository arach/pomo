import SwiftUI
import HudsonUI
import HudsonShell

/// The SwiftUI content hosted inside the floating panel: a frosted, rounded HUD
/// card rendering whichever watchface is selected. Reads `settings` so cycling
/// the face or changing opacity updates live.
struct HUDRootView: View {
    let model: TimerModel
    let settings: PomoSettings
    let size: CGSize

    // The Blueprint face reads as a drafting sheet, so it wants hard, near-square
    // corners; every other face keeps the soft frosted-HUD radius.
    private var cornerRadius: CGFloat {
        settings.watchface == .blueprint ? 0 : 18
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .blendMode(.plusDarker)
                .padding(0.5)
        )
        // Panel-level opacity is applied to the window's alphaValue by
        // HUDController (so it composes with the summon/dismiss fade).
        .environment(\.hudTheme, .default)
    }
}
