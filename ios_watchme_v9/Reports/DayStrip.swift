//
//  DayStrip.swift
//  ios_watchme_v9
//
//  One day as a thin picture for the report's day panels (platform docs/product/screens.md
//  "レポート"): the day's recordings joined end to end in the order they were made, a thin
//  divider between them, and each event as a small emoji where it happened. Warm events sit
//  above the middle line and hard ones below it, as in the recording's own picture
//  (SpotTimelineChart). The time nobody recorded is not drawn.
//

import SwiftUI

struct DayStripData {
    struct Recording: Identifiable {
        let recordedAt: String
        /// Wall-clock start, HH:mm; nil when unknown.
        let clock: String?
        let seconds: Double
        var id: String { recordedAt }
    }

    struct Event: Identifiable {
        let id: String
        let recordedAt: String
        let start: Double
        let type: String
        let intensity: String?
    }

    var recordings: [Recording] = []
    var events: [Event] = []
}

struct DayStrip: View {
    let data: DayStripData

    private static let height: CGFloat = 54
    private static let labelHeight: CGFloat = 12

    /// Width of each recording, in shares of the strip. A short recording still gets a
    /// readable slice next to a long one.
    private var shares: [String: (start: Double, width: Double)] {
        let longest = data.recordings.map(\.seconds).max() ?? 0
        let weights = data.recordings.map { max($0.seconds, longest * 0.15, 1) }
        let total = weights.reduce(0, +)
        var result: [String: (Double, Double)] = [:]
        var at = 0.0
        for (recording, weight) in zip(data.recordings, weights) {
            result[recording.recordedAt] = (at / total, weight / total)
            at += weight
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let middle = Self.height / 2
            let shares = shares

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: width, height: 1)
                    .offset(y: middle)

                // Dividers between recordings, and the start time under each
                ForEach(data.recordings) { recording in
                    if let share = shares[recording.recordedAt] {
                        let x = width * share.start
                        if share.start > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 1, height: Self.height)
                                .offset(x: x)
                        }
                        if let clock = recording.clock, width * share.width >= 30 {
                            Text(clock)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(white: 0.45))
                                .offset(x: x + 3, y: Self.height)
                        }
                    }
                }

                // Later events on top of earlier ones
                ForEach(data.events) { event in
                    if let emoji = Self.emoji[event.type], let direction = Self.direction[event.type],
                       let share = shares[event.recordedAt],
                       let seconds = data.recordings.first(where: { $0.recordedAt == event.recordedAt })?.seconds {
                        let within = seconds > 0 ? min(max(event.start / seconds, 0), 1) : 0.5
                        // Keep the emoji inside the strip at both ends
                        let x = min(max(width * (share.start + share.width * within), 7), width - 7)
                        let reach = (middle - 8) * (0.35 + 0.65 * Self.strength(event.intensity))
                        Text(emoji)
                            .font(.system(size: 12))
                            .fixedSize()
                            .position(x: x, y: middle - direction * reach)
                    }
                }
            }
        }
        .frame(height: Self.height + Self.labelHeight)
        .allowsHitTesting(false)
    }

    static let emoji = ["reprimand": "😠", "conflict": "💢", "crying": "😢", "laughter": "😄", "praise": "👏", "joy": "😊"]
    static let direction: [String: CGFloat] = ["praise": 1, "laughter": 1, "joy": 1, "reprimand": -1, "conflict": -1, "crying": -1]

    /// The graded strength of a reprimand or conflict, the middle for the rest (as
    /// TimelineEvent.gradedStrength).
    private static func strength(_ intensity: String?) -> CGFloat {
        switch intensity {
        case "severe": return 1
        case "strong": return 0.6
        case "mild": return 0.2
        default: return 0.5
        }
    }
}
