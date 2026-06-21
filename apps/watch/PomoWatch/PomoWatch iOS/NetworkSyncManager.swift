//
//  NetworkSyncManager.swift
//  PomoWatch iOS
//
//  Syncs with macOS Pomo app via local network or iCloud
//

import Foundation
import Network
import MultipeerConnectivity

class NetworkSyncManager: NSObject, ObservableObject {
    static let shared = NetworkSyncManager()
    
    @Published var macConnectionStatus: ConnectionStatus = .disconnected
    @Published var lastMacSync: Date?
    
    // MultipeerConnectivity for local network discovery
    private let serviceType = "pomo-sync"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    private var advertiser: MCNearbyServiceAdvertiser!
    
    // Network discovery
    private let netBrowser = NWBrowser(for: .bonjour(type: "_pomo._tcp", domain: nil), using: .tcp)
    
    override init() {
        super.init()
        setupMultipeer()
        setupNetworkDiscovery()
    }
    
    private func setupMultipeer() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        // Browse for Mac peers
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        // Advertise to Mac
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["device": "iPhone"], serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
    }
    
    private func setupNetworkDiscovery() {
        netBrowser.browseResultsChangedHandler = { results, changes in
            for result in results {
                if case .service(let name, let type, let domain, let interface) = result.endpoint {
                    print("Found Pomo service: \(name) on \(interface)")
                    DispatchQueue.main.async {
                        self.macConnectionStatus = .connected
                        self.lastMacSync = Date()
                    }
                }
            }
        }
        
        netBrowser.start(queue: .main)
    }
    
    func syncWithMac() {
        // Try to sync with Mac
        if let currentSession = WatchConnectivityManager.shared.currentSession {
            forwardToMac(currentSession)
        }
    }
    
    func forwardToMac(_ session: PomoSession) {
        // Send via MultipeerConnectivity
        if self.session.connectedPeers.count > 0 {
            do {
                let data = try JSONEncoder().encode(session)
                try self.session.send(data, toPeers: self.session.connectedPeers, with: .reliable)
                
                DispatchQueue.main.async {
                    self.lastMacSync = Date()
                }
            } catch {
                print("Error sending to Mac: \(error)")
            }
        }
        
        // Also save to UserDefaults for sharing via App Groups (if configured)
        saveToSharedDefaults(session)
    }
    
    private func saveToSharedDefaults(_ session: PomoSession) {
        // This would work if you have App Groups configured
        if let defaults = UserDefaults(suiteName: "group.com.yourteam.pomo") {
            do {
                let data = try JSONEncoder().encode(session)
                defaults.set(data, forKey: "currentSession")
                defaults.synchronize()
            } catch {
                print("Error saving to shared defaults: \(error)")
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension NetworkSyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.macConnectionStatus = .connected
                print("Connected to: \(peerID.displayName)")
            case .connecting:
                self.macConnectionStatus = .syncing
            case .notConnected:
                self.macConnectionStatus = .disconnected
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Receive data from Mac
        do {
            let pomoSession = try JSONDecoder().decode(PomoSession.self, from: data)
            DispatchQueue.main.async {
                // Forward to Watch
                WatchConnectivityManager.shared.sendSessionToWatch(pomoSession)
                self.lastMacSync = Date()
            }
        } catch {
            print("Error decoding data from Mac: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NetworkSyncManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Found a Mac running Pomo
        if info?["device"] == "Mac" {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.macConnectionStatus = .disconnected
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NetworkSyncManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept invitations from Mac
        invitationHandler(true, session)
    }
}