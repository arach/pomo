import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var timerManager: TimerManager
    @State private var selectedTimeRange = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Cards
                    HStack(spacing: 16) {
                        StatsCard(
                            title: "Today",
                            value: "\(timerManager.dailySessions)",
                            subtitle: "sessions",
                            color: .cyan
                        )
                        
                        StatsCard(
                            title: "Streak",
                            value: "\(statsManager.streakDays)",
                            subtitle: "days",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 16) {
                        StatsCard(
                            title: "Total",
                            value: "\(statsManager.totalSessions)",
                            subtitle: "all time",
                            color: .purple
                        )
                        
                        StatsCard(
                            title: "Average",
                            value: String(format: "%.1f", statsManager.averageSessionsPerDay),
                            subtitle: "per day",
                            color: .green
                        )
                    }
                    
                    // Weekly Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weekly Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if !statsManager.weeklyStats.isEmpty {
                            Chart(statsManager.weeklyStats) { stat in
                                BarMark(
                                    x: .value("Day", stat.date, unit: .day),
                                    y: .value("Sessions", stat.sessions)
                                )
                                .foregroundStyle(.cyan)
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                        } else {
                            Text("No data yet. Start your first session!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Focus Time Distribution
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Focus Time Today")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let totalMinutes = Int(timerManager.totalFocusTime / 60)
                        let hours = totalMinutes / 60
                        let minutes = totalMinutes % 60
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.largeTitle)
                                .foregroundColor(.cyan)
                            
                            VStack(alignment: .leading) {
                                if hours > 0 {
                                    Text("\(hours)h \(minutes)m")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("\(minutes) minutes")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                Text("Total focus time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Best Streak
                    if statsManager.bestStreak > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text("Best Streak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(statsManager.bestStreak) days")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            if statsManager.streakDays == statsManager.bestStreak {
                                Text("Current!")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange)
                                    )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
        }
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
            .environmentObject(StatsManager())
            .environmentObject(TimerManager())
    }
}