import SwiftUI
import HudsonUI

/// Analog chronograph face: a ticked dial with a colored progress arc, a sweep
/// hand tracking elapsed progress, and a small digital readout.
///
/// The view is split into small sub-views so the SwiftUI type-checker doesn't
/// have to solve one large `body` expression (which times out on CI).
struct ChronographFace: View {
    let model: TimerModel

    private let dial: CGFloat = 170
    private var accent: Color { model.sessionType.tint.color }

    var body: some View {
        ZStack {
            bezel
            ticks
            progressArc
            sweepHand
            hub
            labels
        }
        .frame(width: dial, height: dial)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { controls }
        .background(dialBackground)
    }

    private var bezel: some View {
        Circle().stroke(Color.white.opacity(0.14), lineWidth: 2)
    }

    private var ticks: some View {
        Canvas { ctx, size in
            for mark in Self.tickMarks(in: size) {
                var path = Path()
                path.move(to: mark.start)
                path.addLine(to: mark.end)
                ctx.stroke(
                    path,
                    with: .color(.white.opacity(mark.major ? 0.55 : 0.22)),
                    lineWidth: mark.major ? 2 : 1
                )
            }
        }
        .padding(6)
    }

    /// Tick-mark geometry computed in a plain function — keeps the heavy
    /// trig out of the SwiftUI result-builder, which otherwise times out.
    private static func tickMarks(in size: CGSize) -> [(start: CGPoint, end: CGPoint, major: Bool)] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer: CGFloat = min(size.width, size.height) / 2 - 4
        var marks: [(start: CGPoint, end: CGPoint, major: Bool)] = []
        for i in 0..<60 {
            let major = i % 5 == 0
            let angle: CGFloat = CGFloat(i) / 60 * 2 * .pi - .pi / 2
            let inner: CGFloat = outer - (major ? 10 : 5)
            let start = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
            let end = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
            marks.append((start, end, major))
        }
        return marks
    }

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: max(0.0001, model.progress))
            .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(14)
            .shadow(color: accent.opacity(0.6), radius: 5)
            .animation(.linear(duration: 0.2), value: model.progress)
    }

    private var sweepHand: some View {
        Capsule()
            .fill(accent)
            .frame(width: 3, height: dial * 0.40)
            .offset(y: -dial * 0.20)
            .rotationEffect(.degrees(model.progress * 360))
            .animation(.linear(duration: 0.2), value: model.progress)
    }

    private var hub: some View {
        ZStack {
            Circle().fill(accent).frame(width: 9, height: 9)
            Circle().fill(Color.black).frame(width: 3, height: 3)
        }
    }

    private var labels: some View {
        ZStack {
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
    }

    private var controls: some View {
        FaceControls(model: model, tint: accent)
            .padding(.bottom, HudSpacing.xs)
    }

    private var dialBackground: some View {
        RadialGradient(
            colors: [Color(white: 0.12), Color.black.opacity(0.85)],
            center: .center, startRadius: 4, endRadius: dial
        )
    }
}
