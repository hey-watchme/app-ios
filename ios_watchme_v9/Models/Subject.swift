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
    let cognitiveType: String?
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
        case cognitiveType = "cognitive_type"
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

    // Cognitive type display data
    var cognitiveTypeData: CognitiveTypeOption? {
        guard let cognitiveType = cognitiveType else { return nil }
        return CognitiveTypeOption.allCases.first { $0.rawValue == cognitiveType }
    }
}

// MARK: - Cognitive Type Options
enum CognitiveTypeOption: String, CaseIterable, Identifiable {
    case sensorySensitive = "sensory_sensitive"
    case sensoryInsensitive = "sensory_insensitive"
    case cognitiveAnalytical = "cognitive_analytical"
    case cognitiveIntuitive = "cognitive_intuitive"
    case verbalExpressive = "verbal_expressive"
    case verbalIntrospective = "verbal_introspective"
    case behavioralImpulsive = "behavioral_impulsive"
    case behavioralDeliberate = "behavioral_deliberate"
    case emotionalStable = "emotional_stable"
    case emotionalUnstable = "emotional_unstable"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .sensorySensitive, .sensoryInsensitive:
            return "🎧"
        case .cognitiveAnalytical, .cognitiveIntuitive:
            return "🧠"
        case .verbalExpressive, .verbalIntrospective:
            return "💬"
        case .behavioralImpulsive, .behavioralDeliberate:
            return "⚡"
        case .emotionalStable, .emotionalUnstable:
            return "❤️"
        }
    }

    var categoryName: String {
        switch self {
        case .sensorySensitive, .sensoryInsensitive:
            return "感覚系"
        case .cognitiveAnalytical, .cognitiveIntuitive:
            return "認知系"
        case .verbalExpressive, .verbalIntrospective:
            return "言語系"
        case .behavioralImpulsive, .behavioralDeliberate:
            return "行動系"
        case .emotionalStable, .emotionalUnstable:
            return "情動系"
        }
    }

    var typeName: String {
        switch self {
        case .sensorySensitive:
            return "敏感型"
        case .sensoryInsensitive:
            return "鈍感型"
        case .cognitiveAnalytical:
            return "分析型"
        case .cognitiveIntuitive:
            return "直感型"
        case .verbalExpressive:
            return "表出型"
        case .verbalIntrospective:
            return "内省型"
        case .behavioralImpulsive:
            return "衝動型"
        case .behavioralDeliberate:
            return "熟考型"
        case .emotionalStable:
            return "安定型"
        case .emotionalUnstable:
            return "不安定型"
        }
    }

    var description: String {
        switch self {
        case .sensorySensitive:
            return "音や光、触覚などの感覚刺激に敏感に反応するタイプです"
        case .sensoryInsensitive:
            return "感覚刺激に対して鈍感で、気づきにくいタイプです"
        case .cognitiveAnalytical:
            return "物事を論理的・分析的に考えるタイプです"
        case .cognitiveIntuitive:
            return "直感的に理解し、全体を把握するタイプです"
        case .verbalExpressive:
            return "言葉で表現することが得意で、外に向けて発信するタイプです"
        case .verbalIntrospective:
            return "内面で深く考え、内省的なタイプです"
        case .behavioralImpulsive:
            return "素早く行動に移し、即座に反応するタイプです"
        case .behavioralDeliberate:
            return "じっくり考えてから慎重に行動するタイプです"
        case .emotionalStable:
            return "感情が安定していて、穏やかなタイプです"
        case .emotionalUnstable:
            return "感情の変動が大きく、表情豊かなタイプです"
        }
    }

    var displayName: String {
        return "\(emoji) \(categoryName)（\(typeName)）"
    }
}