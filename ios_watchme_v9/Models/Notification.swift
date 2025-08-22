//
//  Notification.swift
//  ios_watchme_v9
//
//  通知データモデル
//

import Foundation

struct Notification: Codable, Identifiable {
    let id: UUID
    let userId: UUID?
    let type: String
    let title: String
    let message: String
    var isRead: Bool
    let createdAt: Date
    let triggeredBy: String?
    let metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
        case triggeredBy = "triggered_by"
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        triggeredBy = try container.decodeIfPresent(String.self, forKey: .triggeredBy)
        
        // metadataはJSONBなので、特殊な処理が必要
        if let metadataData = try? container.decodeIfPresent(Data.self, forKey: .metadata),
           let json = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
            metadata = json
        } else {
            metadata = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(triggeredBy, forKey: .triggeredBy)
        
        if let metadata = metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            try container.encode(metadataData, forKey: .metadata)
        }
    }
}

// 通知種別
enum NotificationType: String {
    case global = "global"
    case personal = "personal"
    case event = "event"
}

// 既読記録
struct NotificationRead: Codable {
    let userId: UUID
    let notificationId: UUID
    let readAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case notificationId = "notification_id"
        case readAt = "read_at"
    }
}

// 通知表示用の拡張
extension Notification {
    // 相対時間の表示（例：5分前、1時間前、昨日など）
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // 通知タイプに応じたアイコン
    var iconName: String {
        switch type {
        case NotificationType.global.rawValue:
            return "megaphone.fill"
        case NotificationType.event.rawValue:
            return "bell.fill"
        case NotificationType.personal.rawValue:
            return "person.fill"
        default:
            // タイトルから推測
            if title.contains("分析") {
                return "chart.line.uptrend.xyaxis"
            } else if title.contains("録音") {
                return "mic.fill"
            } else if title.contains("レポート") {
                return "doc.text.fill"
            } else if title.contains("デバイス") {
                return "iphone"
            } else {
                return "bell.fill"
            }
        }
    }
}