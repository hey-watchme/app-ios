//
//  DashboardTimeBlock.swift
//  ios_watchme_v9
//
//  spot_resultsテーブルの録音ごとのデータモデル
//

import Foundation
import SwiftUI

// MARK: - Behavior Extractor Models (SED)

struct SEDBehaviorEvent: Codable, Equatable {
    let label: String
    let score: Double

    // Extract Japanese label from "Speech / 会話・発話" format
    var japaneseLabel: String {
        let parts = label.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.last ?? label
    }
}

struct SEDBehaviorTimePoint: Codable, Equatable {
    let time: Double
    let events: [SEDBehaviorEvent]
}

// MARK: - Emotion Extractor Models

struct EmotionDetail: Codable, Equatable {
    let group: String?
    let label: String
    let score: Double
    let name_en: String?
    let name_ja: String
}

struct EmotionChunk: Codable, Equatable {
    let chunk_id: Int
    let duration: Double
    let emotions: [EmotionDetail]
    let end_time: Double
    let start_time: Double
    let primary_emotion: EmotionDetail
}

// MARK: - Dashboard Time Block

struct DashboardTimeBlock: Codable, Equatable, Identifiable {
    let deviceId: String
    let date: String?  // local_dateをdateにマッピング（nullの可能性あり）
    let localTime: String?  // local_time (YYYY-MM-DD HH:MM:SS) - ✅ ユニークキー
    let summary: String?    // その録音の詳細説明
    let behavior: String?   // その録音の行動
    let emotion: String?    // LLM抽出の有意な感情（1-2個、カンマ区切り）
    let vibeScore: Double?
    let createdAt: String?
    let updatedAt: String?

    // spot_features からの追加データ（Supabaseが自動的にパースした配列）
    let behaviorTimePoints: [SEDBehaviorTimePoint]
    let emotionChunks: [EmotionChunk]

    // 表示用の時刻文字列（初期化時に1回だけ計算してキャッシュ）
    let displayTime: String

    // Identifiable conformance
    var id: String {
        "\(deviceId)_\(localTime ?? "unknown")"
    }

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date = "local_date"
        case localTime = "local_time"
        case summary
        case behavior
        case emotion
        case vibeScore = "vibe_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case behaviorTimePoints = "behavior_extractor_result"
        case emotionChunks = "emotion_extractor_result"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        deviceId = try container.decode(String.self, forKey: .deviceId)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        localTime = try container.decodeIfPresent(String.self, forKey: .localTime)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        behavior = try container.decodeIfPresent(String.self, forKey: .behavior)
        emotion = try container.decodeIfPresent(String.self, forKey: .emotion)
        vibeScore = try container.decodeIfPresent(Double.self, forKey: .vibeScore)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Supabaseが自動パースした配列を取得（失敗時は空配列）
        behaviorTimePoints = (try? container.decodeIfPresent([SEDBehaviorTimePoint].self, forKey: .behaviorTimePoints)) ?? []
        emotionChunks = (try? container.decodeIfPresent([EmotionChunk].self, forKey: .emotionChunks)) ?? []

