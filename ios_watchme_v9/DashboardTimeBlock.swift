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

// MARK: - Scene Mapping Model (from profile_result)

struct SceneMapping: Codable, Equatable {
    let participants: String?
    let core_activity: String?
    let behavior_detail: String?
    let atmosphere: String?
    let uncertainty: String?

    enum CodingKeys: String, CodingKey {
        case participants
        case core_activity
        case behavior_detail
        case atmosphere
        case uncertainty
    }
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
    let rating: Int?        // Importance rating (0-5)
    let createdAt: String?
    let updatedAt: String?

    // profile_result fields (scene_mapping, analysis)
    let sceneMapping: SceneMapping?
    let analysis: String?

    // spot_features からの追加データ（Supabaseが自動的にパースした配列）
    let vibeTranscriberResult: String?  // 文字起こし結果（"発話なし" or 実際のテキスト）
    let behaviorTimePoints: [SEDBehaviorTimePoint]
    let emotionChunks: [EmotionChunk]
    let emotionFeaturesResultHumeRaw: String?  // SER raw JSON (Hume API) for debug display
    let sceneDescriptionRaw: String?  // Acoustic scene description (Gemini) for debug display
    let audioKey: String?  // S3 key of the recording (development playback)
    let metricsRaw: String?  // Fixed measurements (profile_result.metrics) as JSON
    let vocalEmotionRaw: String?  // emotion2vec scores (profile_result.vocal_emotion) as JSON
    let stages: [SpotStage]  // per-stage progress (spot_stages); empty for old recordings
    let recordedAt: String?  // spot_results.recorded_at (UTC); keys the events of this recording
    let recordingRaw: String?  // profile_result.recording (session, chunk sequence, duration) as JSON
    let llmModel: String?  // model that wrote the analysis (spot_results.llm_model)

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
        case rating
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case vibeTranscriberResult = "vibe_transcriber_result"
        case behaviorTimePoints = "behavior_extractor_result"
        case emotionChunks = "emotion_extractor_result"
        case emotionFeaturesResultHumeRaw = "emotion_features_result_hume"
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
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // scene_mapping and analysis are not used via Codable path (injected via direct init)
        sceneMapping = nil
        analysis = nil

        // Supabaseが自動パースした配列とテキストを取得（失敗時は空配列/nil）
        vibeTranscriberResult = try? container.decodeIfPresent(String.self, forKey: .vibeTranscriberResult)
        behaviorTimePoints = (try? container.decodeIfPresent([SEDBehaviorTimePoint].self, forKey: .behaviorTimePoints)) ?? []
        emotionChunks = (try? container.decodeIfPresent([EmotionChunk].self, forKey: .emotionChunks)) ?? []
        // emotion_features_result_hume is JSONB with arbitrary structure - decode via JSONValue and convert to string
        if let jsonVal = try? container.decodeIfPresent(JSONValue.self, forKey: .emotionFeaturesResultHumeRaw) {
            emotionFeaturesResultHumeRaw = jsonVal.prettyPrinted
        } else {
            emotionFeaturesResultHumeRaw = nil
        }
        sceneDescriptionRaw = nil
        audioKey = nil
        metricsRaw = nil
        vocalEmotionRaw = nil
        stages = []
        recordedAt = nil
        recordingRaw = nil
        llmModel = nil

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
         rating: Int? = nil,
         createdAt: String?,
         updatedAt: String? = nil,
         sceneMapping: SceneMapping? = nil,
         analysis: String? = nil,
         vibeTranscriberResult: String? = nil,
         behaviorTimePoints: [SEDBehaviorTimePoint],
         emotionChunks: [EmotionChunk],
         emotionFeaturesResultHumeRaw: String? = nil,
         sceneDescriptionRaw: String? = nil,
         audioKey: String? = nil,
         metricsRaw: String? = nil,
         vocalEmotionRaw: String? = nil,
         stages: [SpotStage] = [],
         recordedAt: String? = nil,
         recordingRaw: String? = nil,
         llmModel: String? = nil) {

        self.deviceId = deviceId
        self.date = localDate
        self.localTime = localTime
        self.summary = summary
        self.behavior = behavior
        self.emotion = emotion
        self.vibeScore = vibeScore
        self.rating = rating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sceneMapping = sceneMapping
        self.analysis = analysis
        self.vibeTranscriberResult = vibeTranscriberResult
        self.behaviorTimePoints = behaviorTimePoints
        self.emotionChunks = emotionChunks
        self.emotionFeaturesResultHumeRaw = emotionFeaturesResultHumeRaw
        self.sceneDescriptionRaw = sceneDescriptionRaw
        self.audioKey = audioKey
        self.metricsRaw = metricsRaw
        self.vocalEmotionRaw = vocalEmotionRaw
        self.stages = stages
        self.recordedAt = recordedAt
        self.recordingRaw = recordingRaw
        self.llmModel = llmModel

        // Calculate displayTime
        self.displayTime = Self.calculateDisplayTime(localTime: localTime, deviceId: deviceId)
    }
}
// MARK: - Transcript and scene (shared by the result card and the detail view)

extension DashboardTimeBlock {
    struct ConversationTurn: Identifiable {
        let id: Int
        let speaker: String?
        let text: String
    }

    var transcriptObject: [String: Any]? {
        guard let raw = vibeTranscriberResult, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Splits the stored transcription ("SPEAKER S1: ...\nSPEAKER S2: ...") into turns.
    var conversationTurns: [ConversationTurn] {
        guard let text = transcriptObject?["transcription"] as? String else { return [] }
        let prefix = "SPEAKER "
        return text.split(separator: "\n").enumerated().compactMap { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            if line.hasPrefix(prefix), let colon = line.firstIndex(of: ":") {
                let speaker = String(line[line.index(line.startIndex, offsetBy: prefix.count)..<colon])
                let body = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                return ConversationTurn(id: index, speaker: speaker, text: body)
            }
            return ConversationTurn(id: index, speaker: nil, text: line)
        }
    }

    private var sceneObject: [String: Any]? {
        guard let raw = sceneDescriptionRaw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["scene"] as? [String: Any]
    }

    /// Who each speaker label sounds like, estimated from the voice by the scene stage (e.g. "S1" -> "子ども").
    var speakerRoles: [String: String] {
        guard let roles = sceneObject?["speaker_roles"] as? [[String: Any]] else { return [:] }
        var result: [String: String] = [:]
        for entry in roles {
            if let label = entry["label"] as? String, let role = entry["role"] as? String {
                result[label] = role
            }
        }
        return result
    }

    /// One or two sentences describing the scene (scene stage).
    var sceneSummary: String? {
        guard let summary = sceneObject?["summary"] as? String, !summary.isEmpty else { return nil }
        return summary
    }

    /// A field of a stage's progress payload. While the pipeline runs, these short previews
    /// are all there is; the full results arrive when Persist writes the recording.
    func stagePayload(_ stage: String, _ key: String) -> String? {
        guard case .object(let payload)? = stages.first(where: { $0.stage == stage })?.payload,
              case .string(let value)? = payload[key], !value.isEmpty else { return nil }
        return value
    }
}
