//
//  SavedRecordings.swift
//  ios_watchme_v9
//
//  Recordings the signed-in user saved to find again (table spot_bookmarks, platform
//  supabase/migrations/20261120010000_spot_bookmarks.sql). Each user's own; only for
//  devices the user is linked to, so never for the sample device.
//

import Foundation
import Supabase

enum SavedRecordings {
    private struct Row: Codable {
        let user_id: String?
        let device_id: String
        let recorded_at: String
    }

    private static var client: SupabaseClient { SupabaseClientManager.shared.client }

    /// The sample device is read-only; recordings on it cannot be saved.
    static func canSave(deviceId: String) -> Bool {
        deviceId != DeviceManager.sampleDeviceID
    }

    /// recorded_at of the device's saved recordings, newest recording first.
    static func recordedAts(deviceId: String) async throws -> [String] {
        let rows: [Row] = try await client
            .from("spot_bookmarks")
            .select("device_id, recorded_at")
            .eq("device_id", value: deviceId)
            .order("recorded_at", ascending: false)
            .execute()
            .value
        return rows.map(\.recorded_at)
    }

    static func isSaved(deviceId: String, recordedAt: String) async throws -> Bool {
        let rows: [Row] = try await client
            .from("spot_bookmarks")
            .select("device_id, recorded_at")
            .eq("device_id", value: deviceId)
            .eq("recorded_at", value: recordedAt)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    static func save(deviceId: String, recordedAt: String) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString.lowercased() else {
            throw SavedRecordingsError.notSignedIn
        }
        try await client
            .from("spot_bookmarks")
            .upsert(Row(user_id: userId, device_id: deviceId, recorded_at: recordedAt),
                    onConflict: "user_id,device_id,recorded_at", ignoreDuplicates: true)
            .execute()
    }

    static func remove(deviceId: String, recordedAt: String) async throws {
        try await client
            .from("spot_bookmarks")
            .delete()
            .eq("device_id", value: deviceId)
            .eq("recorded_at", value: recordedAt)
            .execute()
    }
}

enum SavedRecordingsError: LocalizedError {
    case notSignedIn

    var errorDescription: String? { "ログインしていないため保存できません" }
}
