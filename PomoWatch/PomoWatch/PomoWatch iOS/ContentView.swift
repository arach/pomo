//
//  ContentView.swift
//  PomoWatch iOS
//
//  Minimal bridge interface showing sync status
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @StateObject private var networkSync = NetworkSyncManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background matching Pomo aesthetic
                LinearGradient(
                    colors: [Color(hex: "1a1a1a"), Color(hex: "0a0a0f")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App icon/logo
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 120, height: 120)
                        )
                    
                    Text("Pomo Bridge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Syncing your Pomodoro timer\nbetween Mac and Apple Watch")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Connection Status Cards
                    VStack(spacing: 15) {
                        // Mac Connection Status
                        ConnectionCard(
                            title: "Mac",
                            systemImage: "desktopcomputer",
                            status: networkSync.macConnectionStatus,
                            lastSync: networkSync.lastMacSync
                        )
                        
                        // Watch Connection Status
                        ConnectionCard(
                            title: "Apple Watch",
                            systemImage: "applewatch",
                            status: connectivity.isReachable ? .connected : .disconnected,
                            lastSync: connectivity.lastMessageTime
                        )
                    }
                    .padding(.top, 20)
                    
                    // Current Session Info
                    if let session = connectivity.currentSession {
                        VStack(spacing: 10) {
                            Text("Active Session")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Label("\(session.timeRemaining / 60):\(String(format: "%02d", session.timeRemaining % 60))", 
                                      systemImage: "timer")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                    .foregroundColor(session.isRunning ? .green : .orange)
                                
                                if session.isRunning {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "pause.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    // Manual sync button
                    Button(action: {
                        connectivity.requestSync()
                        networkSync.syncWithMac()
                    }) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

struct ConnectionCard: View {
    let title: String
    let systemImage: String
    let status: ConnectionStatus
    let lastSync: Date?
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(status.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    
                    Text(status.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let lastSync = lastSync {
                        Text("• \(lastSync.timeAgoString())")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(status.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

enum ConnectionStatus {
    case connected
    case disconnected
    case syncing
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .syncing: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Not Connected"
        case .syncing: return "Syncing..."
        }
    }
}

// Helper extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Date {
    func timeAgoString() -> String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}