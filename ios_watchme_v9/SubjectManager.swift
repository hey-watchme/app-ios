//
//  SubjectManager.swift
//  ios_watchme_v9
//
//  The subjects (observed people) the signed-in user can see, and which one is on screen.
//  Recordings and results belong to a subject (platform docs/product/accounts-subjects-devices.md).
//  The list comes from subject_members (who is linked to which subject) joined with subjects;
//  the shared sample is added at the end. Signed-out visitors see only the sample.
//

import SwiftUI
import Foundation
import UIKit
import Supabase

final class SubjectManager: ObservableObject {
    // MARK: - Constants

    /// The shared sample (subjects.is_demo). Everyone can read it; nobody can change it.
    static let sampleSubjectID = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

    // MARK: - State

    enum SubjectState: Equatable {
        case idle
        case loading
        case available([SubjectEntry])   // zero or more, the sample included
        case error(String)
    }

    @Published var state: SubjectState = .idle
    @Published var selectedSubjectID: String? = nil

    /// The subjects in the list (the sample included).
    var subjects: [SubjectEntry] {
        if case .available(let subjects) = state { return subjects }
        return []
    }

    /// The user's own subjects (the sample excluded).
    var ownSubjects: [SubjectEntry] { subjects.filter { !$0.isDemo } }

    var hasOwnSubjects: Bool { !ownSubjects.isEmpty }

    var selectedEntry: SubjectEntry? {
        guard let id = selectedSubjectID else { return nil }
        return subjects.first(where: { $0.subjectId == id })
    }

    var selectedSubject: Subject? { selectedEntry?.subject }

    /// Loaded and something selected.
    var isReady: Bool {
        guard case .available = state else { return false }
        return selectedSubjectID != nil
    }

    /// The sample is on screen.
    var isSampleSelected: Bool { selectedEntry?.isDemo ?? (selectedSubjectID == Self.sampleSubjectID) }

    /// The subject a signed-in user records for when the sample is on screen: their own first.
    var ownRecordingSubject: SubjectEntry? {
        ownSubjects.first(where: { $0.role == "owner" }) ?? ownSubjects.first
    }

    // The key keeps its old name so the selection survives the update (same id value).
    private let selectedSubjectIDKey = "watchme_selected_device_id"

    init() {
        if let saved = UserDefaults.standard.string(forKey: selectedSubjectIDKey) {
            selectedSubjectID = saved
        }
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("APNsTokenReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            self?.saveAPNsTokenToSupabase(token)
        }
    }

    // MARK: - Loading

