//
//  Subject.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/28.
//

import Foundation

// MARK: - Subject Model
struct Subject: Codable, Equatable {
    let subjectId: String
    let name: String?
    let age: Int?
    let gender: String?
    let avatarUrl: String?
    let notes: String?
    let prefecture: String?
    let city: String?
    let createdByUserId: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case subjectId = "subject_id"
        case name
        case age
        case gender
        case avatarUrl = "avatar_url"
        case notes
        case prefecture
        case city
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 年齢と性別を組み合わせた表示文字列
    var ageGenderDisplay: String? {
        var parts: [String] = []
        
        if let age = age {
            parts.append("\(age)歳")
        }
        
        if let gender = gender {
            parts.append(gender)
        }
        
        return parts.isEmpty ? nil : parts.joined(separator:"・")
    }
    
    // 観測対象の情報が設定されているかどうか
    var hasMetadata: Bool {
        return name != nil || age != nil || gender != nil
    }

    // Location display string
    var locationDisplay: String? {
        if let city = city, !city.isEmpty {
            return city
        } else if let prefecture = prefecture, !prefecture.isEmpty {
            return prefecture
        }
        return nil
    }
}