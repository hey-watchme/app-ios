//
//  FamilyQuestion.swift
//  ios_watchme_v9
//
//  A question the analysis could not settle, for the family to answer with one tap
//  (platform docs/product/questions.md). Rows of the `questions` table; the app reads the
//  open ones and answers through POST /questions/answers.
//

import Foundation

struct FamilyQuestion: Decodable, Identifiable, Equatable {
    struct Option: Decodable, Equatable {
        let key: String
        let label: String
    }

    struct Context: Decodable, Equatable {
        let quote: String?
        let start_sec: Double?
        let who: String?
        let audio_key: String?
    }

    let question_id: String
    let device_id: String
    let recorded_at: String?
    let local_date: String?
    let scope: String          // recording, day, person
    let kind: String           // event, raised_voice, listener, day_off
    let prompt: String
    let options: [Option]
    let context: Context?

    var id: String { question_id }

    /// はい / いいえ: answered by swiping.
    var isYesNo: Bool {
        options.map(\.key) == ["yes", "no"]
    }

    var scopeName: String {
        switch scope {
        case "person": return "プロフィール"
        case "day": return "この日"
        default: return "この録音"
        }
    }

    var topicName: String {
        switch kind {
        case "event": return "出来事"
        case "raised_voice": return "声の様子"
        case "day_off": return "予定"
        default: return scope == "person" ? "家族のこと" : "確認"
        }
    }

    /// "12:34" from the start of the recording, when the question is about a moment.
    var clock: String? {
        guard let seconds = context?.start_sec, seconds >= 0 else { return nil }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
