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

    /// Stages in the order their results usually arrive, as shown on the card.
    /// Sound events run alongside measure and scene and usually finish after them (platform
    /// infra/envs/stg/pipeline.tf). Vocal emotion ("emotion") was removed on 2026-11-12;
    /// older recordings still have its row, which is not shown.
    static let order = ["transcribe", "measure", "scene", "sound_events", "events", "profile", "day_so_far"]

    static let labels: [String: String] = [
        "transcribe": "文字起こし",
        "sound_events": "周りの音",
        "measure": "会話の指標",
        "scene": "場面",
        "events": "出来事",
        "emotion": "声の表情",
        "profile": "分析",
        "day_so_far": "1日の分析",
    ]

    var label: String { Self.labels[stage] ?? stage }

    /// Name of the day's running analysis (day_so_far) for a given local date:
    /// "今日の分析" for today, "11/6 の分析" for another day, "1日の分析" when the date is unknown.
    static func dayAnalysisLabel(for localDate: String?, timezone: TimeZone = .current) -> String {
        guard let localDate else { return "1日の分析" }
        if localDate == LocalDate.today(timezone: timezone) { return "今日の分析" }
        let parts = localDate.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return "1日の分析" }
        return "\(month)/\(day) の分析"
    }

    /// A stage cannot legitimately stay "running" longer than a Lambda can run (15 min),
    /// nor "queued" longer than the whole pipeline takes. Past these, the pipeline stopped
    /// without recording it (e.g. the execution itself failed), so treat it as failed
    /// instead of showing a spinner forever.
    static let runningLimit: TimeInterval = 20 * 60
    static let queuedLimit: TimeInterval = 60 * 60
    /// Heavy stages wait in a work queue and may legitimately sit there for hours when many
    /// chunks arrive at once. These match the pipeline's task timeouts (platform infra/envs/stg/queues.tf).
    static let queuedLimitByStage: [String: TimeInterval] = [
        "sound_events": 3 * 60 * 60,
    ]

    /// Status as the app should show it, with stale queued/running rows turned into failed.
    var effective: SpotStage {
        guard status == "queued" || status == "running", let updated = Self.parse(updatedAt) else { return self }
        let limit = status == "running" ? Self.runningLimit : (Self.queuedLimitByStage[stage] ?? Self.queuedLimit)
        guard Date().timeIntervalSince(updated) > limit else { return self }
        return SpotStage(stage: stage, status: "failed", payload: payload,
                         error: "応答がありません（\(Int(limit / 60))分以上）", updatedAt: updatedAt)
    }

    /// Supabase timestamps carry microseconds ("2026-11-08T07:20:38.479095+00:00").
    static func parse(_ value: String?) -> Date? {
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
