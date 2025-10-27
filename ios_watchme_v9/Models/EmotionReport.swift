//
//  EmotionReport.swift
//  ios_watchme_v9
//
//  Created by Claude Code on 2025/07/27.
//

import Foundation
import SwiftUI

// MARK: - Emotion Time Point Model
struct EmotionTimePoint: Codable {
    let time: String
    let neutral: Double
    let joy: Double
    let anger: Double
    let sadness: Double

    // 時刻を表示用にフォーマット
    var displayTime: String {
        time // "00:00" format already
    }

    // 時刻を数値に変換（グラフ描画用）
    var timeValue: Double {
        let components = time.split(separator: ":")
        guard components.count == 2,
              let hour = Double(components[0]),
              let minute = Double(components[1]) else {
            return 0
        }
        return hour + (minute / 60.0)
    }

    // 全感情の合計値
    var totalEmotions: Double {
        neutral + joy + anger + sadness
    }

    // 最も強い感情を取得
    var dominantEmotion: (name: String, value: Double)? {
        let emotions = [
            ("Neutral", neutral),
            ("Joy", joy),
            ("Anger", anger),
            ("Sadness", sadness)
        ]
        return emotions.max(by: { $0.1 < $1.1 })
    }
}

// MARK: - Emotion Report Model
struct EmotionReport: Codable {
    let deviceId: String
    let date: String
    let emotionGraph: [EmotionTimePoint]
    let filePath: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date
        case emotionGraph = "emotion_graph"
        case filePath = "file_path"
        case createdAt = "created_at"
    }
    
    // 日付をフォーマット表示
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dateObj = formatter.date(from: date) {
            formatter.dateFormat = "MMMM d, yyyy"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: dateObj)
        }
        return date
    }
    
    // 感情ごとの1日の合計値を計算
    var emotionTotals: EmotionTotals {
        var totals = EmotionTotals()
        for point in emotionGraph {
            totals.neutral += point.neutral
            totals.joy += point.joy
            totals.anger += point.anger
            totals.sadness += point.sadness
        }
        return totals
    }

    // ランキング形式で感情を取得
    var emotionRanking: [(name: String, value: Double, color: Color)] {
        let totals = emotionTotals
        let emotions: [(String, Double, Color)] = [
            ("中立", totals.neutral, Color.safeColor("EmotionNeutral")),
            ("喜び", totals.joy, Color.safeColor("EmotionJoy")),
            ("怒り", totals.anger, Color.safeColor("ErrorColor")),
            ("悲しみ", totals.sadness, Color.safeColor("PrimaryActionColor"))
        ]
        return emotions.sorted(by: { $0.1 > $1.1 })
    }
    
    // データがある時間帯のみ取得
    var activeTimePoints: [EmotionTimePoint] {
        emotionGraph.filter { $0.totalEmotions > 0 }
    }
}

// MARK: - Emotion Totals
struct EmotionTotals {
    var neutral: Double = 0.0
    var joy: Double = 0.0
    var anger: Double = 0.0
    var sadness: Double = 0.0
}

// MARK: - Emotion Type Enum
enum EmotionType: String, CaseIterable {
    case joy = "Joy"
    case neutral = "Neutral"
    case anger = "Anger"
    case sadness = "Sadness"

    // 日本語表示名
    var displayName: String {
        switch self {
        case .neutral: return "中立"
        case .joy: return "喜び"
        case .anger: return "怒り"
        case .sadness: return "悲しみ"
        }
    }

    var color: Color {
        switch self {
        case .neutral: return Color.safeColor("EmotionNeutral")
        case .joy: return Color.safeColor("EmotionJoy")
        case .anger: return Color.safeColor("ErrorColor")
        case .sadness: return Color.safeColor("PrimaryActionColor")
        }
    }

    // グラフ表示用の薄い色
    var lightColor: Color {
        color.opacity(0.3)
    }
}