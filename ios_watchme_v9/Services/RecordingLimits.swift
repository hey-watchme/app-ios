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
