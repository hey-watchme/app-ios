//
//  DashboardTimeBlock.swift
//  ios_watchme_v9
//
//  dashboardテーブルの時間ブロックごとのデータモデル
//

import Foundation
import SwiftUI

struct DashboardTimeBlock: Codable {
    let deviceId: String
    let date: String
    let timeBlock: String  // "10-00", "10-30" など
    let summary: String?    // その時間帯の詳細説明
    let behavior: String?   // その時間帯の行動
    let vibeScore: Double?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date
        case timeBlock = "time_block"
        case summary
        case behavior
        case vibeScore = "vibe_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 表示用の時刻文字列を生成（例: "10:00"）
    var displayTime: String {
        timeBlock.replacingOccurrences(of: "-", with: ":")
    }
    
    // 時間ブロックのインデックス（0-47）を計算
    var timeIndex: Int {
        let components = timeBlock.split(separator: "-")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else { return 0 }
        
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
}