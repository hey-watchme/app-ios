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
        let subject_id: String
        let recorded_at: String
    }

    private static var client: SupabaseClient { SupabaseClientManager.shared.client }

    /// The sample device is read-only; recordings on it cannot be saved.
    static func canSave(subjectId: String) -> Bool {
        subjectId != SubjectManager.sampleSubjectID
    }

    /// recorded_at of the device's saved recordings, newest recording first.
    static func recordedAts(subjectId: String) async throws -> [String] {
        let rows: [Row] = try await client
            .from("spot_bookmarks")
            .select("subject_id, recorded_at")
            .eq("subject_id", value: subjectId)
            .order("recorded_at", ascending: false)
            .execute()
            .value
        return rows.map(\.recorded_at)
    }

    static func isSaved(subjectId: String, recordedAt: String) async throws -> Bool {
        let rows: [Row] = try await client
            .from("spot_bookmarks")
            .select("subject_id, recorded_at")
            .eq("subject_id", value: subjectId)
            .eq("recorded_at", value: recordedAt)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    static func save(subjectId: String, recordedAt: String) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString.lowercased() else {
            throw SavedRecordingsError.notSignedIn
        }
        try await client
            .from("spot_bookmarks")
            .upsert(Row(user_id: userId, subject_id: subjectId, recorded_at: recordedAt),
                    onConflict: "user_id,subject_id,recorded_at", ignoreDuplicates: true)
            .execute()
    }

    static func remove(subjectId: String, recordedAt: String) async throws {
        try await client
            .from("spot_bookmarks")
            .delete()
            .eq("subject_id", value: subjectId)
            .eq("recorded_at", value: recordedAt)
            .execute()
    }
}

enum SavedRecordingsError: LocalizedError {
    case notSignedIn

    var errorDescription: String? { "ログインしていないため保存できません" }
}
