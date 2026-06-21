import SwiftUI
import HudsonUI

/// Retro terminal face: green monospace on near-black, a prompt line, an ASCII
/// progress bar, and a blinking block cursor.
struct TerminalFace: View {
    let model: TimerModel

    private let green = Color(red: 0.35, green: 1.0, blue: 0.55)
    private let dimGreen = Color(red: 0.35, green: 1.0, blue: 0.55).opacity(0.5)
    private let cells = 18

    @State private var cursorOn = true

    private var asciiBar: String {
        let filled = Int((Double(cells) * model.progress).rounded(.down))
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: cells - filled)
        return bar
    }

    private var percent: Int { Int((model.progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            // Header / title bar
            HStack(spacing: HudSpacing.sm) {
                Text("pomo")
                    .foregroundStyle(green)
                Text("~/\(model.sessionType.rawValue)")
                    .foregroundStyle(dimGreen)
                Spacer()
                Text(model.isRunning ? "RUN" : (model.isPaused ? "PAUSE" : "IDLE"))
                    .foregroundStyle(model.isRunning ? green : dimGreen)
            }
            .font(HudFont.mono(HudTextSize.xs, weight: .semibold))

            Rectangle().fill(green.opacity(0.18)).frame(height: 1)

            // Prompt + clock
            HStack(spacing: HudSpacing.sm) {
                Text(">")
                    .foregroundStyle(dimGreen)
                Text(model.sessionType.label.lowercased())
                    .foregroundStyle(dimGreen)
                Text(model.clock)
                    .foregroundStyle(green)
                    .monospacedDigit()
                Rectangle()
                    .fill(green)
                    .frame(width: 9, height: 18)
                    .opacity(cursorOn ? 1 : 0)
            }
            .font(HudFont.mono(22, weight: .semibold))

            // ASCII progress
            HStack(spacing: HudSpacing.sm) {
                Text("[\(asciiBar)]")
                    .foregroundStyle(green)
                    .font(HudFont.mono(13, weight: .regular))
                Text("\(percent)%")
                    .foregroundStyle(dimGreen)
                    .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
            }

            FaceControls(model: model, tint: green, subtle: true)
                .padding(.top, HudSpacing.xs)
        }
        .padding(.horizontal, HudSpacing.xxl)
        .padding(.vertical, HudSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            // Near-black panel + faint scanlines for CRT vibe.
            ZStack {
                Color.black.opacity(0.55)
                Scanlines().foregroundStyle(.black.opacity(0.18))
            }
        )
        .onAppear { startCursor() }
    }

    private func startCursor() {
        Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
            Task { @MainActor in cursorOn.toggle() }
        }
    }
}

/// Horizontal scanline overlay.
private struct Scanlines: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(.black.opacity(0.35)))
                    y += 3
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}
