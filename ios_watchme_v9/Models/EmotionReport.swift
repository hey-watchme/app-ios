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
    let joy: Int
    let fear: Int
    let anger: Int
    let trust: Int
    let disgust: Int
    let sadness: Int
    let surprise: Int
    let anticipation: Int
    
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
    var totalEmotions: Int {
        joy + fear + anger + trust + disgust + sadness + surprise + anticipation
    }
    
    // 最も強い感情を取得
    var dominantEmotion: (name: String, value: Int)? {
        let emotions = [
            ("Joy", joy),
            ("Fear", fear),
            ("Anger", anger),
            ("Trust", trust),
            ("Disgust", disgust),
            ("Sadness", sadness),
            ("Surprise", surprise),
            ("Anticipation", anticipation)
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
            totals.joy += point.joy
            totals.fear += point.fear
            totals.anger += point.anger
            totals.trust += point.trust
            totals.disgust += point.disgust
            totals.sadness += point.sadness
            totals.surprise += point.surprise
            totals.anticipation += point.anticipation
        }
        return totals
    }
    
    // ランキング形式で感情を取得
    var emotionRanking: [(name: String, value: Int, color: Color)] {
        let totals = emotionTotals
        let emotions: [(String, Int, Color)] = [
            ("Joy", totals.joy, Color.safeColor("EmotionJoy")),
            ("Trust", totals.trust, Color.safeColor("SuccessColor")),
            ("Anticipation", totals.anticipation, Color.safeColor("WarningColor")),
            ("Surprise", totals.surprise, Color.safeColor("EmotionSurprise")),
            ("Fear", totals.fear, Color.safeColor("AppAccentColor")),
            ("Sadness", totals.sadness, Color.safeColor("PrimaryActionColor")),
            ("Disgust", totals.disgust, Color.safeColor("EmotionDisgust")),
            ("Anger", totals.anger, Color.safeColor("ErrorColor"))
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
    var joy: Int = 0
    var fear: Int = 0
    var anger: Int = 0
    var trust: Int = 0
    var disgust: Int = 0
    var sadness: Int = 0
    var surprise: Int = 0
    var anticipation: Int = 0
}

// MARK: - Emotion Type Enum
enum EmotionType: String, CaseIterable {
    case joy = "Joy"
    case fear = "Fear"
    case anger = "Anger"
    case trust = "Trust"
    case disgust = "Disgust"
    case sadness = "Sadness"
    case surprise = "Surprise"
    case anticipation = "Anticipation"
    
    var color: Color {
        switch self {
        case .joy: return Color.safeColor("EmotionJoy")
        case .fear: return Color.safeColor("AppAccentColor")
        case .anger: return Color.safeColor("ErrorColor")
        case .trust: return Color.safeColor("SuccessColor")
        case .disgust: return Color.safeColor("EmotionDisgust")
        case .sadness: return Color.safeColor("PrimaryActionColor")
        case .surprise: return Color.safeColor("EmotionSurprise")
        case .anticipation: return Color.safeColor("WarningColor")
        }
    }
    
    // グラフ表示用の薄い色
    var lightColor: Color {
        color.opacity(0.3)
    }
}