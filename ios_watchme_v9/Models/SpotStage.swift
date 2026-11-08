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
}

extension Array where Element == SpotStage {
    /// True while any stage is still queued or running.
    var isInProgress: Bool {
        contains { $0.status == "queued" || $0.status == "running" }
    }

    /// Stages in pipeline order, with a placeholder "queued" entry for any stage not yet written.
    var ordered: [SpotStage] {
        SpotStage.order.map { name in
            first { $0.stage == name } ?? SpotStage(stage: name, status: "queued", payload: nil, error: nil, updatedAt: nil)
        }
    }
}
