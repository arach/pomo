import SwiftUI
import HudsonUI

/// Flip-clock face: digits sit in dark cards with a center seam and roll over
/// when they change, like an old split-flap display.
struct RolodexFace: View {
    let model: TimerModel

    private var digits: [Int] {
        let s = max(0, model.remainingSeconds)
        let m = min(99, s / 60)
        let sec = s % 60
        return [m / 10, m % 10, sec / 10, sec % 10]
    }

    private var accent: Color { model.sessionType.tint.color }

    var body: some View {
        VStack(spacing: HudSpacing.lg) {
            HStack(spacing: HudSpacing.sm) {
                Circle().fill(accent).frame(width: 6, height: 6)
                    .opacity(model.isRunning ? 1 : 0.4)
                Text(model.sessionType.label)
                    .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(HudPalette.muted)
                if model.isPaused {
                    Text("· PAUSED")
                        .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                        .foregroundStyle(HudPalette.statusWarn)
                }
            }

            HStack(spacing: 5) {
                FlipDigit(value: digits[0])
                FlipDigit(value: digits[1])
                FlipColon()
                FlipDigit(value: digits[2])
                FlipDigit(value: digits[3])
            }

            FaceControls(model: model, tint: accent)
                .padding(.top, HudSpacing.xs)
        }
        .padding(.horizontal, HudSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.12), Color.black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

/// A single flip card. The digit rolls in from the top when it changes.
private struct FlipDigit: View {
    let value: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            Text("\(value)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .id(value)
                .transition(.push(from: .top).combined(with: .opacity))
        }
        .frame(width: 48, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            // Center seam.
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: value)
    }
}

private struct FlipColon: View {
    var body: some View {
        VStack(spacing: 12) {
            Circle().fill(Color.white.opacity(0.85)).frame(width: 7, height: 7)
            Circle().fill(Color.white.opacity(0.85)).frame(width: 7, height: 7)
        }
        .frame(width: 10)
    }
}
