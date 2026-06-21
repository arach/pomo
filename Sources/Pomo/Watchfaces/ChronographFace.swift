import SwiftUI
import HudsonUI

/// Analog chronograph face: a ticked dial with a colored progress arc, a sweep
/// hand tracking elapsed progress, and a small digital readout.
struct ChronographFace: View {
    let model: TimerModel

    private let dial: CGFloat = 170
    private var accent: Color { model.sessionType.tint.color }

    var body: some View {
        ZStack {
            // Bezel
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 2)

            // Tick marks
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let outer = min(size.width, size.height) / 2 - 4
                for i in 0..<60 {
                    let major = i % 5 == 0
                    let angle = Double(i) / 60.0 * 2 * .pi - .pi / 2
                    let inner = outer - (major ? 10 : 5)
                    let p1 = CGPoint(x: c.x + cos(angle) * inner, y: c.y + sin(angle) * inner)
                    let p2 = CGPoint(x: c.x + cos(angle) * outer, y: c.y + sin(angle) * outer)
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(major ? 0.55 : 0.22)),
                        lineWidth: major ? 2 : 1
                    )
                }
            }
            .padding(6)

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0.0001, model.progress))
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(14)
                .shadow(color: accent.opacity(0.6), radius: 5)
                .animation(.linear(duration: 0.2), value: model.progress)

            // Sweep hand
            Capsule()
                .fill(accent)
                .frame(width: 3, height: dial * 0.40)
                .offset(y: -dial * 0.20)
                .rotationEffect(.degrees(model.progress * 360))
                .animation(.linear(duration: 0.2), value: model.progress)

            // Hub
            Circle().fill(accent).frame(width: 9, height: 9)
            Circle().fill(Color.black).frame(width: 3, height: 3)

            // Session label (upper) + digital readout (lower)
            Text(model.sessionType.label)
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .tracking(2)
                .foregroundStyle(HudPalette.muted)
                .offset(y: -dial * 0.22)

            Text(model.clock)
                .font(HudFont.mono(HudTextSize.lg, weight: .semibold))
                .foregroundStyle(HudPalette.ink)
                .monospacedDigit()
                .offset(y: dial * 0.24)
        }
        .frame(width: dial, height: dial)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            FaceControls(model: model, tint: accent)
                .padding(.bottom, HudSpacing.xs)
        }
        .background(
            RadialGradient(
                colors: [Color(white: 0.12), Color.black.opacity(0.85)],
                center: .center, startRadius: 4, endRadius: dial
            )
        )
    }
}
