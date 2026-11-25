//
//  RecordingWidgetBundle.swift
//  RecordingWidget
//
//  The lock screen Live Activity while WatchMe records.
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RecordingWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingLockScreenView(state: context.state)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(.red)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RecordingBadge(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.title2.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isInterrupted ? "録音停止中" : "録音中")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        StopButton()
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isInterrupted ? "pause.circle.fill" : "waveform")
                    .foregroundStyle(context.state.isInterrupted ? .gray : .red)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(context.state.isInterrupted ? .gray : .red)
            } minimal: {
                Image(systemName: context.state.isInterrupted ? "pause.circle.fill" : "waveform")
                    .foregroundStyle(context.state.isInterrupted ? .gray : .red)
            }
        }
    }
}

private struct RecordingLockScreenView: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            RecordingBadge(state: state)
            VStack(alignment: .leading, spacing: 2) {
                Text("WatchMe")
                    .font(.subheadline.weight(.semibold))
                Text(state.isInterrupted ? "録音停止中・マイクが戻ると再開します" : "録音中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ElapsedText(state: state)
                .font(.title2.weight(.medium).monospacedDigit())
                .foregroundStyle(state.isInterrupted ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90, alignment: .trailing)
            StopButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct RecordingBadge: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .fill(state.isInterrupted ? Color.gray.opacity(0.3) : Color.red.opacity(0.2))
                .frame(width: 40, height: 40)
            Image(systemName: state.isInterrupted ? "pause.fill" : "waveform")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(state.isInterrupted ? .gray : .red)
        }
    }
}

/// Counts up by itself while recording (the system updates it); fixed while paused.
private struct ElapsedText: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        if let paused = state.pausedAt {
            Text(Self.format(paused))
        } else {
            Text(state.countingFrom, style: .timer)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct StopButton: View {
    var body: some View {
        Button(intent: StopRecordingIntent()) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 40, height: 40)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("録音を停止")
    }
}
