//
//  DashboardSummary.swift
//  ios_watchme_v9
//
//  Dashboard Summaryテーブルのデータモデル
//

import Foundation

// MARK: - Dashboard Summary Data Model
// dashboard_summaryテーブルの構造に対応したデータモデル
struct DashboardSummary: Codable {
    let deviceId: UUID
    let date: String
    // JSONB型は様々な形式を取る可能性があるため、デコードを試みるがエラーは無視
    let processedCount: Int?
    let lastTimeBlock: String?
    let createdAt: String?
    let updatedAt: String?
    let averageVibe: Float?  // 新しい平均スコアカラム（今回使用する主要フィールド）
    let vibeScores: [Double?]?
    let analysisResult: AnalysisResult?  // cumulative_evaluationを含むJSONBフィールド
    
    // CodingKeysでSnake caseとCamel caseを変換
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date
        case processedCount = "processed_count"
        case lastTimeBlock = "last_time_block"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case averageVibe = "average_vibe"
        case vibeScores = "vibe_scores"
        case analysisResult = "analysis_result"
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
        vibeScores = try container.decodeIfPresent([Double?].self, forKey: .vibeScores)
        analysisResult = try container.decodeIfPresent(AnalysisResult.self, forKey: .analysisResult)
        
        // prompt, insightsなどの他のJSONBフィールドは
        // 将来的に使用する際に別途処理を追加
    }
}

// MARK: - Analysis Result
// analysis_result JSONBフィールドの構造
struct AnalysisResult: Codable {
    let cumulativeEvaluation: [String]?
    
    enum CodingKeys: String, CodingKey {
        case cumulativeEvaluation = "cumulative_evaluation"
    }
    
    // カスタムデコーダーで柔軟に処理
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // cumulative_evaluationが文字列、配列、nullのいずれかに対応
        if let stringValue = try? container.decode(String.self, forKey: .cumulativeEvaluation) {
            // 文字列の場合、改行で分割または単一要素の配列として扱う
            if stringValue.contains("\n") {
                self.cumulativeEvaluation = stringValue.components(separatedBy: "\n").filter { !$0.isEmpty }
            } else {
                self.cumulativeEvaluation = [stringValue]
            }
        } else if let arrayValue = try? container.decode([String].self, forKey: .cumulativeEvaluation) {
            // 配列の場合はそのまま使用
            self.cumulativeEvaluation = arrayValue
        } else {
            // nullまたはデコードできない場合
            self.cumulativeEvaluation = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(cumulativeEvaluation, forKey: .cumulativeEvaluation)
    }
}

// MARK: - 将来の拡張用
// prompt, insightsなどの他のJSONBフィールドは
// 実際に使用する際に適切な型定義を追加予定