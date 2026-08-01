import Foundation
import WatchConnectivity

final class WatchCompanionController: NSObject, ObservableObject {
    @Published private(set) var state: SharedSessionState?
    @Published private(set) var isPhoneReachable = false
    @Published private(set) var hasCompanionApp = false

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        hasCompanionApp = session?.isCompanionAppInstalled ?? false
        session?.delegate = self
        session?.activate()
    }

    func send(_ command: SharedSessionCommand) {
        guard let session, session.isReachable else { return }
        session.sendMessage(
            ["command": command.rawValue],
            replyHandler: { [weak self] reply in
                if let data = reply["state"] as? Data {
                    self?.accept(data)
                }
            },
            errorHandler: nil
        )
    }

    func refresh() {
        send(.requestState)
    }

    private func accept(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(SharedSessionState.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.state = decoded
        }
    }
}

extension WatchCompanionController: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
            self?.hasCompanionApp = session.isCompanionAppInstalled
        }
        if activationState == .activated {
            refresh()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
            self?.hasCompanionApp = session.isCompanionAppInstalled
        }
        if session.isReachable {
            refresh()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message["state"] as? Data {
            accept(data)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["state"] as? Data {
            accept(data)
        }
    }
}
