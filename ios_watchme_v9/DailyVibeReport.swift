//
//  DailyVibeReport.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import Foundation

// MARK: - Daily Vibe Report Data Model
// vibe_whisper_summaryテーブルの構造に対応したデータモデル
struct DailyVibeReport: Codable {
    let deviceId: String
    let date: String
    let vibeScores: [Double?]?  // 配列形式に変更（48要素の配列）
    let averageScore: Double
    let positiveHours: Double
    let negativeHours: Double
    let neutralHours: Double
    let insights: [String]
    let vibeChanges: [VibeChange]?
    let processedAt: String?  // 一旦Stringで受け取る
    let processingLog: ProcessingLog?
    
    // CodingKeysでSnake caseとCamel caseを変換
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date
        case vibeScores = "vibe_scores"
        case averageScore = "average_score"
        case positiveHours = "positive_hours"
        case negativeHours = "negative_hours"
        case neutralHours = "neutral_hours"
        case insights
        case vibeChanges = "vibe_changes"
        case processedAt = "processed_at"
        case processingLog = "processing_log"
    }
}


// MARK: - Vibe Change
// Vibeの変化情報を表す構造体
struct VibeChange: Codable {
    let time: String
    let event: String
    let score: Double
}

// MARK: - Processing Log
// 処理ログ情報を格納する構造体（実際のデータに合わせて簡略化）
struct ProcessingLog: Codable {
    // 必要に応じて後で追加
}

// MARK: - Helper Extensions
extension DailyVibeReport {
    // 感情の割合を計算するヘルパープロパティ
    var totalHours: Double {
        positiveHours + negativeHours + neutralHours
    }
    
    var positivePercentage: Double {
        guard totalHours > 0 else { return 0 }
        return (positiveHours / totalHours) * 100
    }
    
    var negativePercentage: Double {
        guard totalHours > 0 else { return 0 }
        return (negativeHours / totalHours) * 100
    }
    
    var neutralPercentage: Double {
        guard totalHours > 0 else { return 0 }
        return (neutralHours / totalHours) * 100
    }
    
    // インサイトの最初の3つを取得（UIで表示する際に便利）
    var topInsights: [String] {
        Array(insights.prefix(3))
    }
}