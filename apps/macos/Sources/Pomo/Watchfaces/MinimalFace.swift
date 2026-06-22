import SwiftUI
import HudsonUI

/// Clean, Hudson-native face: big monospaced clock, a thin progress rule, and a
/// tinted session label. Leans entirely on Hudson design tokens.
struct MinimalFace: View {
    let model: TimerModel

    private var accent: Color { model.sessionType.accentColor }

    var body: some View {
        VStack(spacing: HudSpacing.lg) {
            // Session label
            HStack(spacing: HudSpacing.sm) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .opacity(model.isRunning ? 1 : 0.4)
                Text(model.sessionType.label)
                    .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(HudPalette.muted)
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
    }
}