        // displayTimeを初期化時に1回だけ計算（キャッシュ）
        displayTime = Self.calculateDisplayTime(localTime: localTime, deviceId: deviceId)
    }

    // 表示用の時刻文字列を計算（staticメソッド）
    private static func calculateDisplayTime(localTime: String?, deviceId: String) -> String {
        // ⚠️ 必ずlocal_timeを使用（UTCではなくユーザーの生活時間）
        guard let localTime = localTime else {
            print("❌ [ERROR] local_time is NULL - this should never happen!")
            print("   device_id: \(deviceId)")
            return "⚠️ ERROR"
        }

        // ISO 8601形式を試す (T区切り: YYYY-MM-DDTHH:MM:SS)
        var components = localTime.split(separator: "T")
        if components.count >= 2 {
            let timeComponents = components[1].split(separator: ":")
            if timeComponents.count >= 2 {
                return "\(timeComponents[0]):\(timeComponents[1])"
            }
        }

        // スペース区切り形式を試す (YYYY-MM-DD HH:MM:SS)
        components = localTime.split(separator: " ")
        if components.count >= 2 {
            let timeComponents = components[1].split(separator: ":")
            if timeComponents.count >= 2 {
                return "\(timeComponents[0]):\(timeComponents[1])"
            }
        }

        // パース失敗 = システムエラー
        print("❌ [ERROR] Failed to parse local_time: \(localTime)")
        print("   Expected format: YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD HH:MM:SS")
        return "⚠️ PARSE ERROR"
    }

    // 時間ブロックのインデックス（0-47）を計算
    var timeIndex: Int {
        // displayTimeから計算 (HH:MM)
        let timeComponents = displayTime.split(separator: ":")
        guard timeComponents.count == 2,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else { return 0 }

        return hour * 2 + (minute >= 30 ? 1 : 0)
    }
    
    // スコアによる色の判定
    var scoreColor: Color {
        guard let score = vibeScore else {
            return Color.safeColor("BehaviorTextTertiary")
        }

        if score > 10 {
            return Color.safeColor("SuccessColor")
        } else if score < -10 {
            return Color.safeColor("ErrorColor")
        } else {
            return Color.safeColor("BorderLight")
        }
    }

    // MARK: - Aggregated Data for Display

    /// Top behaviors aggregated from all time points (sorted by average score)
    var topBehaviors: [(label: String, score: Double)] {
        let timePoints = behaviorTimePoints
        guard !timePoints.isEmpty else { return [] }

        // Collect all events across all time points
        var eventScores: [String: [Double]] = [:]

        for point in timePoints {
            for event in point.events {
                // Use translated label from BehaviorEventType
                let translatedLabel = translateBehaviorLabel(event.label)
                eventScores[translatedLabel, default: []].append(event.score)
            }
        }

        // Calculate average score for each label
        let averaged = eventScores.map { (label, scores) -> (label: String, score: Double) in
            let avgScore = scores.reduce(0.0, +) / Double(scores.count)
            return (label, avgScore)
        }

        // Filter by minimum threshold (0.1) and sort by score
        return averaged
            .filter { $0.score > 0.1 }
            .sorted { $0.score > $1.score }
    }

    // Translate behavior label using BehaviorEventType
    private func translateBehaviorLabel(_ label: String) -> String {
        // Extract English part from "Speech / 会話・発話" format
        let englishLabel = label.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? label
        return BehaviorEventType(rawValue: englishLabel)?.displayName ?? englishLabel
    }

    /// Top emotions aggregated from all chunks (sorted by average score)
    var topEmotions: [(name: String, score: Double)] {
        let chunks = emotionChunks
        guard !chunks.isEmpty else { return [] }

        // Collect all emotions across all chunks
        var emotionScores: [String: [Double]] = [:]

        for chunk in chunks {
            for emotion in chunk.emotions {
                emotionScores[emotion.name_ja, default: []].append(emotion.score)
            }
        }

        // Calculate average score for each emotion
        let averaged = emotionScores.map { (name, scores) -> (name: String, score: Double) in
            let avgScore = scores.reduce(0.0, +) / Double(scores.count)
            return (name, avgScore)
        }

        // Filter by minimum threshold and sort by score
        return averaged
            .filter { $0.score > 0.1 }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Direct Initializer for Performance Optimization

    /// Direct initializer to avoid JSON encoding/decoding overhead
    init(deviceId: String,
         localDate: String?,
         localTime: String?,
         summary: String?,
         behavior: String?,
         emotion: String?,
         vibeScore: Double?,
         createdAt: String?,
         updatedAt: String? = nil,
         behaviorTimePoints: [SEDBehaviorTimePoint],
         emotionChunks: [EmotionChunk]) {

        self.deviceId = deviceId
        self.date = localDate
        self.localTime = localTime
        self.summary = summary
        self.behavior = behavior
        self.emotion = emotion
        self.vibeScore = vibeScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.behaviorTimePoints = behaviorTimePoints
        self.emotionChunks = emotionChunks

        // Calculate displayTime
        self.displayTime = Self.calculateDisplayTime(localTime: localTime, deviceId: deviceId)
    }
}