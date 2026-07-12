import ActivityKit
import SwiftUI
import WidgetKit

struct PomoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomoActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(PomoLivePalette.background)
                .activitySystemActionForegroundColor(context.attributes.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Pomo", systemImage: "timer")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(context.attributes.accent)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    PomoRemainingTime(state: context.state, size: 24)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.modeName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(context.attributes.accent)
                        if !context.attributes.intent.isEmpty {
                            Text(context.attributes.intent)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(PomoLivePalette.muted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.accent)
            } compactTrailing: {
                PomoRemainingTime(state: context.state, size: 13)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.accent)
            }
            .keylineTint(context.attributes.accent)
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<PomoActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(context.attributes.accent.opacity(0.12))
                Circle()
                    .stroke(context.attributes.accent.opacity(0.34), lineWidth: 1)
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(context.attributes.accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.modeName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(context.attributes.accent)
                Text(context.attributes.intent.isEmpty ? "Pomo" : context.attributes.intent)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PomoLivePalette.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 3) {
                PomoRemainingTime(state: context.state, size: 28)
                Text(context.state.isPaused ? "PAUSED" : "REMAINING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(PomoLivePalette.dim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.attributes.modeName), Pomo timer")
    }
}

private struct PomoRemainingTime: View {
    let state: PomoActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.isPaused {
                Text(Self.formatted(state.remainingSeconds))
            } else {
                Text(timerInterval: Date()...state.endDate, countsDown: true)
            }
        }
        .font(.system(size: size, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(PomoLivePalette.ink)
    }

    private static func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }
}

private enum PomoLivePalette {
    static let background = Color(red: 23 / 255, green: 18 / 255, blue: 15 / 255)
    static let ink = Color(red: 244 / 255, green: 238 / 255, blue: 230 / 255)
    static let muted = Color(red: 188 / 255, green: 174 / 255, blue: 158 / 255)
    static let dim = Color(red: 125 / 255, green: 113 / 255, blue: 101 / 255)
}

private extension PomoActivityAttributes {
    var accent: Color {
        Color(
            red: Double((accentHex >> 16) & 0xff) / 255,
            green: Double((accentHex >> 8) & 0xff) / 255,
            blue: Double(accentHex & 0xff) / 255
        )
    }
}
