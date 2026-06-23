import SwiftUI
import HudsonUI

/// Clean, Hudson-native face: big monospaced clock, a thin progress rule, and a
/// tinted session label. Leans entirely on Hudson design tokens.
struct MinimalFace: View {
    let model: TimerModel

    private var accent: Color { model.sessionType.accentColor }

    var body: some View {
        VStack(spacing: HudSpacing.lg) {
            // Session label — your intent once it's named, otherwise the session
            // type ("FOCUS"). The intent takes the label's place rather than
            // crowding in alongside it.
            HStack(spacing: HudSpacing.sm) {
                Text(model.intent.isEmpty ? model.sessionType.label : model.intent)
                    .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                    .tracking(model.intent.isEmpty ? 2 : 0.5)
                    .foregroundStyle(HudPalette.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if model.isPaused {
                    Text("· PAUSED")
                        .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(HudPalette.statusWarn)
                }
            }

            // Clock
            Text(model.clock)
                .font(HudFont.mono(54, weight: .medium))
                .foregroundStyle(HudPalette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: model.remainingSeconds)

            // Progress rule
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(HudPalette.ink.opacity(0.08))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(2, geo.size.width * model.progress))
                        .animation(.linear(duration: 0.2), value: model.progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 2)

            FaceControls(model: model, tint: accent)
                .padding(.top, HudSpacing.xs)
        }
        .padding(.horizontal, HudSpacing.huge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Clean dark backing so the face stays legible over a busy desktop —
        // every other watchface carries its own; minimal was the bare exception
        // and read as washed-out/see-through. The panel's blur + opacity still
        // soften it, keeping the frosted depth.
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.05)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
