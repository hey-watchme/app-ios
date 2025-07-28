//
//  DeviceMetadata.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/28.
//

import Foundation

// MARK: - Device Metadata Model
struct DeviceMetadata: Codable {
    let deviceId: String
    let name: String?
    let age: Int?
    let gender: String?
    let avatarUrl: String?
    let notes: String?
    let updatedByAccountId: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case name
        case age
        case gender
        case avatarUrl = "avatar_url"
        case notes
        case updatedByAccountId = "updated_by_account_id"
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
}