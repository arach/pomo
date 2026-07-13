import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var stats: StatsManager
    @State private var heatmapPulse = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    summaryGrid
                    weeklyChart
                    focusHeatmap
                    recentSessions
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .pomoScreen()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 8) {
                PomoWordmark()
                Text("Activity")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(PomoPalette.ink)
            }
            Spacer()
            Text("ACTIVITY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(PomoPalette.dim)
        }
    }

    private var summaryGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                metric("Today", "\(stats.todaySessions)", "sessions", tint: PomoPalette.accent)
                metric("Streak", "\(stats.streakDays)", stats.streakDays == 1 ? "day" : "days", tint: PomoPalette.orange)
            }
            GridRow {
                metric("Focus time", formatDuration(stats.totalFocusTime), "all time")
                metric("Completed", "\(stats.totalSessions)", "sessions", tint: PomoPalette.green)
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ detail: String, tint: Color = PomoPalette.ink) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(PomoPalette.dim)
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(detail)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(PomoPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pomoPanel(padding: 16)
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            PomoSectionLabel(title: "This week", trailing: "\(stats.weeklyStats.reduce(0) { $0 + $1.sessions }) sessions")

            Chart(stats.weeklyStats) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Sessions", day.sessions)
                )
                .foregroundStyle(
                    Calendar.current.isDateInToday(day.date)
                        ? PomoPalette.accent
                        : PomoPalette.accent.opacity(0.34)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(PomoPalette.dim)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(PomoPalette.border)
                    AxisValueLabel().foregroundStyle(PomoPalette.dim)
                }
            }
            .chartYScale(domain: 0...max(6, (stats.weeklyStats.map(\.sessions).max() ?? 0) + 1))
            .frame(height: 180)
        }
        .pomoPanel()
    }

    private var focusHeatmap: some View {
        let days = stats.activity(days: 35)
        return VStack(alignment: .leading, spacing: 18) {
            PomoSectionLabel(title: "Last five weeks", trailing: "less  ·  more")

            GeometryReader { proxy in
                let spacing: CGFloat = 6
                let size = min((proxy.size.width - spacing * 6) / 7, 34)
                HStack(spacing: spacing) {
                    ForEach(Array(stride(from: 0, to: days.count, by: 7)), id: \.self) { start in
                        VStack(spacing: spacing) {
                            ForEach(Array(days[start..<min(start + 7, days.count)])) { day in
                                let isToday = Calendar.current.isDateInToday(day.date)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(PomoPalette.accent.opacity(activityOpacity(day.sessions, isToday: isToday)))
                                    .overlay {
                                        if isToday {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .stroke(PomoPalette.accent, lineWidth: 1)
                                        }
                                    }
                                    .shadow(
                                        color: isToday ? PomoPalette.accent.opacity(heatmapPulse ? 0.35 : 0.08) : .clear,
                                        radius: heatmapPulse ? 5 : 1
                                    )
                                    .frame(width: size, height: size)
                                    .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.sessions) sessions")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 7 * 34 + 6 * 6)
        }
        .pomoPanel()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                heatmapPulse = true
            }
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 14) {
            PomoSectionLabel(title: "Recent")

            if stats.recentFocusSessions.isEmpty {
                Text("Finish a focus block and it will show up here.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(PomoPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(stats.recentFocusSessions) { session in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(PomoPalette.accent)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.intent ?? "Focus session")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(PomoPalette.ink)
                                .lineLimit(1)
                            Text(session.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(PomoPalette.dim)
                        }
                        Spacer()
                        Text("\(Int(session.duration / 60))m")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(PomoPalette.muted)
                    }
                    .padding(.vertical, 8)

                    if session.id != stats.recentFocusSessions.last?.id {
                        Divider().overlay(PomoPalette.border)
                    }
                }
            }
        }
        .pomoPanel()
    }

    private func activityOpacity(_ count: Int, isToday: Bool) -> Double {
        if isToday && count == 0 { return heatmapPulse ? 0.55 : 0.16 }
        switch count {
        case 0: return 0.07
        case 1: return 0.28
        case 2: return 0.45
        case 3: return 0.62
        case 4: return 0.78
        default: return 1
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        }
        return "\(totalMinutes)m"
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsManager())
}
