//
//  DashboardTimeBlock.swift
//  ios_watchme_v9
//
//  spot_resultsテーブルの録音ごとのデータモデル
//

import Foundation
import SwiftUI

struct DashboardTimeBlock: Codable, Equatable {
    let deviceId: String
    let date: String?  // local_dateをdateにマッピング（nullの可能性あり）
    let recordedAt: String?  // recorded_at (UTC)（nullの可能性あり）
    let localTime: String?  // local_time (YYYY-MM-DD HH:MM:SS)
    let summary: String?    // その録音の詳細説明
    let behavior: String?   // その録音の行動
    let vibeScore: Double?
    let createdAt: String?
    let updatedAt: String?

    // 表示用の時刻文字列（初期化時に1回だけ計算してキャッシュ）
    let displayTime: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date = "local_date"
        case recordedAt = "recorded_at"
        case localTime = "local_time"
        case summary
        case behavior
        case vibeScore = "vibe_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        deviceId = try container.decode(String.self, forKey: .deviceId)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        recordedAt = try container.decodeIfPresent(String.self, forKey: .recordedAt)
        localTime = try container.decodeIfPresent(String.self, forKey: .localTime)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        behavior = try container.decodeIfPresent(String.self, forKey: .behavior)
        vibeScore = try container.decodeIfPresent(Double.self, forKey: .vibeScore)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // displayTimeを初期化時に1回だけ計算（キャッシュ）
        displayTime = Self.calculateDisplayTime(localTime: localTime, recordedAt: recordedAt, deviceId: deviceId)
    }

    // 表示用の時刻文字列を計算（staticメソッド）
    private static func calculateDisplayTime(localTime: String?, recordedAt: String?, deviceId: String) -> String {
        // ⚠️ 必ずlocal_timeを使用（UTCではなくユーザーの生活時間）
        guard let localTime = localTime else {
            print("❌ [ERROR] local_time is NULL - this should never happen!")
            print("   device_id: \(deviceId)")
            print("   recorded_at: \(recordedAt ?? "nil")")
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
}