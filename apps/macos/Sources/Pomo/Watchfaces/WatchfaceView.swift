import SwiftUI
import HudsonUI

/// Routes the selected `Watchface` to its SwiftUI implementation. All faces are
/// driven by the same `TimerModel` and share the fixed HUD content size.
struct WatchfaceView: View {
    let face: Watchface
    let model: TimerModel

    var body: some View {
        switch face {
        case .minimal:      MinimalFace(model: model)
        case .terminal:     TerminalFace(model: model)
        case .neon:         NeonFace(model: model)
        case .retroDigital: RetroDigitalFace(model: model)
        case .rolodex:      RolodexFace(model: model)
        case .chronograph:  ChronographFace(model: model)
        case .blueprint:    BlueprintFace(model: model)
        }
    }
}

/// Compact transport controls reused across faces. The look adapts to each
/// face's accent colour while sharing layout + behaviour.
struct FaceControls: View {
    let model: TimerModel
    var tint: Color
    var subtle: Bool = false

    var body: some View {
        HStack(spacing: HudSpacing.xl) {
            Button(action: { model.reset() }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(FaceControlStyle(tint: tint, prominent: false, subtle: subtle))
            .help("Reset (R)")

            Button(action: { model.toggle() }) {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(FaceControlStyle(tint: tint, prominent: true, subtle: subtle))
            .help(model.isRunning ? "Pause (Space)" : "Start (Space)")

            Button(action: { model.skip() }) {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(FaceControlStyle(tint: tint, prominent: false, subtle: subtle))
            .help("Skip to next session (N)")
        }
    }
}

/// Circular icon button with a face-tinted treatment.
private struct FaceControlStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool
    var subtle: Bool

    func makeBody(configuration: Configuration) -> some View {
        let diameter: CGFloat = prominent ? 34 : 28
        return configuration.label
            .font(.system(size: prominent ? 13 : 11, weight: .semibold))
            .foregroundStyle(prominent ? tint : tint.opacity(0.85))
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(tint.opacity(prominent ? 0.16 : 0.0))
                    .overlay(Circle().stroke(tint.opacity(subtle ? 0.25 : 0.4), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Circle())
    }
}
