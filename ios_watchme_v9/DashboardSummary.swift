//
//  DashboardSummary.swift
//  ios_watchme_v9
//
//  Dashboard Summaryテーブルのデータモデル
//

import Foundation

// MARK: - Vibe Score Data Point
// vibe_scores配列の各要素の構造
struct VibeScoreDataPoint: Codable, Equatable {
    let time: String  // HH:MM format
    let score: Double  // Vibe score

    enum CodingKeys: String, CodingKey {
        case time
        case score
    }
}

// MARK: - Dashboard Summary Data Model
// daily_resultsテーブルの構造に対応したデータモデル
struct DashboardSummary: Codable {
    let deviceId: UUID
    let date: String  // local_dateをdateとしてマッピング（既存コードとの互換性のため）
    // JSONB型は様々な形式を取る可能性があるため、デコードを試みるがエラーは無視
    let processedCount: Int?
    let lastTimeBlock: String?
    let createdAt: String?
    let updatedAt: String?
    let averageVibe: Float?  // vibe_scoreカラム（平均スコア）
    let vibeScores: [VibeScoreDataPoint]?  // Time-based vibe scores (not 48-block based)
    let analysisResult: AnalysisResult?  // profile_resultを含むJSONBフィールド
    let insights: String?  // summaryカラム: 1日のサマリーインサイト
    let burstEvents: [BurstEvent]?  // burst_eventsカラム: バーストイベント配列

    // CodingKeysでSnake caseとCamel caseを変換
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date = "local_date"  // daily_resultsのlocal_dateカラムをdateにマッピング
        case processedCount = "processed_count"
        case lastTimeBlock = "last_time_block"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case averageVibe = "vibe_score"  // daily_resultsのvibe_scoreカラム
        case vibeScores = "vibe_scores"
        case analysisResult = "profile_result"  // daily_resultsのprofile_resultカラム
        case insights = "summary"  // daily_resultsのsummaryカラム
        case burstEvents = "burst_events"
    }
    
    // Manual initializer for creating placeholder data
    init(deviceId: UUID, date: String, processedCount: Int?, lastTimeBlock: String?, createdAt: String?, updatedAt: String?, averageVibe: Float?, vibeScores: [VibeScoreDataPoint]?, analysisResult: AnalysisResult?, insights: String?, burstEvents: [BurstEvent]?) {
        self.deviceId = deviceId
        self.date = date
        self.processedCount = processedCount
        self.lastTimeBlock = lastTimeBlock
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.averageVibe = averageVibe
        self.vibeScores = vibeScores
        self.analysisResult = analysisResult
        self.insights = insights
        self.burstEvents = burstEvents
    }

    // カスタムデコーダーで、JSONB型のフィールドをスキップしつつ必要なフィールドだけ取得
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        deviceId = try container.decode(UUID.self, forKey: .deviceId)
        date = try container.decode(String.self, forKey: .date)
        processedCount = try container.decodeIfPresent(Int.self, forKey: .processedCount)
        lastTimeBlock = try container.decodeIfPresent(String.self, forKey: .lastTimeBlock)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        averageVibe = try container.decodeIfPresent(Float.self, forKey: .averageVibe)
        vibeScores = try container.decodeIfPresent([VibeScoreDataPoint].self, forKey: .vibeScores)
        analysisResult = try container.decodeIfPresent(AnalysisResult.self, forKey: .analysisResult)
        insights = try container.decodeIfPresent(String.self, forKey: .insights)
        burstEvents = try container.decodeIfPresent([BurstEvent].self, forKey: .burstEvents)
    }
}

// MARK: - Burst Event
// burst_events JSONBフィールドの構造
struct BurstEvent: Codable {
    let time: String  // HH:MM format
    let event: String  // Event description
    let scoreChange: Double  // Score change from previous recording

    enum CodingKeys: String, CodingKey {
        case time
        case event
        case scoreChange = "score_change"
    }
}

// MARK: - Analysis Result
// profile_result JSONBフィールドの構造（2-layer nested structure）
struct AnalysisResult: Codable {
    let summary: String?
    let behavior: String?
    let vibeScore: Int?
    let profileResult: ProfileResultDetails?

    enum CodingKeys: String, CodingKey {
        case summary
        case behavior
        case vibeScore = "vibe_score"
        case profileResult = "profile_result"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        summary = try? container.decodeIfPresent(String.self, forKey: .summary)
        behavior = try? container.decodeIfPresent(String.self, forKey: .behavior)
        vibeScore = try? container.decodeIfPresent(Int.self, forKey: .vibeScore)
        profileResult = try? container.decodeIfPresent(ProfileResultDetails.self, forKey: .profileResult)
    }
}

// MARK: - Profile Result Details
// Nested profile_result details structure
struct ProfileResultDetails: Codable {
    let dailyTrend: String?
    let keyMoments: [String]?
    let emotionalStability: String?

    enum CodingKeys: String, CodingKey {
        case dailyTrend = "daily_trend"
        case keyMoments = "key_moments"
        case emotionalStability = "emotional_stability"
    }
}

// MARK: - Daily Vibe Score (Weekly Report)
// Weekly mood chart data (one entry per day)
struct DailyVibeScore: Codable {
    let localDate: String  // "2025-11-19" format
    let vibeScore: Double  // Daily average vibe score

    enum CodingKeys: String, CodingKey {
        case localDate = "local_date"
        case vibeScore = "vibe_score"
    }
}

// MARK: - 将来の拡張用
// prompt, insightsなどの他のJSONBフィールドは
// 実際に使用する際に適切な型定義を追加予定