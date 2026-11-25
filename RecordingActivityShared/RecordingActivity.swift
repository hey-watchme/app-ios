//
//  RecordingActivity.swift
//  Shared by the app and the RecordingWidget extension.
//
//  The Live Activity shown on the lock screen while recording (like Voice Memos):
//  elapsed time, whether the microphone is taken (interrupted), and a stop button.
//

import ActivityKit
import AppIntents
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Recording: the elapsed time is "now - countingFrom" (interruptions are taken out).
        var countingFrom: Date
        /// Interrupted: recording is paused at this many seconds.
        var pausedAt: TimeInterval?

        var isInterrupted: Bool { pausedAt != nil }
    }
}

extension Foundation.Notification.Name {
    /// Posted by StopRecordingIntent; RecordingStore stops the recording.
    static let watchMeStopRecordingRequested = Foundation.Notification.Name("watchMeStopRecordingRequested")
}

/// The stop button on the lock screen. A LiveActivityIntent runs in the app's process.
struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "録音を停止"
    static var description = IntentDescription("WatchMe の録音を止めます")

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .watchMeStopRecordingRequested, object: nil)
        }
        return .result()
    }
}
