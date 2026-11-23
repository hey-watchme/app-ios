//
//  ReportMetric.swift
//  ios_watchme_v9
//
//  What the report's trend chart can show besides the day's Vibe: the counted events,
//  one kind at a time or added up per axis (platform docs/events.md,
//  docs/product/axes-and-score.md). The numbers are the counts as they were counted;
//  they are not divided by the length of the recordings.
//

import Foundation

struct ReportMetric: Identifiable, Hashable {
    let id: String
    let name: String
    /// Event types added up; empty for Vibe.
    let eventTypes: [String]

    var isVibe: Bool { eventTypes.isEmpty }

    static let vibe = ReportMetric(id: "vibe", name: "気分", eventTypes: [])

    /// The axes of axes-and-score.md, as far as today's event types go. A mishap belongs to none yet.
    static let axes = [
        ReportMetric(id: "axis-trouble", name: "対人トラブル", eventTypes: ["reprimand", "conflict"]),
        ReportMetric(id: "axis-positive", name: "肯定的な関わり", eventTypes: ["praise", "joy"]),
        ReportMetric(id: "axis-expression", name: "感情の表出", eventTypes: ["crying", "laughter"]),
        ReportMetric(id: "axis-body", name: "体調", eventTypes: ReportEvents.bodyTypes),
    ]

    static let events = SpotEventsCard.typeOrder.map {
        ReportMetric(id: $0, name: SpotEventsCard.typeNames[$0] ?? $0, eventTypes: [$0])
    }
}

/// One row of spot_event_runs, as the report reads it.
struct ReportEventRun: Decodable {
    let local_date: String
    let recorded_at: String
    let extractor_version: String
    let audio_seconds: Double?
    let counts: [String: Int]?
}

/// What was counted on one local date.
struct ReportDayCounts {
    /// Event type -> times. A type is present only when a recording of the day looked for it,
    /// so "not looked for" (absent) and "looked for, none" (0) stay apart.
    var counts: [String: Int] = [:]
    var recordings = 0
    var audioSeconds: Double = 0

    /// Times the metric's events were counted; nil when no recording of the day looked for them.
    func value(of metric: ReportMetric) -> Int? {
        let lookedFor = metric.eventTypes.compactMap { counts[$0] }
        return lookedFor.isEmpty ? nil : lookedFor.reduce(0, +)
    }
}

enum ReportEvents {
    static let bodyTypes = ["cough", "sneeze", "throat_clearing"]
    /// Body sounds are counted from this extractor version on; earlier versions never looked for them.
    static let bodyTypesSince = "events-v3"

    /// A length of audio in words: 42分, 1時間5分, 30秒.
    static func durationText(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60)時間\(minutes % 60)分" }
        return minutes > 0 ? "\(minutes)分" : "\(Int(seconds))秒"
    }

    /// The runs added up per local date. A recording analysed by more than one extractor
    /// version counts once, by its newest version (as the detail screens do).
    static func days(from runs: [ReportEventRun]) -> [String: ReportDayCounts] {
        var newest: [String: ReportEventRun] = [:]  // recorded_at -> run
        for run in runs where (newest[run.recorded_at]?.extractor_version ?? "") < run.extractor_version {
            newest[run.recorded_at] = run
        }

        var days: [String: ReportDayCounts] = [:]
        for run in newest.values {
            var day = days[run.local_date] ?? ReportDayCounts()
            day.recordings += 1
            day.audioSeconds += run.audio_seconds ?? 0
            for type in SpotEventsCard.typeOrder
            where run.extractor_version >= bodyTypesSince || !bodyTypes.contains(type) {
                // A type the run looked for and did not find may be missing from its counts
                day.counts[type, default: 0] += run.counts?[type] ?? 0
            }
            days[run.local_date] = day
        }
        return days
    }
}
