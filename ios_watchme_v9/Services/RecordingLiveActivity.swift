//
//  RecordingLiveActivity.swift
//  ios_watchme_v9
//
//  Starts, updates and ends the lock screen Live Activity of a recording
//  (RecordingActivityShared/RecordingActivity.swift, drawn by the RecordingWidget extension).
//  Best effort: when Live Activities are off in Settings, recording works the same without it.
//

import ActivityKit
import Foundation

@MainActor
enum RecordingLiveActivity {
    private static var current: Activity<RecordingActivityAttributes>?

    static func start(recordedSoFar: TimeInterval) {
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            RecordingEventLog.write("live activity: disabled in Settings")
            return
        }
        let state = RecordingActivityAttributes.ContentState(countingFrom: Date().addingTimeInterval(-recordedSoFar), pausedAt: nil)
        do {
            current = try Activity.request(attributes: RecordingActivityAttributes(),
                                           content: ActivityContent(state: state, staleDate: nil))
        } catch {
            RecordingEventLog.write("live activity: could not start: \(error.localizedDescription)")
        }
    }

    /// `recordedSoFar` is the time recorded up to now (interruptions excluded).
    static func update(interrupted: Bool, recordedSoFar: TimeInterval) {
        guard let activity = current else { return }
        let state = RecordingActivityAttributes.ContentState(
            countingFrom: Date().addingTimeInterval(-recordedSoFar),
            pausedAt: interrupted ? recordedSoFar : nil
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Also ends activities left over from a run that died while recording.
    static func endAll() {
        current = nil
        for activity in Activity<RecordingActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
