//
//  QuestionService.swift
//  ios_watchme_v9
//
//  Reads the open questions (RLS: subjects the user is a member of) and sends the answers to the
//  API, which applies them and writes the recording's note again (platform functions/questions).
//

import Foundation

enum QuestionService {
    private static let serverURL = "https://api.hey-watch.me"

    /// Open questions of a device, newest first. recordedAt narrows them to one recording,
    /// scope to one kind of question (person = about the observed person).
    static func open(subjectId: String, recordedAt: String? = nil, scope: String? = nil) async -> [FamilyQuestion] {
        var query = SupabaseClientManager.shared.client
            .from("questions")
            .select("question_id, subject_id, recorded_at, local_date, scope, kind, prompt, options, context")
            .eq("subject_id", value: subjectId)
            .eq("status", value: "open")
        if let recordedAt {
            query = query.eq("recorded_at", value: recordedAt)
        }
        if let scope {
            query = query.eq("scope", value: scope)
        }
        do {
            return try await query
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
        } catch {
            print("❌ [Questions] Failed to read: \(error)")
            return []
        }
    }

    /// answers: question_id -> option key, "unsure" or "skip".
    static func send(_ answers: [String: String]) async throws {
        guard !answers.isEmpty else { return }
        guard let url = URL(string: "\(serverURL)/questions/answers"),
              let bearer = await SupabaseClientManager.shared.bearerToken() else {
            throw NSError(domain: "QuestionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "ログインし直してからもう一度お試しください"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(bearer, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "answers": answers.map { ["question_id": $0.key, "answer": $0.value] }
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw NSError(domain: "QuestionService", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "答えを送れませんでした（\(status)）。時間をおいてもう一度お試しください"])
        }
    }
}
