//
//  Message.swift
//  ios_watchme_v9
//
//  お問い合わせ・通報メッセージモデル
//

import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let createdAt: String
    let userId: String
    let category: MessageCategory
    let messageBody: String
    let contextType: MessageContextType?
    let targetCommentId: String?
    let targetUserId: String?
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
    let status: MessageStatus

    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case createdAt = "created_at"
        case userId = "user_id"
        case category = "category"
        case messageBody = "message_body"
        case contextType = "context_type"
        case targetCommentId = "target_comment_id"
        case targetUserId = "target_user_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case status = "status"
    }
}

// メッセージカテゴリ
enum MessageCategory: String, Codable, CaseIterable {
    case inquiry = "inquiry"                 // お問い合わせ
    case feedback = "feedback"               // ご意見・ご要望
    case bugReport = "bug_report"            // バグの報告
    case reportContent = "report_content"    // 不適切なコンテンツの通報
    case other = "other"                     // その他

    var displayName: String {
        switch self {
        case .inquiry:
            return "お問い合わせ"
        case .feedback:
            return "ご意見・ご要望"
        case .bugReport:
            return "バグの報告"
        case .reportContent:
            return "不適切なコンテンツの通報"
        case .other:
            return "その他"
        }
    }
}

// コンテキストタイプ
enum MessageContextType: String, Codable {
    case general = "general"     // 一般
    case comment = "comment"     // コメント通報
    case user = "user"           // ユーザー通報（将来用）
    case bug = "bug"             // バグ
}

// メッセージステータス
enum MessageStatus: String, Codable {
    case pending = "pending"         // 未対応
    case inProgress = "in_progress"  // 対応中
    case resolved = "resolved"       // 解決済み
    case dismissed = "dismissed"     // 却下
}

// フィードバック送信用のリクエストモデル
struct FeedbackRequest: Codable {
    let userId: String
    let category: String
    let messageBody: String
    let contextType: String?
    let targetCommentId: String?
    let targetUserId: String?
    let appVersion: String
    let osVersion: String
    let deviceModel: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case category = "category"
        case messageBody = "message_body"
        case contextType = "context_type"
        case targetCommentId = "target_comment_id"
        case targetUserId = "target_user_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceModel = "device_model"
    }
}
