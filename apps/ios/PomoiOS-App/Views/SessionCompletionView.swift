import SwiftUI

struct SessionCompletionView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var statsManager: StatsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("dailyGoal") private var dailyGoal = 8
    @AppStorage("encouragementEnabled") private var encouragementEnabled = true

    let outcome: SessionOutcome

    @State private var ringTrim = 0.015
    @State private var cadenceFilled = 0
    @State private var detailsVisible = false
    @State private var actionsVisible = false
    @State private var resolvedNote: String?
    @AccessibilityFocusState private var completionFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(proxy.safeAreaInsets.top + 24, 44))

                    completionCard(availableWidth: proxy.size.width - 40)
                        .accessibilityFocused($completionFocused)

                    if outcome.mode == .deepFocus {
                        cadence
                            .padding(.top, 22)
                    }

                    ledger
                        .padding(.top, outcome.mode == .deepFocus ? 18 : 22)

                    if let resolvedNote {
                        VStack(spacing: 10) {
                            Capsule()
                                .fill(PomoPalette.accent)
                                .frame(width: 14, height: 2)
                            Text(resolvedNote)
                                .font(.system(.callout, design: .rounded, weight: .regular))
                                .foregroundStyle(PomoPalette.ink.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        .padding(.top, 20)
                        .opacity(detailsVisible ? 1 : 0)
                    }

                    Color.clear
                        .frame(height: 28)

                    actions
                        .opacity(actionsVisible ? 1 : 0)
                        .allowsHitTesting(actionsVisible)
                        .accessibilityHidden(!actionsVisible)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                }
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, 20)
            }
            .id(outcome.id)
            .scrollBounceBehavior(.basedOnSize)
            .background(
                PomoPalette.background
                    .opacity(reduceTransparency ? 0.98 : 0.94)
                    .ignoresSafeArea()
            )
        }
        .preferredColorScheme(.dark)
        .task(id: outcome.id) {
            await performRitual()
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func completionCard(availableWidth: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                Capsule()
                    .fill(outcome.mode.color)
                    .frame(height: 4)
                CompletionReceiptText(outcome: outcome, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        } else {
            CompletionDial(
                outcome: outcome,
                trim: reduceMotion ? 1 : ringTrim,
                differentiateWithoutColor: differentiateWithoutColor
            )
            .frame(width: availableWidth, height: min(availableWidth / 1.06, 330))
            .background(cardBackground)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(PomoPalette.elevated)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        differentiateWithoutColor ? PomoPalette.ink.opacity(0.28) : PomoPalette.border,
                        lineWidth: 1
                    )
            }
    }

    private var cadence: some View {
        VStack(spacing: 12) {
            cadenceHeader
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < (reduceMotion ? outcome.cadenceFilled : cadenceFilled) ? PomoPalette.accent : PomoPalette.surfaceStrong)
                        .overlay {
                            if differentiateWithoutColor && index < (reduceMotion ? outcome.cadenceFilled : cadenceFilled) {
                                Capsule().stroke(PomoPalette.ink.opacity(0.65), lineWidth: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 5)
                }
            }
        }
        .opacity(detailsVisible || reduceMotion ? 1 : 0)
    }

    @ViewBuilder
    private var cadenceHeader: some View {
        let detail = outcome.closedCadenceSet ? "long break ready" : "long break after 4 focus blocks"
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text("CADENCE")
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .foregroundStyle(PomoPalette.ink)
                Text(detail)
                    .font(.system(.callout, design: .monospaced, weight: .regular))
                    .foregroundStyle(PomoPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            PomoSectionLabel(title: "Cadence", trailing: detail)
        }
    }

    @ViewBuilder
    private var ledger: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(statsManager.todaySessions) of \(dailyGoal) today")
                        .foregroundStyle(statsManager.todaySessions >= dailyGoal ? PomoPalette.green : PomoPalette.ink)
                    Text("\(formatFocusTime(statsManager.todayFocusTime)) focused")
                        .foregroundStyle(PomoPalette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 0) {
                    Text("\(statsManager.todaySessions) of \(dailyGoal) today")
                        .foregroundStyle(statsManager.todaySessions >= dailyGoal ? PomoPalette.green : PomoPalette.ink)
                    Text(" · \(formatFocusTime(statsManager.todayFocusTime)) focused")
                        .foregroundStyle(PomoPalette.muted)
                }
            }
        }
        .font(.system(.caption, design: .monospaced, weight: .medium))
        .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(detailsVisible || reduceMotion ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statsManager.todaySessions) of \(dailyGoal) focus blocks today, \(formatFocusTime(statsManager.todayFocusTime)) focused")
    }

    private var actions: some View {
        VStack(spacing: 4) {
            Button {
                timerManager.dismissOutcome(startNext: true)
            } label: {
                Text(primaryActionTitle)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(PomoPalette.background)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PomoPalette.accent)
                    )
            }
            .buttonStyle(.plain)

            Button("Not yet") {
                timerManager.dismissOutcome(startNext: false)
            }
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(PomoPalette.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .buttonStyle(.plain)
        }
    }

    private var primaryActionTitle: String {
        if outcome.autoStartedNext {
            return outcome.nextMode == .deepFocus ? "Open focus timer" : "Open break timer"
        }
        return "Start \(actionDuration(outcome.nextDuration)) \(outcome.nextMode == .deepFocus ? "focus" : "break")"
    }

    private func resolveNote() -> String? {
        guard encouragementEnabled else { return nil }
        guard outcome.mode == .deepFocus else {
            return outcome.mode == .longBreak ? "Set complete. A new four starts when you do." : nil
        }
        if outcome.closedCadenceSet {
            return "Four blocks complete. The long break is part of the work."
        }
        if statsManager.todaySessions == dailyGoal {
            return "That is your goal for today."
        }
        return nil
    }

    @MainActor
    private func performRitual() async {
        resolvedNote = resolveNote()

        if reduceMotion {
            ringTrim = 1
            cadenceFilled = outcome.cadenceFilled
            detailsVisible = true
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            actionsVisible = true
            completionFocused = true
            return
        }

        withAnimation(.easeOut(duration: 0.46)) {
            ringTrim = 1
        }
        try? await Task.sleep(for: .milliseconds(420))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.30)) {
            cadenceFilled = outcome.cadenceFilled
            detailsVisible = true
        }
        try? await Task.sleep(for: .milliseconds(420))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.20)) {
            actionsVisible = true
        }
        completionFocused = true
    }

    private func actionDuration(_ duration: TimeInterval) -> String {
        let seconds = max(Int(duration.rounded()), 1)
        if seconds.isMultiple(of: 60) {
            let minutes = seconds / 60
            return "\(minutes)-minute"
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func formatFocusTime(_ duration: TimeInterval) -> String {
        let minutes = max(Int(duration) / 60, 0)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

private struct CompletionDial: View {
    let outcome: SessionOutcome
    let trim: Double
    let differentiateWithoutColor: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.39

            ZStack {
                Canvas { context, _ in
                    for index in 0..<60 {
                        let angle = Double(index) / 60 * .pi * 2 - .pi / 2
                        let major = index % 5 == 0
                        let outer = CGPoint(
                            x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius
                        )
                        let innerRadius = radius - (major ? 14 : 7)
                        let inner = CGPoint(
                            x: center.x + cos(angle) * innerRadius,
                            y: center.y + sin(angle) * innerRadius
                        )
                        var path = Path()
                        path.move(to: inner)
                        path.addLine(to: outer)
                        context.stroke(
                            path,
                            with: .color(index == 0 ? outcome.mode.color : PomoPalette.ink.opacity(major ? 0.38 : 0.12)),
                            lineWidth: index == 0 ? 2.5 : (major ? 1.8 : 1)
                        )
                    }
                }

                Circle()
                    .trim(from: 0, to: trim)
                    .stroke(outcome.mode.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.67, height: size * 0.67)
                    .shadow(color: outcome.mode.color.opacity(0.16), radius: 6, y: 2)
                    .overlay {
                        if differentiateWithoutColor {
                            Circle()
                                .stroke(PomoPalette.ink.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        }
                    }

                Circle()
                    .fill(PomoPalette.elevated)
                    .frame(width: size * 0.47, height: size * 0.47)

                CompletionReceiptText(outcome: outcome, alignment: .center)
                    .frame(maxWidth: size * 0.62)
            }
        }
        .padding(14)
        .accessibilityHidden(true)
    }
}

private struct CompletionReceiptText: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let outcome: SessionOutcome
    let alignment: TextAlignment

    var body: some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 10) {
            Text(outcome.mode == .deepFocus ? "FOCUS COMPLETE" : "BREAK COMPLETE")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(PomoPalette.muted)

            Text(formatDuration(outcome.duration))
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 40 : 46, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(PomoPalette.ink)
                .minimumScaleFactor(0.72)

            if let intent = outcome.intent {
                Text(intent)
                    .font(.system(.caption, design: .monospaced, weight: .regular))
                    .foregroundStyle(PomoPalette.muted)
                    .multilineTextAlignment(alignment)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(completionAccessibilityLabel)
    }

    private var completionAccessibilityLabel: String {
        let phase = outcome.mode == .deepFocus ? "Focus complete" : "Break complete"
        let intent = outcome.intent.map { ", \($0)" } ?? ""
        return "\(phase), \(formatDuration(outcome.duration))\(intent)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(Int(duration.rounded()), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
