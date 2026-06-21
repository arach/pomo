//
//  WatchConnectivityManager.swift
//  PomoWatch iOS
//
//  Manages communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity

struct PomoSession: Codable {
    let timeRemaining: Int
    let isRunning: Bool
    let sessionsCompleted: Int
    let selectedMinutes: Int
    let theme: String
    let timestamp: Date
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var currentSession: PomoSession?
    @Published var lastMessageTime: Date?
    
    private let session: WCSession
    
    private override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Send to Watch
    
    func sendSessionToWatch(_ pomoSession: PomoSession) {
        guard session.isReachable else {
            // If watch isn't reachable, update application context for next launch
            updateContext(pomoSession)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(pomoSession)
            let message = ["session": data]
            
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message to watch: \(error)")
                // Fallback to context update
                self.updateContext(pomoSession)
            }
            
            lastMessageTime = Date()
        } catch {
            print("Error encoding session: \(error)")
        }
    }
    
    private func updateContext(_ pomoSession: PomoSession) {
        do {
            let data = try JSONEncoder().encode(pomoSession)
            let context = ["session": data]
            
            try session.updateApplicationContext(context)
        } catch {
            print("Error updating context: \(error)")
        }
    }
    
    func requestSync() {
        guard session.isReachable else { return }
        
        session.sendMessage(["command": "requestSync"], replyHandler: { reply in
            if let data = reply["session"] as? Data {
                do {
                    self.currentSession = try JSONDecoder().decode(PomoSession.self, from: data)
                    self.lastMessageTime = Date()
                } catch {
                    print("Error decoding session: \(error)")
                }
            }
        }, errorHandler: { error in
            print("Error requesting sync: \(error)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        if let error = error {
            print("Session activation failed: \(error)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["session"] as? Data {
            do {
                let pomoSession = try JSONDecoder().decode(PomoSession.self, from: data)
                DispatchQueue.main.async {
                    self.currentSession = pomoSession
                    self.lastMessageTime = Date()
                    
                    // Forward to Mac
                    NetworkSyncManager.shared.forwardToMac(pomoSession)
                }
            } catch {
                print("Error decoding session from watch: \(error)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["command"] as? String == "requestSync" {
            if let currentSession = currentSession {
                do {
                    let data = try JSONEncoder().encode(currentSession)
                    replyHandler(["session": data])
                } catch {
                    replyHandler([:])
                }
            } else {
                replyHandler([:])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["session"] as? Data {
            do {
                let pomoSession = try JSONDecoder().decode(PomoSession.self, from: data)
                DispatchQueue.main.async {
                    self.currentSession = pomoSession
                    self.lastMessageTime = Date()
                }
            } catch {
                print("Error decoding context: \(error)")
            }
        }
    }
    
    // Required for iOS
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}