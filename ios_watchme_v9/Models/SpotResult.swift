//
//  SpotResult.swift
//  ios_watchme_v9
//
//  Spot analysis result data model
//

import Foundation

// MARK: - Spot Result
// spot_results table model
struct SpotResult: Codable, Identifiable {
    let deviceId: String
    let recordedAt: String  // ISO8601 timestamp
    let localDate: String?
    let localTime: String?
    let summary: String?
    let behavior: String?
    let vibeScore: Double?
    let transcription: String?
    let createdAt: String?

    var id: String {
        "\(deviceId)_\(recordedAt)"
    }

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case recordedAt = "recorded_at"
        case localDate = "local_date"
        case localTime = "local_time"
        case summary
        case behavior
        case vibeScore = "vibe_score"
        case transcription
        case createdAt = "created_at"
    }
}

// MARK: - Spot Result with Features
// Combined data from spot_results and spot_features
struct SpotResultDetail: Identifiable {
    let spotResult: SpotResult
    let behaviorFeatures: [SEDBehaviorTimePoint]?
    let emotionFeatures: [EmotionChunk]?

    var id: String {
        spotResult.id
    }

    var deviceId: String { spotResult.deviceId }
    var recordedAt: String { spotResult.recordedAt }
    var localDate: String? { spotResult.localDate }
    var localTime: String? { spotResult.localTime }
    var summary: String? { spotResult.summary }
    var behavior: String? { spotResult.behavior }
    var vibeScore: Double? { spotResult.vibeScore }
    var transcription: String? { spotResult.transcription }
}
