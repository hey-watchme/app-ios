//
//  SlotTimeUtility.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/07.
//

import Foundation

// スロット時刻ユーティリティクラス
class SlotTimeUtility {
    
    // MARK: - 日付から30分スロット名を生成（HH-MM形式）
    static func getSlotName(from date: Date, timezone: TimeZone? = nil) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timezone ?? TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        
        // 30分単位に調整（0-29分 → 00分、30-59分 → 30分）
        let adjustedMinute = minute < 30 ? 0 : 30
        
        return String(format: "%02d-%02d", hour, adjustedMinute)
    }
    
    // MARK: - 現在時刻のスロット名を取得（タイムゾーン考慮版）
    static func getCurrentSlot(timezone: TimeZone? = nil) -> String {
        return getSlotName(from: Date(), timezone: timezone)
    }
    
    // MARK: - 現在時刻のスロット名を取得（互換性のため残す）
    static func getCurrentSlot() -> String {
        return getCurrentSlot(timezone: nil)
    }
    
    // MARK: - 日付文字列を取得（YYYY-MM-DD形式）
    static func getDateString(from date: Date, timezone: TimeZone? = nil) -> String {
        // デバイスのローカルタイムゾーンを使用します
        // これにより、分析対象の生活時間に基づいたデータ管理が可能になります
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        // タイムゾーンが指定されていればそれを使用、なければ現在のタイムゾーン
        dateFormatter.timeZone = timezone ?? TimeZone.current
        return dateFormatter.string(from: date)
    }
    
    // MARK: - 完全なファイルパスを生成（device_id/YYYY-MM-DD/raw/HH-MM.wav）
    static func generateFilePath(deviceID: String, date: Date, timezone: TimeZone? = nil) -> String {
        let dateString = getDateString(from: date, timezone: timezone)
        let slotName = getSlotName(from: date, timezone: timezone)
        return "\(deviceID)/\(dateString)/raw/\(slotName).wav"
    }
    
    // MARK: - ファイル名からスロット名を抽出（拡張子を除去）
    static func extractSlotName(from fileName: String) -> String {
        return fileName.replacingOccurrences(of: ".wav", with: "")
    }
    
    // MARK: - 次のスロット切り替えまでの秒数を計算（タイムゾーン考慮版）
    static func getSecondsUntilNextSlot(timezone: TimeZone? = nil) -> TimeInterval {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = timezone ?? TimeZone.current
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let nanosecond = components.nanosecond ?? 0
        
        let currentMinuteInSlot = minute % 30
        let totalSecondsInCurrentSlot = Double(currentMinuteInSlot * 60 + second) + Double(nanosecond) / 1_000_000_000.0
        let secondsUntilNextSlot = (30.0 * 60.0) - totalSecondsInCurrentSlot
        
        return TimeInterval(secondsUntilNextSlot)
    }
    
    // MARK: - 次のスロット切り替えまでの秒数を計算（互換性のため残す）
    static func getSecondsUntilNextSlot() -> TimeInterval {
        return getSecondsUntilNextSlot(timezone: nil)
    }
    
    // MARK: - 次のスロット開始時刻を取得（タイムゾーン考慮版）
    static func getNextSlotStartTime(timezone: TimeZone? = nil) -> Date {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = timezone ?? TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        let minute = components.minute ?? 0
        let nextSlotMinute = minute < 30 ? 30 : 0
        let nextHour = minute < 30 ? components.hour ?? 0 : (components.hour ?? 0) + 1
        
        var nextSlotComponents = components
        nextSlotComponents.hour = nextHour
        nextSlotComponents.minute = nextSlotMinute
        nextSlotComponents.second = 0
        nextSlotComponents.nanosecond = 0
        
        // 時刻が24時を超える場合の処理
        if nextHour >= 24 {
            nextSlotComponents.hour = 0
            nextSlotComponents.day = (components.day ?? 0) + 1
        }
        
        return calendar.date(from: nextSlotComponents) ?? now
    }
    
    // MARK: - 次のスロット開始時刻を取得（互換性のため残す）
    static func getNextSlotStartTime() -> Date {
        return getNextSlotStartTime(timezone: nil)
    }
    
    // MARK: - スロット時刻のデバッグ情報を出力
    static func printSlotDebugInfo() {
        let now = Date()
        print("📅 現在時刻: \(now)")
        print("📅 現在スロット: \(getCurrentSlot())")
        print("📅 次のスロット切り替えまで: \(Int(getSecondsUntilNextSlot()))秒")
        print("📅 次のスロット開始時刻: \(getNextSlotStartTime())")
    }
}