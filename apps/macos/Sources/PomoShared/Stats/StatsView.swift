import SwiftUI
import HudsonUI
import HudsonShell

/// The focus-history window: headline numbers + a GitHub-style heatmap of the
/// days you showed up, plus a recent-sessions list. Opened from the menu popover
/// (chart button) or `pomo://stats`. Dressed in Hudson tokens to match Settings.
struct StatsView: View {
    let history: SessionHistoryStore
    var onClose: () -> Void

    private let calendar = Calendar.current
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HudSpacing.xxl) {
                header
                summaryRow
                heatmapCard
                recentSection
                footerBar
            }
            .padding(HudSpacing.huge)
        }
        .frame(width: 460, height: 660)
        .background(frostedBackground)
        .background(
            // Esc closes, matching the HUD.
            Button("", action: onClose)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
        .environment(\.hudTheme, .default)
    }

    /// Behind-window frost + dark scrim, matching the HUD / menu popover.
    private var frostedBackground: some View {
        ZStack {
            HudVisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            LinearGradient(
                colors: [Color.black.opacity(0.46), Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: HudSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(HudPalette.accent)
            Text("Pomo")
                .font(HudFont.mono(HudTextSize.lg, weight: .semibold))
                .foregroundStyle(HudPalette.ink)
            Spacer()
            Text("STATS")
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .tracking(2)
                .foregroundStyle(HudPalette.muted)
        }
    }

    // MARK: - Summary tiles

    private var summaryRow: some View {
        HStack(spacing: HudSpacing.md) {
            metricTile("This week", "\(history.focusCountThisWeek())")
            metricTile("Focused", hoursMinutes(history.focusSecondsThisWeek()))
            metricTile("Streak", streakLabel, tint: HudPalette.accent)
        }
    }

    private var streakLabel: String {
        let days = history.currentStreak()
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func metricTile(_ label: String, _ value: String, tint: Color = HudPalette.ink) -> some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            Text(label.uppercased())
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(HudPalette.dim)
            Text(value)
                .font(HudFont.mono(26, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HudSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.card)
                .fill(HudPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.card)
                        .stroke(HudPalette.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: HudSpacing.lg) {
            HStack {
                Text("LAST 17 WEEKS")
                    .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(HudPalette.dim)
                Spacer()
                legend
            }
            heatmapGrid
        }
        .padding(HudSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HudRadius.card)
                .fill(HudPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: HudRadius.card)
                        .stroke(HudPalette.border, lineWidth: 1)
                )
        )
    }

    private var legend: some View {
        HStack(spacing: HudSpacing.xs) {
            Text("less")
                .font(HudFont.mono(HudTextSize.micro))
                .foregroundStyle(HudPalette.dim)
            ForEach([0, 1, 2, 4], id: \.self) { count in
                RoundedRectangle(cornerRadius: 2)
                    .fill(HudPalette.accent.opacity(opacity(for: count)))
                    .frame(width: 10, height: 10)
            }
            Text("more")
                .font(HudFont.mono(HudTextSize.micro))
                .foregroundStyle(HudPalette.dim)
        }
    }

    private var heatmapGrid: some View {
        let columns = history.heatmap()
        return HStack(alignment: .top, spacing: 4) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: 4) {
                    ForEach(column) { day in
                        cell(day)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    /// One heatmap square. Today's square carries a soft accent ring + glow that
    /// breathes — it's the one bright invitation in an otherwise empty grid.
    @ViewBuilder
    private func cell(_ day: DayCount) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let fillOpacity = (isToday && day.count == 0)
            ? (pulse ? 0.85 : 0.30)        // empty "today" breathes
            : opacity(for: day.count)
        RoundedRectangle(cornerRadius: 2)
            .fill(HudPalette.accent.opacity(fillOpacity))
            .frame(width: 13, height: 13)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(HudPalette.accent, lineWidth: 1)
                        .opacity(pulse ? 0.9 : 0.25)
                }
            }
            .shadow(
                color: isToday ? HudPalette.accent.opacity(pulse ? 0.7 : 0.15) : .clear,
                radius: isToday ? (pulse ? 5 : 1.5) : 0
            )
            .help(todayOrDayHelp(day, isToday: isToday))
    }

    private func todayOrDayHelp(_ day: DayCount, isToday: Bool) -> String {
        guard isToday else { return helpText(for: day) }
        if day.count == 0 { return "Today · start a session" }
        return "Today · \(day.count) session\(day.count == 1 ? "" : "s")"
    }

    private func opacity(for count: Int) -> Double {
        switch count {
        case 0:  return 0.10
        case 1:  return 0.40
        case 2:  return 0.62
        case 3:  return 0.80
        default: return 1.0
        }
    }

    private func helpText(for day: DayCount) -> String {
        let date = Self.dayFormatter.string(from: day.date)
        if day.count == 0 { return "\(date) · no sessions" }
        return "\(date) · \(day.count) session\(day.count == 1 ? "" : "s")"
    }

    // MARK: - Recent sessions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: HudSpacing.md) {
            Text("RECENT")
                .font(HudFont.mono(HudTextSize.micro, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(HudPalette.dim)

            if recent.isEmpty {
                Text("No focus sessions yet. Finish a 25-minute block and it'll show up here.")
                    .font(HudFont.ui(HudTextSize.sm))
                    .foregroundStyle(HudPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { record in
                        recentRow(record)
                    }
                }
            }
        }
    }

    private var recent: [SessionRecord] {
        Array(history.records.filter(\.isFocus).suffix(8).reversed())
    }

    private func recentRow(_ record: SessionRecord) -> some View {
        HStack(spacing: HudSpacing.md) {
            Circle()
                .fill(HudPalette.accent)
                .frame(width: 6, height: 6)
            Text(record.intent ?? "Focus session")
                .font(HudFont.ui(HudTextSize.sm))
                .foregroundStyle(record.intent == nil ? HudPalette.muted : HudPalette.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: HudSpacing.md)
            Text(Self.rowFormatter.string(from: record.completedAt))
                .font(HudFont.mono(HudTextSize.xs))
                .foregroundStyle(HudPalette.dim)
        }
        .padding(.vertical, HudSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HudPalette.border).frame(height: 1)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Text("\(history.totalFocusCount) focus session\(history.totalFocusCount == 1 ? "" : "s") all time")
                .font(HudFont.mono(HudTextSize.xs))
                .foregroundStyle(HudPalette.dim)
            Spacer()
            if !history.records.isEmpty {
                HudButton("Clear", style: .secondary) { history.clear() }
            }
            HudButton("Done", style: .primary(.green)) { onClose() }
        }
    }

    // MARK: - Formatting

    private func hoursMinutes(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    private static let rowFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
}
