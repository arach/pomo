import SwiftUI
import HudsonUI

/// Engineering-drawing face, styled after Hudson's landing page: cool slate
/// "paper", a 12/72 drafting grid, a tick ruler that doubles as the progress
/// scale, the countdown measured by a caliper dimension line, a corner title
/// block, and a footer plate. Hard corners, 1px ink, a single session-tinted
/// accent — honest and precise.
struct BlueprintFace: View {
    let model: TimerModel

    /// The drawing accent follows the session tint so the face still reads
    /// focus/break/long at a glance (focus green sits right by Hudson's emerald).
    private var accent: Color { model.sessionType.accentColor }

    // Slate engineering palette — cool blue-grey, distinct from the neutral HUD
    // chrome, matching the marketing site's `--paper`/`--ink`/`--line` tokens.
    private enum Slate {
        static let paper = Color(red: 0.102, green: 0.122, blue: 0.149)
        static let edge  = Color(red: 0.063, green: 0.078, blue: 0.098)
        static let ink   = Color(red: 0.910, green: 0.922, blue: 0.937)
        static let ink2  = Color(red: 0.604, green: 0.639, blue: 0.682)
        static let ink3  = Color(red: 0.420, green: 0.455, blue: 0.502)
        static let line  = Color(red: 0.227, green: 0.259, blue: 0.302)
        static let grid  = Color(red: 0.165, green: 0.192, blue: 0.227)
    }

    private var totalClock: String { TimeFormat.clock(model.totalSeconds) }
    private var percent: Int { Int((model.progress * 100).rounded()) }

    var body: some View {
        ZStack {
            // Paper: slate with a deep edge vignette so the sheet sinks into its
            // edges.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Slate.paper, location: 0.0),
                    .init(color: Slate.edge,  location: 0.68),
                    .init(color: Color(red: 0.035, green: 0.047, blue: 0.063), location: 1.0)
                ]),
                center: .center, startRadius: 18, endRadius: 248
            )

            // Static drafting substrate: grid, frame, registration marks.
            substrate

            // Main measured column.
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    slug
                    Spacer(minLength: HudSpacing.md)
                    titleBlock
                }
                Spacer(minLength: 0)
                clock
                Spacer().frame(height: HudSpacing.md)
                DimensionLine(label: "REMAINING", tint: accent, ink: Slate.ink2)
                Spacer(minLength: 0)
                footerPlate
                FaceControls(model: model, tint: accent, subtle: true)
                    .padding(.top, HudSpacing.md)
            }
            .padding(.horizontal, 20)
            .padding(.top, 34)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            progressRuler
                .frame(height: 24)
                .padding(.horizontal, 14)
                .padding(.top, 10)
        }
    }

    // MARK: - Substrate (grid + frame + registration crosshairs)

    private var substrate: some View {
        ZStack {
            // The drafting cross-lines fade out radially so the sheet reads
            // densest under the readout and dissolves toward the edges.
            gridLines
                .mask(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: 0.22),
                            .init(color: .clear, location: 0.88)
                        ]),
                        center: .center, startRadius: 4, endRadius: 200
                    )
                )
            // Frame + registration marks stay crisp — they're structure, not fill.
            frameAndMarks
        }
    }

    private var gridLines: some View {
        Canvas { ctx, size in
            func seg(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ w: CGFloat) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), lineWidth: w)
            }
            // Grid — minor every 12pt, major (heavier) every 72pt.
            let step: CGFloat = 12
            var i = 0
            var x: CGFloat = 0
            while x <= size.width {
                let major = i % 6 == 0
                seg(CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height),
                    major ? Slate.line.opacity(0.7) : Slate.grid.opacity(0.62), 1)
                x += step; i += 1
            }
            i = 0
            var y: CGFloat = 0
            while y <= size.height {
                let major = i % 6 == 0
                seg(CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y),
                    major ? Slate.line.opacity(0.7) : Slate.grid.opacity(0.62), 1)
                y += step; i += 1
            }
        }
    }

    private var frameAndMarks: some View {
        Canvas { ctx, size in
            func seg(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ w: CGFloat) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), lineWidth: w)
            }
            // Drawing frame.
            let inset: CGFloat = 9
            let frame = CGRect(x: inset, y: inset,
                               width: size.width - inset * 2, height: size.height - inset * 2)
            ctx.stroke(Path(frame), with: .color(Slate.ink3.opacity(0.8)), lineWidth: 1)

            // Registration crosshairs at the frame corners.
            let r: CGFloat = 5
            for corner in [CGPoint(x: frame.minX, y: frame.minY),
                           CGPoint(x: frame.maxX, y: frame.minY),
                           CGPoint(x: frame.minX, y: frame.maxY),
                           CGPoint(x: frame.maxX, y: frame.maxY)] {
                seg(CGPoint(x: corner.x - r, y: corner.y), CGPoint(x: corner.x + r, y: corner.y), Slate.ink3, 1)
                seg(CGPoint(x: corner.x, y: corner.y - r), CGPoint(x: corner.x, y: corner.y + r), Slate.ink3, 1)
            }
        }
    }

    // MARK: - Progress ruler (tick scale + caliper marker)

    private var progressRuler: some View {
        Canvas { ctx, size in
            func seg(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ w: CGFloat) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), lineWidth: w)
            }
            let baseY = size.height - 1
            let W = size.width

            // Baseline + tick scale (short every 12, tall every 72).
            seg(CGPoint(x: 0, y: baseY), CGPoint(x: W, y: baseY), Slate.line, 1)
            var i = 0
            var x: CGFloat = 0
            while x <= W {
                let h: CGFloat = (i % 6 == 0) ? 8 : 4
                seg(CGPoint(x: x, y: baseY), CGPoint(x: x, y: baseY - h), Slate.ink3, 1)
                x += 12; i += 1
            }

            // Elapsed fill + caliper marker.
            let px = max(0, min(W, W * model.progress))
            seg(CGPoint(x: 0, y: baseY), CGPoint(x: px, y: baseY), accent, 2)
            seg(CGPoint(x: px, y: baseY), CGPoint(x: px, y: baseY - 13), accent, 1)
            var tri = Path()
            tri.move(to: CGPoint(x: px, y: baseY - 12))
            tri.addLine(to: CGPoint(x: px - 4, y: baseY - 17))
            tri.addLine(to: CGPoint(x: px + 4, y: baseY - 17))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(accent))

            // Percent readout, clamped within the ruler.
            let label = ctx.resolve(
                Text("\(percent)%")
                    .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                    .foregroundStyle(accent)
            )
            let lx = max(12, min(W - 12, px))
            ctx.draw(label, at: CGPoint(x: lx, y: baseY - 21), anchor: .center)
        }
    }

    // MARK: - Hero clock

    private var clock: some View {
        Text(model.clock)
            .font(HudFont.mono(46, weight: .medium))
            .tracking(1)
            .monospacedDigit()
            .foregroundStyle(Slate.ink)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.2), value: model.remainingSeconds)
    }

    // MARK: - Corner stamps

    private var slug: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SHEET 01 / 01")
                .font(HudFont.mono(HudTextSize.micro))
                .tracking(2)
                .foregroundStyle(Slate.ink3)
            Text("POMO · TIMER")
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Slate.ink2)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 0) {
            titleCell("SESSION", model.sessionType.shortLabel.uppercased())
            Rectangle().fill(Slate.line).frame(height: 1)
            titleCell("T-SET", totalClock)
        }
        .frame(width: 96)
        .overlay(Rectangle().stroke(Slate.ink3, lineWidth: 1))
    }

    private func titleCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(HudFont.mono(HudTextSize.micro))
                .tracking(1.5)
                .foregroundStyle(Slate.ink3)
            Text(value)
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Slate.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
    }

    // MARK: - Footer plate

    private var footerPlate: some View {
        HStack(spacing: HudSpacing.md) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
                .opacity(model.isRunning ? 1 : 0.5)
            Text(statusText)
                .foregroundStyle(statusColor)
            Spacer(minLength: HudSpacing.sm)
            Text("Ø \(percent)%")
                .foregroundStyle(Slate.ink2)
            Rectangle().fill(Slate.line).frame(width: 1, height: 9)
            Text("\(model.totalSeconds / 60)′")
                .foregroundStyle(Slate.ink2)
        }
        .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
        .tracking(1.5)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(Rectangle().stroke(Slate.line, lineWidth: 1))
    }

    private var statusText: String {
        if model.isRunning { return "RUNNING" }
        return model.isPaused ? "HOLD" : "STANDBY"
    }

    private var statusColor: Color {
        if model.isRunning { return accent }
        return model.isPaused ? HudPalette.statusWarn : Slate.ink3
    }
}

