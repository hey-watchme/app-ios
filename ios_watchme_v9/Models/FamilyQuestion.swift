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
    let subject_id: String
    let recorded_at: String?
    let local_date: String?
    let scope: String          // recording, day, person
    let kind: String           // event, raised_voice, listener, day_off
    let prompt: String
    let options: [Option]
    let context: Context?
    /// When the recording ran, filled from spot_results after reading (not a column of questions).
    var span: RecordingSpan? = nil

    private enum CodingKeys: String, CodingKey {
        case question_id, subject_id, recorded_at, local_date, scope, kind, prompt, options, context
    }

    var id: String { question_id }

    /// はい / いいえ: answered by swiping.
    var isYesNo: Bool {
        options.map(\.key) == ["yes", "no"]
    }

    /// Which recording or day the question is about. A day holds several recordings, so a bare
    /// "この録音" would not say which one: name it by its time, e.g. 7:27〜7:57 の録音.
    /// withDate: on the dashboard the questions come from every day, so the date is named too.
    func scopeName(withDate: Bool) -> String {
        switch scope {
        case "person":
            return "プロフィール"
        case "day":
            return Self.dayLabel(local_date) ?? "この日"
        default:
            guard let span else { return "この録音" }
            let date = withDate ? (Self.dayLabel(local_date).map { $0 + " " } ?? "") : ""
            return "\(date)\(span.label) の録音"
        }
    }

    /// "11/24（月）" from "2026-11-24".
    private static func dayLabel(_ localDate: String?) -> String? {
        guard let localDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: localDate) else { return nil }
        formatter.dateFormat = "M/d（E）"
        return formatter.string(from: date)
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

/// A recording's local start time and length (spot_results.local_time, profile_result.recording).
struct RecordingSpan: Equatable {
    let start: Date      // local wall-clock time, kept in a UTC calendar
    let seconds: Double?

    /// "7:27〜7:57", or "7:27〜" while the length is unknown.
    var label: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "H:mm"
        let from = formatter.string(from: start)
        guard let seconds, seconds > 0 else { return "\(from)〜" }
        return "\(from)〜\(formatter.string(from: start.addingTimeInterval(seconds)))"
    }
}