    /// Load the user's subjects (and the sample) and keep a valid selection.
    func loadSubjects(for userId: String) async {
        await MainActor.run { state = .loading }
        do {
            let subjects = try await fetchSubjects(userId: userId)
            await MainActor.run {
                state = .available(subjects)
                if selectedSubjectID == nil || !subjects.contains(where: { $0.subjectId == selectedSubjectID }) {
                    selectedSubjectID = defaultSelection(from: subjects)
                }
            }
        } catch {
            print("❌ Failed to load subjects: \(error)")
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    /// Show the sample to a signed-out visitor. It is read with the anon key (RLS lets anon
    /// read the sample only). The selection is not saved, so a later sign-in starts on the
    /// user's own subject.
    func loadSampleForGuest() async {
        let alreadyShown = await MainActor.run { () -> Bool in
            if case .available(let current) = state,
               current.count == 1, current.first?.isDemo == true,
               selectedSubjectID == current.first?.subjectId {
                return true
            }
            if case .available = state { return false }
            state = .loading
            return false
        }
        if alreadyShown { return }

        do {
            let sample = try await fetchSample()
            await MainActor.run {
                // The list and the selection together, so the dashboard is laid out once.
                state = .available(sample.map { [$0] } ?? [])
                selectedSubjectID = sample?.subjectId
            }
        } catch {
            print("❌ Failed to load the sample: \(error)")
            await MainActor.run {
                state = .error("サンプルを読み込めませんでした。通信状況を確かめてください。")
            }
        }
    }

    private func fetchSubjects(userId: String) async throws -> [SubjectEntry] {
        let rows: [MemberRow] = try await supabase
            .from("subject_members")
            .select("role, subjects(*)")
            .eq("user_id", value: userId)
            .execute()
            .value

        var subjects = rows.map {
            SubjectEntry(subject: $0.subjects.subject, role: $0.role,
                         timezone: $0.subjects.timezone, isDemo: $0.subjects.isDemo)
        }
        .sorted { ($0.subject.createdAt ?? "") < ($1.subject.createdAt ?? "") }

        // Signed-in users can open the sample too. It is not linked to the account (no
        // role, so it cannot be edited or recorded to).
        if !subjects.contains(where: { $0.isDemo }), let sample = try? await fetchSample() {
            subjects.append(sample)
        }
        return subjects
    }

    private func fetchSample() async throws -> SubjectEntry? {
        let rows: [SubjectRow] = try await supabase
            .from("subjects")
            .select("*")
            .eq("subject_id", value: Self.sampleSubjectID)
            .execute()
            .value
        return rows.first.map { SubjectEntry(subject: $0.subject, role: nil, timezone: $0.timezone, isDemo: true) }
    }

    private func defaultSelection(from subjects: [SubjectEntry]) -> String? {
        if let saved = UserDefaults.standard.string(forKey: selectedSubjectIDKey),
           subjects.contains(where: { $0.subjectId == saved }) {
            return saved
        }
        return (subjects.first(where: { $0.role == "owner" && !$0.isDemo })
                ?? subjects.first(where: { !$0.isDemo }))?.subjectId
    }

    // MARK: - Changes

    /// Add a subject: the subject and the caller's membership in one call (create_subject).
    /// Returns its id. The profile fields are written afterwards with a normal update.
    @discardableResult
    func createSubject(name: String = "") async throws -> String {
        let id: String = try await supabase
            .rpc("create_subject", params: CreateSubjectParams(p_name: name, p_timezone: TimeZone.current.identifier))
            .execute()
            .value
        guard !id.isEmpty else { throw SubjectManagerError.noSubjectReturned }
        return id
    }

    func selectSubject(_ subjectId: String?) {
        selectedSubjectID = subjectId
        if let subjectId {
            UserDefaults.standard.set(subjectId, forKey: selectedSubjectIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedSubjectIDKey)
        }
    }

    /// Drop a deleted (or left) subject from the list and move the selection.
    @MainActor
    func forgetSubject(_ subjectId: String) {
        let remaining = subjects.filter { $0.subjectId != subjectId }
        state = .available(remaining)
        if selectedSubjectID == subjectId {
            selectSubject(defaultSelection(from: remaining))
        }
    }

    /// Put a just-uploaded avatar into the list, so the header and the subject screen
    /// update before the network reload.
    @MainActor
    func applySubjectAvatar(subjectId: String, avatarUrl: String) {
        guard case .available(let current) = state else { return }
        state = .available(current.map { entry in
            guard entry.subjectId.lowercased() == subjectId.lowercased() else { return entry }
            var copy = entry
            copy.subject = entry.subject.withAvatarUrl(avatarUrl)
            return copy
        })
    }

    @MainActor
    func clearState() {
        state = .idle
        selectedSubjectID = nil
        UserDefaults.standard.removeObject(forKey: selectedSubjectIDKey)
    }

    @MainActor
    func resetState() {
        clearState()
    }

    // MARK: - Time zone

    /// The selected subject's time zone (days are grouped in it), else the phone's.
    var selectedTimezone: TimeZone {
        selectedSubjectID.map { getTimezone(for: $0) } ?? TimeZone.current
    }

    var subjectCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = selectedTimezone
        return calendar
    }

    func getTimezone(for subjectId: String) -> TimeZone {
        if let name = subjects.first(where: { $0.subjectId == subjectId })?.timezone,
           let zone = TimeZone(identifier: name) {
            return zone
        }
        return TimeZone.current
    }

    // MARK: - APNs token

    private func saveAPNsTokenToSupabase(_ token: String) {
        guard let userId = UserDefaults.standard.string(forKey: "current_user_id") else {
            UserDefaults.standard.set(token, forKey: "pending_apns_token")
            return
        }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        Task {
            do {
                try await SupabaseClientManager.shared.client
                    .from("users")
                    .update(["apns_token": token, "apns_environment": environment])
                    .eq("user_id", value: userId)
                    .execute()
                UserDefaults.standard.removeObject(forKey: "pending_apns_token")
            } catch {
                print("❌ Failed to save the APNs token: \(error)")
            }
        }
    }
}

// MARK: - Models

/// One subject in the list: the profile, the user's role, and what the app needs to show it.
struct SubjectEntry: Equatable {
    var subject: Subject
    let role: String?          // "owner" / "viewer"; nil for the sample
    let timezone: String?      // IANA name (e.g. "Asia/Tokyo")
    let isDemo: Bool

    var subjectId: String { subject.subjectId }

    /// Name for display; an unnamed subject (name '') shows as 名称未設定.
    var displayName: String {
        let name = (subject.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "名称未設定" : name
    }

    var canEditSubject: Bool { role == "owner" && !isDemo }
    var canDeleteSubject: Bool { role != nil && !isDemo }
}

/// A subjects row with the columns Subject does not carry.
private struct SubjectRow: Decodable {
    let subject: Subject
    let timezone: String?
    let isDemo: Bool

    enum CodingKeys: String, CodingKey {
        case timezone
        case isDemo = "is_demo"
    }

    init(from decoder: Decoder) throws {
        subject = try Subject(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        isDemo = try container.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    }
}

private struct MemberRow: Decodable {
    let role: String?
    let subjects: SubjectRow
}

/// Parameters of the create_subject() database function.
private struct CreateSubjectParams: Encodable {
    let p_name: String
    let p_timezone: String
}

enum SubjectManagerError: Error, LocalizedError {
    case noSubjectReturned

    var errorDescription: String? {
        switch self {
        case .noSubjectReturned: return "分析対象の登録に失敗しました"
        }
    }
}
