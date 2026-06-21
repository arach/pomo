import SwiftUI
import HudsonUI

/// Cyberpunk face: a glowing circular progress ring with a magenta→cyan
/// gradient and a neon-lit clock at the centre.
struct NeonFace: View {
    let model: TimerModel

    private let magenta = Color(red: 1.0, green: 0.18, blue: 0.85)
    private let cyan = Color(red: 0.25, green: 0.95, blue: 1.0)

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [magenta, cyan, magenta],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 8)

            // Glow underlay
            Circle()
                .trim(from: 0, to: max(0.0001, model.progress))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 9)
                .opacity(0.9)

            // Crisp ring
            Circle()
                .trim(from: 0, to: max(0.0001, model.progress))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: model.progress)

            // Centre stack
            VStack(spacing: HudSpacing.sm) {
                Text(model.sessionType.label)
                    .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(cyan)
                    .shadow(color: cyan.opacity(0.8), radius: 6)

                Text(model.clock)
                    .font(HudFont.mono(36, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: magenta.opacity(0.9), radius: 10)
                    .shadow(color: magenta.opacity(0.5), radius: 20)

                Text(model.isRunning ? "● LIVE" : (model.isPaused ? "❚❚ PAUSED" : "○ READY"))
                    .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(model.isRunning ? magenta : Color.white.opacity(0.5))
            }
        }
        .padding(HudSpacing.xxl)
        .overlay(alignment: .bottom) {
            FaceControls(model: model, tint: cyan)
                .padding(.bottom, HudSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.02, blue: 0.08).opacity(0.55))
    }
}
