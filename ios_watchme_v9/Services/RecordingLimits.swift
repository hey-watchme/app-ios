//
//  RecordingLimits.swift
//  ios_watchme_v9
//
//  How long one recording may run. The value lives on the server (public.app_config,
//  key "recording_max_minutes") so it can change without an app release; the app keeps
//  the last value it read and falls back to `defaultMinutes`.
//  Change it with: update public.app_config set value = '30' where key = 'recording_max_minutes';
//

import Foundation
import Supabase

enum RecordingLimits {
    /// Used until the server's value has been read once (2026-11-23: 30 minutes).
    static let defaultMinutes = 30
    /// Values outside this range are ignored, so a typo cannot stop recording altogether.
    static let allowedMinutes = 1...180

    private static let storageKey = "recording_max_minutes"

    static var maxMinutes: Int {
        let saved = UserDefaults.standard.integer(forKey: storageKey)
        return allowedMinutes.contains(saved) ? saved : defaultMinutes
    }

    static var maxSessionSeconds: TimeInterval { TimeInterval(maxMinutes * 60) }

    /// Read the current value from the server. Failures keep the saved value.
    static func refresh() async {
        struct Row: Decodable { let value: Int }
        do {
            let rows: [Row] = try await supabase
                .from("app_config")
                .select("value")
                .eq("key", value: storageKey)
                .execute()
                .value
            if let minutes = rows.first?.value, allowedMinutes.contains(minutes) {
                UserDefaults.standard.set(minutes, forKey: storageKey)
            }
        } catch {
            print("⚠️ RecordingLimits: could not read the limit, keeping \(maxMinutes) min: \(error)")
        }
    }
}

/// This account's recording time this month (my_recording_quota() on the server).
/// The month runs from the day the account was made; admins have no limit.
struct RecordingQuota: Decodable, Equatable {
    let plan: String
    let limitSeconds: Double?
    let usedSeconds: Double
    let remainingSeconds: Double?
    let periodEnd: String

    enum CodingKeys: String, CodingKey {
        case plan, limitSeconds = "limit_seconds", usedSeconds = "used_seconds",
             remainingSeconds = "remaining_seconds", periodEnd = "period_end"
    }

    var isUnlimited: Bool { remainingSeconds == nil }
    var isUsedUp: Bool { (remainingSeconds ?? 1) <= 0 }

    /// When the month starts again, e.g. "12/10".
    var renewsOn: String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: periodEnd) ?? {
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: periodEnd)
        }()
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded(.down))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)分" }
        return m == 0 ? "\(h)時間" : "\(h)時間\(m)分"
    }

    /// One line for the recording screen.
    var summary: String {
        guard let remaining = remainingSeconds, let limit = limitSeconds else { return "" }
        return "今月の録音 残り\(Self.duration(remaining)) / \(Self.duration(limit))（\(renewsOn) に戻ります）"
    }

    var usedUpMessage: String {
        "今月の録音時間（\(Self.duration(limitSeconds ?? 0))）を使い切りました。\(renewsOn) から再び録音できます"
    }

    static func fetch() async -> RecordingQuota? {
        do {
            let quota: RecordingQuota? = try await supabase.rpc("my_recording_quota").execute().value
            return quota
        } catch {
            print("⚠️ RecordingQuota: could not read: \(error)")
            return nil
        }
    }
}
