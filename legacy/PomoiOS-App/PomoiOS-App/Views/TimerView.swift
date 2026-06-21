import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var showingModeSelection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        timerManager.currentMode.color.opacity(0.3),
                        timerManager.currentMode.color.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Mode selector
                    Button(action: { showingModeSelection = true }) {
                        HStack {
                            Image(systemName: timerManager.currentMode.icon)
                            Text(timerManager.currentMode.rawValue)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(timerManager.currentMode.color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(timerManager.currentMode.color.opacity(0.2))
                        )
                    }
                    
                    // Timer display
                    ZStack {
                        // Progress ring
                        Circle()
                            .stroke(
                                timerManager.currentMode.color.opacity(0.2),
                                lineWidth: 20
                            )
                            .frame(width: 280, height: 280)
                        
                        Circle()
                            .trim(from: 0, to: timerManager.progress)
                            .stroke(
                                timerManager.currentMode.color,
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 280, height: 280)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerManager.progress)
                        
                        VStack(spacing: 10) {
                            Text(timerManager.formattedTime)
                                .font(.system(size: 60, weight: .light, design: .rounded))
                                .monospacedDigit()
                            
                            if timerManager.completedPomodoros > 0 {
                                HStack(spacing: 4) {
                                    ForEach(0..<min(timerManager.completedPomodoros, 8), id: \.self) { _ in
                                        Circle()
                                            .fill(timerManager.currentMode.color)
                                            .frame(width: 8, height: 8)
                                    }
                                    if timerManager.completedPomodoros > 8 {
                                        Text("+\(timerManager.completedPomodoros - 8)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Control buttons
                    HStack(spacing: 30) {
                        // Reset button
                        Button(action: { timerManager.resetTimer() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray6))
                                )
                        }
                        
                        // Play/Pause button
                        Button(action: {
                            if timerManager.isActive {
                                timerManager.pauseTimer()
                            } else {
                                timerManager.startTimer()
                            }
                        }) {
                            Image(systemName: timerManager.isActive ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(timerManager.currentMode.color)
                                )
                        }
                        
                        // Skip button
                        Button(action: { timerManager.skipToNext() }) {
                            Image(systemName: "forward.end.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingModeSelection) {
                ModeSelectionView()
            }
            .alert("Session Complete!", isPresented: $timerManager.showingCompletion) {
                Button("Continue") {
                    timerManager.showingCompletion = false
                }
            } message: {
                Text("Great work! Time for a \(timerManager.currentMode.rawValue)")
            }
        }
    }
}

struct ModeSelectionView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(FocusMode.allCases, id: \.self) { mode in
                Button(action: {
                    timerManager.switchToMode(mode)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: mode.icon)
                            .font(.title2)
                            .foregroundColor(mode.color)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(.headline)
                            Text("\(Int(mode.duration / 60)) minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if mode == timerManager.currentMode {
                            Image(systemName: "checkmark")
                                .foregroundColor(mode.color)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Mode")
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
            .environmentObject(TimerManager())
    }
}