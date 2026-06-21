import SwiftUI
import HudsonUI

/// Classic 7-segment LCD face: amber digits with a glow, "off" segments faintly
/// lit like a real display, on a dark panel.
struct RetroDigitalFace: View {
    let model: TimerModel

    private let amber = Color(red: 1.0, green: 0.78, blue: 0.18)
    private var off: Color { amber.opacity(0.10) }

    private var digits: [Int] {
        let s = max(0, model.remainingSeconds)
        let m = min(99, s / 60)
        let sec = s % 60
        return [m / 10, m % 10, sec / 10, sec % 10]
    }

    var body: some View {
        VStack(spacing: HudSpacing.md) {
            HStack(spacing: HudSpacing.xs) {
                Text(model.sessionType.label)
                    .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(amber.opacity(0.7))
                Spacer()
                Text(model.isRunning ? "RUN" : (model.isPaused ? "HOLD" : "SET"))
                    .font(HudFont.mono(HudTextSize.xxs, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(amber.opacity(0.5))
            }
            .padding(.horizontal, HudSpacing.xs)

            HStack(spacing: 7) {
                SevenSegmentDigit(value: digits[0], on: amber, off: off)
                SevenSegmentDigit(value: digits[1], on: amber, off: off)
                SegmentColon(color: amber)
                SevenSegmentDigit(value: digits[2], on: amber, off: off)
                SevenSegmentDigit(value: digits[3], on: amber, off: off)
            }
            .frame(height: 64)
            .shadow(color: amber.opacity(0.55), radius: 7)

            FaceControls(model: model, tint: amber, subtle: true)
                .padding(.top, HudSpacing.xs)
        }
        .padding(.horizontal, HudSpacing.xxl)
        .padding(.vertical, HudSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.06, blue: 0.03), Color.black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

/// One 7-segment digit. Segments a–g lit per the value; unlit segments render in
/// the faint `off` colour for that authentic LCD look.
struct SevenSegmentDigit: View {
    let value: Int
    let on: Color
    let off: Color

    // Which segments (a–g) are lit for each digit.
    private static let map: [Int: Set<Character>] = [
        0: ["a", "b", "c", "d", "e", "f"],
        1: ["b", "c"],
        2: ["a", "b", "g", "e", "d"],
        3: ["a", "b", "g", "c", "d"],
        4: ["f", "g", "b", "c"],
        5: ["a", "f", "g", "c", "d"],
        6: ["a", "f", "g", "e", "c", "d"],
        7: ["a", "b", "c"],
        8: ["a", "b", "c", "d", "e", "f", "g"],
        9: ["a", "b", "c", "d", "f", "g"],
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let t = min(w, h) * 0.16        // segment thickness
            let lit = Self.map[value] ?? []

            ZStack {
                // Horizontals
                horizontal(on: lit.contains("a"), w: w, t: t).position(x: w / 2, y: t / 2 + 1)
                horizontal(on: lit.contains("g"), w: w, t: t).position(x: w / 2, y: h / 2)
                horizontal(on: lit.contains("d"), w: w, t: t).position(x: w / 2, y: h - t / 2 - 1)
                // Verticals (top row)
                vertical(on: lit.contains("f"), h: h, t: t).position(x: t / 2 + 1, y: h * 0.25 + t / 2)
                vertical(on: lit.contains("b"), h: h, t: t).position(x: w - t / 2 - 1, y: h * 0.25 + t / 2)
                // Verticals (bottom row)
                vertical(on: lit.contains("e"), h: h, t: t).position(x: t / 2 + 1, y: h * 0.75 - t / 2)
                vertical(on: lit.contains("c"), h: h, t: t).position(x: w - t / 2 - 1, y: h * 0.75 - t / 2)
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
    }

    private func horizontal(on: Bool, w: CGFloat, t: CGFloat) -> some View {
        Capsule()
            .fill(on ? on_color : off)
            .frame(width: w - t * 1.6, height: t)
    }

    private func vertical(on: Bool, h: CGFloat, t: CGFloat) -> some View {
        Capsule()
            .fill(on ? on_color : off)
            .frame(width: t, height: h / 2 - t * 1.4)
    }

    private var on_color: Color { on }
}

/// The blinking ":" between minutes and seconds, built from two dots.
private struct SegmentColon: View {
    let color: Color
    var body: some View {
        VStack(spacing: 10) {
            Circle().fill(color).frame(width: 6, height: 6)
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .shadow(color: color.opacity(0.6), radius: 4)
        .frame(width: 8)
    }
}
