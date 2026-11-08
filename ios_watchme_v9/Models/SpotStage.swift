//
//  SpotStage.swift
//  ios_watchme_v9
//
//  One row of spot_stages: how far one stage of a recording's analysis has got.
//  The pipeline writes a row per stage; the app fills the result card in as they complete.
//

import Foundation

struct SpotStage: Codable, Equatable, Identifiable {
    let stage: String
    let status: String      // queued, running, completed, failed, skipped
    let payload: JSONValue?
    let error: String?
    let updatedAt: String?

    var id: String { stage }

    enum CodingKeys: String, CodingKey {
        case stage, status, payload, error
        case updatedAt = "updated_at"
    }

    /// Pipeline order, as shown on the card.
    static let order = ["transcribe", "sound_events", "measure", "scene", "emotion", "profile", "day_so_far"]

    static let labels: [String: String] = [
        "transcribe": "文字起こし",
        "sound_events": "周りの音",
        "measure": "会話の指標",
        "scene": "場面",
        "emotion": "声の表情",
        "profile": "分析",
        "day_so_far": "ここまで",
    ]

    var label: String { Self.labels[stage] ?? stage }

    /// A stage cannot legitimately stay "running" longer than a Lambda can run (15 min),
    /// nor "queued" longer than the whole pipeline takes. Past these, the pipeline stopped
    /// without recording it (e.g. the execution itself failed), so treat it as failed
    /// instead of showing a spinner forever.
    static let runningLimit: TimeInterval = 20 * 60
    static let queuedLimit: TimeInterval = 60 * 60

    /// Status as the app should show it, with stale queued/running rows turned into failed.
    var effective: SpotStage {
        guard status == "queued" || status == "running", let updated = Self.parse(updatedAt) else { return self }
        let limit = status == "running" ? Self.runningLimit : Self.queuedLimit
        guard Date().timeIntervalSince(updated) > limit else { return self }
        return SpotStage(stage: stage, status: "failed", payload: payload,
                         error: "応答がありません（\(Int(limit / 60))分以上）", updatedAt: updatedAt)
    }

    /// Supabase timestamps carry microseconds ("2026-11-08T07:20:38.479095+00:00").
    private static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let trimmed = value.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}

extension Array where Element == SpotStage {
    /// True while any stage is still queued or running (stale ones count as failed).
    var isInProgress: Bool {
        contains { let e = $0.effective; return e.status == "queued" || e.status == "running" }
    }

    /// Stages in pipeline order (stale ones shown as failed). A stage with no row yet is
    /// shown as queued only while others are still moving; once the rest has finished it
    /// can never come, so it is shown as skipped.
    var ordered: [SpotStage] {
        let current = map(\.effective)
        let moving = current.contains { $0.status == "queued" || $0.status == "running" }
        return SpotStage.order.map { name in
            current.first { $0.stage == name }
                ?? SpotStage(stage: name, status: moving ? "queued" : "skipped", payload: nil, error: nil, updatedAt: nil)
        }
    }
}
