//
//  WeeklyResults.swift
//  ios_watchme_v9
//
//  Weekly analysis results model
//

import Foundation

// MARK: - Weekly Results Model
struct WeeklyResults: Codable, Identifiable {
    var id: String { "\(deviceId)_\(weekStartDate)" }

    let deviceId: String
    let weekStartDate: String  // YYYY-MM-DD (Monday)
    let summary: String?  // Week summary in Japanese
    let memorableEvents: [MemorableEvent]?  // Top 5 memorable events
    let profileResult: [String: AnyCodable]?  // Full LLM response (JSONB)
    let processedCount: Int?  // Number of recordings analyzed
    let llmModel: String?
    let createdAt: String?  // Keep as String to avoid date parsing issues

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case weekStartDate = "week_start_date"
        case summary
        case memorableEvents = "memorable_events"
        case profileResult = "profile_result"
        case processedCount = "processed_count"
        case llmModel = "llm_model"
        case createdAt = "created_at"
    }
}

// MARK: - Memorable Event Model
struct MemorableEvent: Codable, Identifiable {
    var id: Int { rank }

    let rank: Int
    let date: String  // YYYY-MM-DD
    let time: String  // HH:MM
    let dayOfWeek: String  // 月/火/水/木/金/土/日
    let eventSummary: String  // Japanese description
    let transcriptionSnippet: String

    enum CodingKeys: String, CodingKey {
        case rank
        case date
        case time
        case dayOfWeek = "day_of_week"
        case eventSummary = "event_summary"
        case transcriptionSnippet = "transcription_snippet"
    }
}

// MARK: - AnyCodable (for JSONB decoding)
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        case let array as [AnyCodable]:
            try container.encode(array)
        default:
            try container.encodeNil()
        }
    }
}
