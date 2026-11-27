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
            var questions: [FamilyQuestion] = try await query
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            let spans = await recordingSpans(subjectId: subjectId,
                                             recordedAt: Set(questions.compactMap(\.recorded_at)))
            for i in questions.indices {
                questions[i].span = questions[i].recorded_at.flatMap { instant($0) }.flatMap { spans[$0] }
            }
            return questions
        } catch {
            print("❌ [Questions] Failed to read: \(error)")
            return []
        }
    }

    private struct SpanRow: Decodable {
        let recorded_at: String
        let local_time: String?
        let duration: Double?
    }

    /// When each recording ran, keyed by its recorded_at instant. A missing row only loses the label's time.
    private static func recordingSpans(subjectId: String, recordedAt: Set<String>) async -> [Date: RecordingSpan] {
        guard !recordedAt.isEmpty else { return [:] }
        let rows: [SpanRow]
        do {
            rows = try await SupabaseClientManager.shared.client
                .from("spot_results")
                .select("recorded_at, local_time, duration:profile_result->recording->duration_seconds")
                .eq("subject_id", value: subjectId)
                // As "...Z" in double quotes: an in-list must quote "." and ":", and a "+" in a URL can read as a space
                .in("recorded_at", values: recordedAt.compactMap(instant).map { "\"\(utc($0))\"" })
                .execute()
                .value
        } catch {
            print("❌ [Questions] Failed to read the recordings' times: \(error)")
            return [:]
        }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone(identifier: "UTC")
        var spans: [Date: RecordingSpan] = [:]
        for row in rows {
            guard let key = instant(row.recorded_at), let localTime = row.local_time else { continue }
            for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
                local.dateFormat = format
                if let start = local.date(from: localTime) {
                    spans[key] = RecordingSpan(start: start, seconds: row.duration)
                    break
                }
            }
        }
        return spans
    }

    private static func utc(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// A timestamptz as PostgREST writes it ("2026-11-24T22:27:00+00:00", with or without fractions).
    private static func instant(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
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
        // Every entry (the recording, the dashboard, the profile) keeps its own list; answered ones must leave them all
        await MainActor.run { NotificationCenter.default.post(name: .questionsAnswered, object: nil) }
    }
}

extension NSNotification.Name {
    /// Answers were saved: the open questions have changed.
    static let questionsAnswered = NSNotification.Name("questionsAnswered")
}