// MARK: - Dimension line

/// A drafting dimension callout: extension ticks at each end, an arrowed rule
/// broken by a centred label — the caliper that "measures" the clock above it.
private struct DimensionLine: View {
    var label: String
    var tint: Color
    var ink: Color
    var width: CGFloat = 178

    var body: some View {
        Canvas { ctx, size in
            func seg(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ w: CGFloat) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), lineWidth: w)
            }
            let midY = size.height / 2
            let W = size.width
            let gap: CGFloat = 64
            let cx = W / 2
            let tick: CGFloat = 5

            // Extension ticks (tinted) + dimension rule with a centre gap.
            seg(CGPoint(x: 0, y: midY - tick), CGPoint(x: 0, y: midY + tick), tint, 1)
            seg(CGPoint(x: W, y: midY - tick), CGPoint(x: W, y: midY + tick), tint, 1)
            seg(CGPoint(x: 0, y: midY), CGPoint(x: cx - gap / 2, y: midY), ink, 1)
            seg(CGPoint(x: cx + gap / 2, y: midY), CGPoint(x: W, y: midY), ink, 1)

            // Arrowheads pointing outward to the extension lines.
            func arrow(at x: CGFloat, dir: CGFloat) {
                var a = Path()
                a.move(to: CGPoint(x: x, y: midY))
                a.addLine(to: CGPoint(x: x - dir * 6, y: midY - 3))
                a.addLine(to: CGPoint(x: x - dir * 6, y: midY + 3))
                a.closeSubpath()
                ctx.fill(a, with: .color(ink))
            }
            arrow(at: 0, dir: -1)
            arrow(at: W, dir: 1)

            // Centre label over the gap.
            let text = ctx.resolve(
                Text(label)
                    .font(HudFont.mono(HudTextSize.micro, weight: .semibold))
                    .foregroundStyle(ink)
            )
            ctx.draw(text, at: CGPoint(x: cx, y: midY), anchor: .center)
        }
        .frame(width: width, height: 14)
    }
}
