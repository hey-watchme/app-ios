//
//  SubjectComment.swift
//  ios_watchme_v9
//
//  観測対象のコメントモデル
//

import Foundation

struct SubjectComment: Codable, Identifiable {
    let id: String
    let subjectId: String
    let userId: String
    let commentText: String
    let createdAt: String
    let userName: String?
    let userAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "comment_id"
        case subjectId = "subject_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case createdAt = "created_at"
        case userName = "user_name"
        case userAvatarUrl = "user_avatar_url"
    }
    
    // 日付のフォーマット表示用
    var formattedDate: String {
        // ISO8601形式の文字列をDateに変換
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M/d HH:mm"
            return displayFormatter.string(from: date)
        }
        return ""
    }
    
    // コメント投稿者の表示名
    var displayName: String {
        if let name = userName, !name.isEmpty {
            return name
        }
        return "名無し"
    }
}