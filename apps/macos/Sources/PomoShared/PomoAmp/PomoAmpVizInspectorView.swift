import Foundation
import SwiftUI

struct PomoAmpVizInspectorView: View {
    let viz: PomoAmpVizData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sourceStatus
            metrics
            bandSection(title: "BANDS", values: viz.bands, positiveOnly: true)
            bandSection(title: "WAVE", values: viz.waveform, positiveOnly: false)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.065), Color(red: 0.025, green: 0.028, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viz.isPlaying ? Color(red: 0.51, green: 0.90, blue: 0.69) : Color.white.opacity(0.22))
                .frame(width: 7, height: 7)
            Text("VIZ DATA")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.4)
            Spacer()
            Text("#\(viz.frame)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.48))
        }
        .foregroundStyle(Color.white.opacity(0.92))
    }

    private var sourceStatus: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("SOURCE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.white.opacity(0.45))
                Text(viz.source.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(sourceColor)
                Spacer(minLength: 0)
                Text("\(format(viz.latencyMs, decimals: 0))MS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .monospacedDigit()
            }

            if let error = viz.sourceError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .lineLimit(2)
                    .foregroundStyle(Color(red: 0.96, green: 0.59, blue: 0.37).opacity(0.9))
            }
        }
    }

    private var sourceColor: Color {
        switch viz.source {
        case "webAudio", "screenCapture", "coreAudioTap":
            return Color(red: 0.51, green: 0.90, blue: 0.69)
        case "blocked":
            return Color(red: 0.96, green: 0.59, blue: 0.37)
        default:
            return Color.white.opacity(0.5)
        }
    }

    private var metrics: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
            metricRow("host", format(viz.hostTime, decimals: 3), "media", format(viz.mediaTime, decimals: 3))
            metricRow("dur", format(viz.duration, decimals: 1), "prog", format(viz.progress, decimals: 3))
            metricRow("bpm", format(viz.bpm, decimals: 1), "rate", format(viz.playbackRate, decimals: 2))
            metricRow("beat", "\(viz.beatIndex)+\(format(viz.beatPhase, decimals: 3))", "bar", "\(viz.barIndex)+\(format(viz.barPhase, decimals: 3))")
            metricRow("rms", format(viz.rms, decimals: 3), "peak", format(viz.peak, decimals: 3))
            metricRow("rmsdb", format(viz.rmsDb, decimals: 1), "peakdb", format(viz.peakDb, decimals: 1))
            metricRow("crest", format(viz.crestDb, decimals: 1), "trans", format(viz.transient, decimals: 3))
            metricRow("low", format(viz.low, decimals: 3), "mid", format(viz.mid, decimals: 3))
            metricRow("high", format(viz.high, decimals: 3), "drop", format(viz.drop, decimals: 3))
            metricRow("cent", format(viz.centroidHz, decimals: 0), "bright", format(viz.brightness, decimals: 3))
            metricRow("roll", format(viz.rolloff85Hz, decimals: 0), "tone", format(viz.tonality, decimals: 3))
            metricRow("flux", format(viz.flux, decimals: 3), "onset", format(viz.onsetPulse, decimals: 3))
            metricRow("sub", format(viz.sub, decimals: 3), "bass", format(viz.bass, decimals: 3))
            metricRow("pres", format(viz.presence, decimals: 3), "brill", format(viz.brilliance, decimals: 3))
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }

    private func metricRow(_ a: String, _ av: String, _ b: String, _ bv: String) -> some View {
        GridRow {
            label(a)
            value(av)
            label(b)
            value(bv)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .foregroundStyle(Color(red: 0.51, green: 0.90, blue: 0.69).opacity(0.72))
            .frame(width: 34, alignment: .trailing)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Color.white.opacity(0.86))
            .frame(width: 54, alignment: .leading)
            .monospacedDigit()
    }

    private func bandSection(title: String, values: [Double], positiveOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.46))
            GeometryReader { geometry in
                let count = max(values.count, 1)
                let gap: CGFloat = 2
                let width = max(1, (geometry.size.width - CGFloat(count - 1) * gap) / CGFloat(count))
                HStack(alignment: .center, spacing: gap) {
                    ForEach(values.indices, id: \.self) { index in
                        if positiveOnly {
                            positiveBar(values[index], width: width, height: geometry.size.height)
                        } else {
                            waveformBar(values[index], width: width, height: geometry.size.height)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: positiveOnly ? 34 : 28)
        }
    }

    private func positiveBar(_ value: Double, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.51, green: 0.90, blue: 0.69), Color(red: 0.96, green: 0.59, blue: 0.37)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: max(2, height * CGFloat(clamp(value))))
            .frame(height: height, alignment: .bottom)
            .opacity(0.52 + clamp(value) * 0.48)
    }

    private func waveformBar(_ value: Double, width: CGFloat, height: CGFloat) -> some View {
        let normalized = CGFloat(clamp(abs(value)))
        return Capsule()
            .fill(value >= 0 ? Color(red: 0.51, green: 0.90, blue: 0.69) : Color(red: 0.96, green: 0.59, blue: 0.37))
            .frame(width: width, height: max(2, height * normalized))
            .frame(height: height, alignment: value >= 0 ? .top : .bottom)
            .opacity(0.45 + Double(normalized) * 0.5)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
