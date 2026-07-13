import ActivityKit
import Foundation

@MainActor
final class PomoLiveActivityController {
    private var activity: Activity<PomoActivityAttributes>?
    private var currentIntent = ""

    init() {
        activity = Activity<PomoActivityAttributes>.activities.first
        currentIntent = activity?.content.state.intent ?? ""
    }

    func startOrResume(
        modeName: String,
        intent: String,
        remaining: TimeInterval,
        total: TimeInterval,
        accentHex: UInt32
    ) {
        currentIntent = intent
        let state = contentState(remaining: remaining, paused: false, intent: intent)
        let content = ActivityContent(state: state, staleDate: state.endDate)

        if let current = activity ?? Activity<PomoActivityAttributes>.activities.first {
            activity = current
            Task { await current.update(content) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PomoActivityAttributes(
            modeName: modeName,
            totalSeconds: max(Int(total.rounded()), 1),
            accentHex: accentHex
        )

        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // Live Activities are optional and can be disabled or capacity-limited.
            activity = nil
        }
    }

    func pause(remaining: TimeInterval, intent: String) {
        guard let current = activity ?? Activity<PomoActivityAttributes>.activities.first else { return }
        activity = current
        currentIntent = intent
        let state = contentState(remaining: remaining, paused: true, intent: intent)
        Task {
            await current.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(remaining: TimeInterval = 0, immediate: Bool) {
        guard let current = activity ?? Activity<PomoActivityAttributes>.activities.first else { return }
        activity = nil
        let state = contentState(remaining: remaining, paused: true, intent: currentIntent)
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .default
        Task {
            await current.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
        }
    }

    private func contentState(
        remaining: TimeInterval,
        paused: Bool,
        intent: String
    ) -> PomoActivityAttributes.ContentState {
        let seconds = max(Int(remaining.rounded(.up)), 0)
        return PomoActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(TimeInterval(seconds)),
            remainingSeconds: seconds,
            isPaused: paused,
            intent: intent
        )
    }
}
