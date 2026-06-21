import Foundation
import Observation

/// The countdown engine. Ported from the Tauri app's `timer-store.ts` but
/// drift-free: while running it derives `remainingSeconds` from a target
/// `endDate` rather than decrementing a counter, so it stays accurate even if a
/// tick is late. Pausing snapshots the remaining time.
@MainActor
@Observable
final class TimerModel {
    enum Phase {
        case idle      // configured, not started
        case running
        case paused
    }

    private(set) var phase: Phase = .idle
    private(set) var sessionType: SessionType = .focus
    private(set) var totalSeconds: Int
    private(set) var remainingSeconds: Int

    /// Number of completed focus sessions in the current cycle — drives when a
    /// long break is offered.
    private(set) var completedFocusCount: Int = 0

    /// Fired once when a session reaches zero (play sound, summon panel, flash).
    @ObservationIgnored var onComplete: ((SessionType) -> Void)?
    /// Fired every display tick + on any state change (menu-bar refresh).
    @ObservationIgnored var onTick: (() -> Void)?

    @ObservationIgnored private let settings: PomoSettings
    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?

    init(settings: PomoSettings) {
        self.settings = settings
        self.totalSeconds = settings.seconds(for: .focus)
        self.remainingSeconds = settings.seconds(for: .focus)
    }

    // MARK: - Derived

    var isRunning: Bool { phase == .running }
    var isPaused: Bool { phase == .paused }
    var isIdle: Bool { phase == .idle }

    /// 0…1 elapsed fraction.
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var clock: String { TimeFormat.clock(remainingSeconds) }

    // MARK: - Controls

    /// Start from idle, or resume from pause.
    func start() {
        guard phase != .running else { return }
        if remainingSeconds <= 0 { remainingSeconds = totalSeconds }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        phase = .running
        startTicker()
        notify()
    }

    func pause() {
        guard phase == .running else { return }
        syncRemaining()
        stopTicker()
        endDate = nil
        phase = .paused
        notify()
    }

    /// Space-bar behaviour: start ⇄ pause.
    func toggle() {
        switch phase {
        case .running: pause()
        case .idle, .paused: start()
        }
    }

    /// Stop and return to the start of the current session.
    func reset() {
        stopTicker()
        endDate = nil
        phase = .idle
        remainingSeconds = totalSeconds
        notify()
    }

    /// Advance to the next session type without finishing the current one.
    func skip() {
        stopTicker()
        endDate = nil
        advanceSession(didComplete: false)
    }

    // MARK: - Configuration (only meaningful while idle)

    func setSessionType(_ type: SessionType) {
        guard phase == .idle else { return }
        sessionType = type
        totalSeconds = settings.seconds(for: type)
        remainingSeconds = totalSeconds
        notify()
    }

    func cycleSessionType() {
        guard phase == .idle else { return }
        let all = SessionType.allCases
        let idx = all.firstIndex(of: sessionType) ?? 0
        setSessionType(all[(idx + 1) % all.count])
    }

    func setMinutes(_ minutes: Int) {
        guard phase == .idle else { return }
        let secs = max(60, min(99 * 60, minutes * 60))
        totalSeconds = secs
        remainingSeconds = secs
        notify()
    }

    func adjustMinutes(_ delta: Int) {
        guard phase == .idle else { return }
        let currentMinutes = totalSeconds / 60
        setMinutes(currentMinutes + delta)
    }

    /// Re-read durations from settings if the user edits them while idle.
    func reloadDurationsIfIdle() {
        guard phase == .idle else { return }
        totalSeconds = settings.seconds(for: sessionType)
        remainingSeconds = totalSeconds
        notify()
    }

    // MARK: - Ticking

    private func startTicker() {
        ticker?.invalidate()
        // 0.2s cadence keeps the display crisp; value is derived from endDate.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let endDate else { return }
        let remaining = Int(ceil(endDate.timeIntervalSinceNow))
        if remaining <= 0 {
            remainingSeconds = 0
            stopTicker()
            self.endDate = nil
            complete()
        } else if remaining != remainingSeconds {
            remainingSeconds = remaining
            notify()
        }
    }

    private func syncRemaining() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func complete() {
        let finished = sessionType
        if finished == .focus { completedFocusCount += 1 }
        onComplete?(finished)
        advanceSession(didComplete: true)
        if settings.autoStartNext { start() }
    }

    /// Pick the next session type and configure its duration.
    private func advanceSession(didComplete: Bool) {
        let next: SessionType
        if sessionType == .focus {
            let interval = max(1, settings.longBreakInterval)
            next = (completedFocusCount % interval == 0) ? .longBreak : .shortBreak
        } else {
            next = .focus
        }
        sessionType = next
        totalSeconds = settings.seconds(for: next)
        remainingSeconds = totalSeconds
        phase = .idle
        notify()
    }

    private func notify() { onTick?() }
}
