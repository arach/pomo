import SwiftUI

struct PomoWatchRootView: View {
    @EnvironmentObject private var companion: WatchCompanionController

    var body: some View {
        if let state = companion.state {
            CompanionTimerView(state: state)
        } else if companion.hasCompanionApp {
            WatchConnectingView()
        } else {
            ContentView()
        }
    }
}

private struct WatchConnectingView: View {
    @EnvironmentObject private var companion: WatchCompanionController

    var body: some View {
        ZStack {
            PomoWatchPalette.background.ignoresSafeArea()
            VStack(spacing: 10) {
                Circle()
                    .stroke(PomoWatchPalette.surface, lineWidth: 3)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "iphone")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(PomoWatchPalette.accent)
                    }
                Text("CONNECTING TO IPHONE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(PomoWatchPalette.muted)
                Button("Try again") {
                    companion.refresh()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minHeight: 44)
                .buttonStyle(.bordered)
                .tint(PomoWatchPalette.surface)
            }
            .padding(.horizontal, 12)
        }
        .containerBackground(PomoWatchPalette.background.gradient, for: .navigation)
    }
}

private struct CompanionTimerView: View {
    @EnvironmentObject private var companion: WatchCompanionController
    let state: SharedSessionState

    var body: some View {
        ZStack {
            PomoWatchPalette.background.ignoresSafeArea()

            if let outcome = state.outcome {
                WatchCompletionReceipt(outcome: outcome)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    timerContent(at: timeline.date)
                }
            }
        }
        .containerBackground(PomoWatchPalette.background.gradient, for: .navigation)
    }

    private func timerContent(at date: Date) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(state.mode.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(modeColor)
                Spacer()
            }

            ZStack {
                Circle()
                    .stroke(PomoWatchPalette.surface, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress(at: date))
                    .stroke(modeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(formattedRemaining(at: date))
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PomoWatchPalette.ink)
                        .minimumScaleFactor(0.72)
                    Text(state.isRunning ? "IN SESSION" : "READY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(PomoWatchPalette.muted)
                }
            }
            .frame(width: 132, height: 132)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(state.mode), \(formattedRemaining(at: date)) remaining")

            if !state.intent.isEmpty {
                Text(state.intent)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PomoWatchPalette.muted)
                    .lineLimit(1)
            }

            if !companion.isPhoneReachable {
                Text("OPEN POMO ON IPHONE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(PomoWatchPalette.dim)
            }

            HStack(spacing: 10) {
                watchButton("arrow.counterclockwise", label: "Reset") {
                    companion.send(.reset)
                }
                watchButton(state.isRunning ? "pause.fill" : "play.fill", label: state.isRunning ? "Pause" : "Start", primary: true) {
                    companion.send(state.isRunning ? .pause : .start)
                }
                watchButton("forward.end.fill", label: "Skip") {
                    companion.send(.skip)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func watchButton(
        _ systemName: String,
        label: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: primary ? 15 : 12, weight: .semibold))
                .foregroundStyle(primary ? PomoWatchPalette.background : PomoWatchPalette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(primary ? PomoWatchPalette.accent : PomoWatchPalette.surface))
        }
        .buttonStyle(.plain)
        .disabled(!companion.isPhoneReachable)
        .opacity(companion.isPhoneReachable ? 1 : 0.45)
        .accessibilityLabel(label)
    }

    private var modeColor: Color {
        switch state.mode {
        case "Short Break": PomoWatchPalette.green
        case "Long Break": PomoWatchPalette.blue
        case "Planning": PomoWatchPalette.orange
        default: PomoWatchPalette.accent
        }
    }

    private func remaining(at date: Date) -> TimeInterval {
        if state.isRunning, let endDate = state.endDate {
            return max(endDate.timeIntervalSince(date), 0)
        }
        return max(state.remaining, 0)
    }

    private func progress(at date: Date) -> Double {
        guard state.duration > 0 else { return 0 }
        return min(max((state.duration - remaining(at: date)) / state.duration, 0), 1)
    }

    private func formattedRemaining(at date: Date) -> String {
        let seconds = max(Int(remaining(at: date).rounded(.up)), 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WatchCompletionReceipt: View {
    @EnvironmentObject private var companion: WatchCompanionController
    let outcome: SharedSessionOutcome

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(modeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PomoWatchPalette.ink)
                    }

                Text(outcome.mode == "Focus" ? "FOCUS COMPLETE" : "BREAK COMPLETE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(PomoWatchPalette.muted)

                Text(formatDuration(outcome.duration))
                    .font(.system(size: 25, weight: .medium, design: .monospaced))
                    .foregroundStyle(PomoWatchPalette.ink)

                if let intent = outcome.intent {
                    Text(intent)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PomoWatchPalette.muted)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }

                if outcome.mode == "Focus" {
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(index < outcome.cadenceFilled ? PomoWatchPalette.accent : PomoWatchPalette.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 4)
                        }
                    }
                }

                Button {
                    companion.send(.continueNext)
                } label: {
                    Text(outcome.autoStartedNext ? "Open timer" : actionTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PomoWatchPalette.background)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(PomoWatchPalette.accent))
                }
                .buttonStyle(.plain)
                .disabled(!companion.isPhoneReachable)

                Button("Not yet") {
                    companion.send(.dismissOutcome)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PomoWatchPalette.muted)
                .frame(minHeight: 36)
                .buttonStyle(.plain)
                .disabled(!companion.isPhoneReachable)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var modeColor: Color {
        outcome.mode == "Focus" ? PomoWatchPalette.accent : PomoWatchPalette.green
    }

    private var actionTitle: String {
        let kind = outcome.nextMode == "Focus" ? "focus" : "break"
        let seconds = max(Int(outcome.nextDuration.rounded()), 0)
        if seconds < 60 {
            return "Start \(seconds)s \(kind)"
        }
        return "Start \(seconds / 60)m \(kind)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(Int(duration.rounded()), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private enum PomoWatchPalette {
    static let background = Color(red: 0.090, green: 0.071, blue: 0.059)
    static let surface = Color(red: 0.188, green: 0.149, blue: 0.118)
    static let ink = Color(red: 0.957, green: 0.933, blue: 0.902)
    static let muted = Color(red: 0.737, green: 0.682, blue: 0.620)
    static let dim = Color(red: 0.588, green: 0.537, blue: 0.490)
    static let accent = Color(red: 0.918, green: 0.894, blue: 0.204)
    static let green = Color(red: 0.369, green: 0.839, blue: 0.604)
    static let blue = Color(red: 0.439, green: 0.718, blue: 1)
    static let orange = Color(red: 0.949, green: 0.651, blue: 0.353)
}
