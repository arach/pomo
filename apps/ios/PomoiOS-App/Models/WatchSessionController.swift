import Combine
import Foundation
import WatchConnectivity

final class WatchSessionController: NSObject, ObservableObject {
    @Published private(set) var isWatchReachable = false

    private weak var timerManager: TimerManager?
    private let session: WCSession?
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        session = WCSession.isSupported() ? .default : nil
        super.init()

        session?.delegate = self
        session?.activate()

        timerManager.$stateRevision
            .dropFirst()
            .map { _ in () }
            .merge(with:
                timerManager.$intent
                    .dropFirst()
                    .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
                    .map { _ in () }
            )
            .sink { [weak self] in
                self?.publishCurrentState()
            }
            .store(in: &cancellables)
    }

    func publishCurrentState() {
        guard let session else { return }
        Task { @MainActor [weak self] in
            guard let self, let timerManager = self.timerManager else { return }
            let state = timerManager.sharedSessionState()
            guard let data = try? JSONEncoder().encode(state) else { return }

            try? session.updateApplicationContext(["state": data])
            if session.isReachable {
                session.sendMessage(["state": data], replyHandler: nil)
            }
        }
    }

    private func apply(
        _ command: SharedSessionCommand,
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        Task { @MainActor [weak self] in
            guard let timerManager = self?.timerManager else {
                replyHandler?([:])
                return
            }
            switch command {
            case .start:
                if !timerManager.isActive { timerManager.startTimer() }
            case .pause:
                timerManager.pauseTimer()
            case .reset:
                timerManager.resetTimer()
            case .skip:
                timerManager.skipToNext()
            case .continueNext:
                timerManager.dismissOutcome(startNext: true)
            case .dismissOutcome:
                timerManager.dismissOutcome(startNext: false)
            case .requestState:
                break
            }

            guard let data = try? JSONEncoder().encode(timerManager.sharedSessionState()) else {
                replyHandler?([:])
                return
            }
            replyHandler?(["state": data])
        }
    }
}

extension WatchSessionController: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchReachable = session.isReachable
            self?.publishCurrentState()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchReachable = session.isReachable
            if session.isReachable { self?.publishCurrentState() }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let rawCommand = message["command"] as? String,
              let command = SharedSessionCommand(rawValue: rawCommand)
        else { return }
        apply(command)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let rawCommand = message["command"] as? String,
              let command = SharedSessionCommand(rawValue: rawCommand)
        else {
            replyHandler([:])
            return
        }

        apply(command, replyHandler: replyHandler)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
